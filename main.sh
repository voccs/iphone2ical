#!/bin/bash

# Circa January, 2012
# ryan@voccs.com
# http://voccs.com/
# https://github.com/voccs/iphone2ical/

# @@@ reset switch

# Constants, not variables.  Do not modify.
DOMAIN="com.voccs.iphone2ical"
DEFAULTS=/usr/bin/defaults
SQLITE=/usr/bin/sqlite3
OSA=/usr/bin/osascript
BACKUP_DIR=~/Library/Application\ Support/MobileSync/Backup
CALL_LOG_FILE=2b2b0084a1bc3a5ac8c27afdf14afb42c61a19ca

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
${DEFAULTS} read ${DOMAIN} "initialized" 2>/dev/null
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
DEVICES=`${DEFAULTS} read ${DOMAIN} "devices" | xargs | sed -e "s/^( //" -e "s/ )$//" -e "s/,//"`
for DEVICE in $DEVICES; do
    DB="${BACKUP_DIR}/${DEVICE}/${CALL_LOG_FILE}"
    sqlite3 "$DB" "SELECT * FROM call limit 5;"
    # @@@ format query to best suit adding ical event
done
# @@@ LAST dict, keyed to backup, value is highest rowid