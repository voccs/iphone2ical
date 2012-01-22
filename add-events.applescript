on split(theString, theDelimiter)
	set oldDelimiters to AppleScript's text item delimiters
	set AppleScript's text item delimiters to theDelimiter
	set theArray to every text item of theString
	set AppleScript's text item delimiters to oldDelimiters
	return theArray
end split

on join(theList, theDelimiter)
	set prevTIDs to AppleScript's text item delimiters
	set AppleScript's text item delimiters to theDelimiter
	set output to "" & theList
	set AppleScript's text item delimiters to prevTIDs
	return output
end join

on run argv
	set CALLDB to item 1 of argv
	set CONTACTDB to item 2 of argv
	set PHONENAME to item 3 of argv
	set CALID to item 4 of argv
	set LASTID to item 5 of argv
	--set CALLDB to "/Users/ryanlee/Library/Application Support/MobileSync/Backup/185128b0d50c97e1e386e6a82ac33605d3589e2a/2b2b0084a1bc3a5ac8c27afdf14afb42c61a19ca"
	--set CONTACTDB to "/Users/ryanlee/Library/Application Support/MobileSync/Backup/185128b0d50c97e1e386e6a82ac33605d3589e2a/31bb7ba8914766d4ba40d6dfb6113c8b614be442"
	--set PHONENAME to "Moore"
	--set CALID to "3C67DB8B-2A06-4A04-BBB5-9D7C07986712"
	--set LASTID to 1580
	set RET to LASTID
	set tzOffset to time to GMT
	set main_query to "attach '" & CONTACTDB & "' as ab; SELECT call.rowid, address, strftime('%Y-%m-%d-%H-%M-%S',date" & tzOffset & ",'unixepoch'), strftime('%Y-%m-%d-%H-%M-%S',date" & tzOffset & "+duration,'unixepoch'), flags, id, abp.first, abp.last, 'outgoing' from call, ab.ABPerson as abp where call.rowid > " & LASTID & " and flags&1=1 and id=abp.rowid union SELECT call.rowid, address, strftime('%Y-%m-%d-%H-%M-%S',date" & tzOffset & ",'unixepoch'), strftime('%Y-%m-%d-%H-%M-%S',date" & tzOffset & "+duration,'unixepoch'), flags, id, abp.first, abp.last, 'incoming' from call, ab.ABPerson as abp, ab.ABMultiValue as mv where call.rowid > " & LASTID & " and flags&1=0 and address=replace(replace(replace(replace(replace(replace(replace(mv.value,'.',''),'-',''),' ',''),'(',''),')',''),'+1',''),'+','') and mv.record_id=abp.rowid union SELECT call.rowid, address, strftime('%Y-%m-%d-%H-%M-%S',date" & tzOffset & ",'unixepoch'), strftime('%Y-%m-%d-%H-%M-%S',date" & tzOffset & "+duration,'unixepoch'), flags, id, abp.first, abp.last, 'outgoing' from call, ab.ABPerson as abp, ab.ABMultiValue as mv where id=-1 and call.rowid > " & LASTID & " and flags&1=1 and address=replace(replace(replace(replace(replace(replace(replace(mv.value,'.',''),'-',''),' ',''),'(',''),')',''),'+1',''),'+','') and mv.record_id=abp.rowid;"
	set rows to paragraphs of (do shell script "/usr/bin/sqlite3 -batch \"" & CALLDB & "\" \"" & main_query & "\"")
	set found_ids to {}
	repeat with i from 1 to (length of rows)
		set eventInfo to my split(item i of rows, "|")
		set found_ids to found_ids & item 1 of eventInfo
	end repeat
	set sub_query to "SELECT rowid, address, strftime('%Y-%m-%d-%H-%M-%S',date" & tzOffset & ",'unixepoch'), strftime('%Y-%m-%d-%H-%M-%S',date" & tzOffset & "+duration,'unixepoch'), flags, id, address, '', 'outgoing' FROM call WHERE call.rowid > " & LASTID & " AND flags&1=1 AND id=-1 AND rowid not in (" & my join(found_ids, ",") & ") UNION SELECT rowid, address, strftime('%Y-%m-%d-%H-%M-%S',date" & tzOffset & ",'unixepoch'), strftime('%Y-%m-%d-%H-%M-%S',date" & tzOffset & "+duration,'unixepoch'), flags, id, address, '', 'incoming' FROM call WHERE call.rowid > " & LASTID & " AND flags&1=0 AND id=-1 AND rowid not in (" & my join(found_ids, ",") & ")"
	set rows to rows & paragraphs of (do shell script "/usr/bin/sqlite3 -batch \"" & CALLDB & "\" \"" & sub_query & "\"")
	tell application "iCal"
		set theCalendar to first calendar whose uid = CALID
		set now to current date
		tell theCalendar
			repeat with row in rows
				set eventStart to current date
				set eventEnd to current date
				set eventInfo to my split(row, "|")
				set eventSummary to item 7 of eventInfo
				if item 8 of eventInfo is not "" then
					set eventSummary to eventSummary & " " & item 8 of eventInfo
				end if
				set eventSummary to eventSummary & " (" & item 9 of eventInfo & ")"
				set eventURN to "urn:tel:record:" & PHONENAME & ":" & item 1 of eventInfo
				set eventStartParts to my split(item 3 of eventInfo, "-")
				set eventEndParts to my split(item 4 of eventInfo, "-")
				set year of eventStart to item 1 of eventStartParts
				set month of eventStart to item 2 of eventStartParts
				set day of eventStart to item 3 of eventStartParts
				set hours of eventStart to item 4 of eventStartParts
				set minutes of eventStart to item 5 of eventStartParts
				set seconds of eventStart to item 6 of eventStartParts
				set year of eventEnd to item 1 of eventEndParts
				set month of eventEnd to item 2 of eventEndParts
				set day of eventEnd to item 3 of eventEndParts
				set hours of eventEnd to item 4 of eventEndParts
				set minutes of eventEnd to item 5 of eventEndParts
				set seconds of eventEnd to item 6 of eventEndParts
				make new event at end of events with properties {summary:eventSummary, location:PHONENAME, start date:eventStart, end date:eventEnd, allday event:false, stamp date:now, url:eventURN}
				if item 1 of eventInfo as integer > RET then
					set RET to item 1 of eventInfo as integer
				end if
			end repeat
		end tell
	end tell
	return RET
end run
