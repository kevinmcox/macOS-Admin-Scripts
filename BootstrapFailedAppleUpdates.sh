#!/bin/bash

# Version 1.0
# Kevin M. Cox
# For detailed information visit:
# https://www.kevinmcox.com/2019/03/working-around-failed-apple-software-updates-with-munki/

if
	[ ! -f /Library/Managed\ Installs/Logs/warnings.log ]
	then
	/bin/echo "No warnings from this Munki run, presuming no failed Apple updates exist."
	else
		if
			/usr/bin/grep -E 'Apple.*update.*Security.*failed' /Library/Managed\ Installs/Logs/warnings.log
			then
			/bin/echo "WARNING: Possible failed Apple security update detected, enabling Munki bootstrap mode." | tee -a /Library/Managed\ Installs/Logs/warnings.log
			/usr/bin/touch /Users/Shared/.com.googlecode.munki.checkandinstallatstartup
			else
			/bin/echo "No failed updates detected."
		fi
fi
