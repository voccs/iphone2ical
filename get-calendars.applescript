set RET to ""
tell application "iCal"
	set CALS to every calendar
	repeat with CAL in CALS
		if writable of CAL as boolean then
			set RET to ((RET & uid of CAL as string) & ",\"" & name of CAL as string) & "\"
"
		end if
	end repeat
end tell
return RET
