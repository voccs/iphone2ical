#!/bin/bash

# Circa January, 2012
# ryan@voccs.com
# http://voccs.com/
# https://github.com/voccs/iphone2ical/

# @@@ reset switch
# @@@ refresh switch?
# @@@ verbose switch?

# Constants, not variables.  Do not modify.
DOMAIN="com.voccs.iphone2ical"
DEFAULTS=/usr/bin/defaults
SQLITE=/usr/bin/sqlite3
OSA=/usr/bin/osascript
BACKUP_DIR=~/Library/Application\ Support/MobileSync/Backup
CALL_LOG_FILE=2b2b0084a1bc3a5ac8c27afdf14afb42c61a19ca
CONTACTS_FILE=31bb7ba8914766d4ba40d6dfb6113c8b614be442

# Start program.
CUR=`pwd`
cd "${BACKUP_DIR}"
BACKUPS=`find . -name "*" -type d -depth 1| sed -e "s/^\.\///g" | egrep "^[0-9a-f]+$"`
if [ "${BACKUPS}" = "" ] ; then
    echo "No iPhones found!"
    exit 1
fi
cd $CUR

# Interactive with the user if not initialized.
INIT=`${DEFAULTS} read ${DOMAIN} "initialized" 2>/dev/null`
if [ $? -ne 0 ] ; then
    ${DEFAULTS} write ${DOMAIN} "initialized" -bool TRUE

    # Find iPhones to read call logs from
    for BACKUP in ${BACKUPS}; do
        PLIST="${BACKUP_DIR}/${BACKUP}/Info"
        TYPE=`${DEFAULTS} read "${PLIST}" "Product Type" | grep iPhone`
        if [ "${TYPE}" != "" ] ; then
            NAME=`${DEFAULTS} read "${PLIST}" "Device Name"`
            while true; do
                read -p "Read call log from iPhone \"${NAME}\"? [Yn] " -n 1 yn
                echo
                case $yn in
                    Y|y|'' )
                        ${DEFAULTS} write ${DOMAIN} "devices" -array-add ${BACKUP}
                        ${DEFAULTS} write ${DOMAIN} "names" -dict "${BACKUP}" "${NAME}"
                        echo "> Reading from \"${NAME}\""
                        sleep 2
                        break;;
                    N|n )
                        echo "> Not reading from \"${NAME}\""
                        sleep 2
                        break;;
                    * )
                        echo "Please answer with [y]es or [n]o."
                esac
            done
        fi
    done

    # Read iCal calendars
    echo "Which iCal calendar should call data be stored in?"
    CALS=`${OSA} ./get-calendars.applescript`
    IDS=("dummy")
    NAMES=""
    for CAL in "$CALS"; do
        ID=`echo -n "$CAL" | cut -d, -f1`
        NAME=`echo -n "$CAL" | cut -d, -f2`
        IDS+=( $ID )
        NAMES+=$NAME
    done
    eval set $NAMES
    select CAL in "$@"; do
        ${DEFAULTS} write ${DOMAIN} "calendar" ${IDS[$REPLY]}
        echo "> Adding call data to calendar \"${CAL}\""
        sleep 2
        break
    done

    # Notice on resetting values
    echo "You can re-run this preference setting interface using the --reset switch"
fi

# Read from preferred devices.
CALID=`${DEFAULTS} read ${DOMAIN} "calendar"`
DEVICES=`${DEFAULTS} read ${DOMAIN} "devices" | xargs | sed -e "s/^( //" -e "s/ )$//" -e "s/,//"`
for DEVICE in $DEVICES; do
    CALLDB="${BACKUP_DIR}/${DEVICE}/${CALL_LOG_FILE}"
    CONTACTDB="${BACKUP_DIR}/${DEVICE}/${CONTACTS_FILE}"
    NAME=`${DEFAULTS} read ${DOMAIN} "names" -dict "${DEVICE}" 2>/dev/null | sed -e "s/[{}]//" | xargs | grep "${DEVICE}" | egrep -o "= ([^;*]+);" | sed -e "s/^= //" -e "s/;$//"`
    LASTID=`${DEFAULTS} read ${DOMAIN} "last" -dict "${DEVICE}" 2>/dev/null | sed -e "s/[{}]//" | xargs | grep "${DEVICE}" | egrep -o "= ([^;*]+);" | sed -e "s/^= //" -e "s/;$//"`
    if [ $? -eq 1 ] ; then
        LASTID=0
    fi
    LAST=`${OSA} add-events.applescript "${CALLDB}" "${CONTACTDB}" "${NAME}" "${CALID}" "${LASTID}"`
    ${DEFAULTS} write ${DOMAIN} "last" -dict "${DEVICE}" "${LAST}"
done
# @@@ replace call log entries in iCal with latest from your contacts? would have to retain device:call id in entry somewhere and be able to look it up / build a hash quickly - or not...
exit 0
