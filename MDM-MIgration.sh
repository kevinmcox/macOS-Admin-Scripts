#!/bin/bash

## Example MDM Migration Script
## By Kevin M. Cox
## For more information visit:
## https://www.kevinmcox.com/2024/07/mdm-migration-with-macos-sonoma-at-macdevopsyvr

## This is an example bash script for an MDM migration that would be triggered by a LaunchDaemon every X minutes.
## It is NOT the script we used in production and should not be trusted to work as-is. Any usage is at your own risk!
## This is less elegant than the python script we used in production,
## but I think bash is more accessible to a wider range of MacAdmins and that is why I made this version for example purposes.

# Specify UTC for all date/time related operations
export TZ="UTC"

# Set log file
logFile="/private/var/log/mdm_migration.log"

# Log function
logFunc () {
	echo "$(/bin/date '+%Y-%m-%d %H:%M:%S') - $1 - $2" >> "${logFile}"
}

# Check for MDM enrollment
if /usr/bin/profiles show | /usr/bin/grep "com.apple.mdm"; then
	logFunc "PASS" "MDM Enrolled, no action needed."
	exit 0
fi

# Get the current user
currentUser=$( echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Make sure a user is logged in
if [[ -z "${currentUser}" ]]; then
	logFunc "EXIT" "No user logged in, can not enroll."
	exit 0
fi

# If a user is logged in, log their name
logFunc "INFO" "Username: ${currentUser}"

# Get current user's UID and log it
uid=$(/usr/bin/id -u "${currentUser}")
logFunc "INFO" "User ID: ${uid}"

# Get status of screen lock
screenLocked=$(/usr/sbin/ioreg -n Root -d1 -a | /usr/bin/grep -A1 IOConsoleLocked | /usr/bin/grep -oE '(true|false)')

# Check for a locked screen
if [[ ${screenLocked} = true ]]; then
	logFunc "EXIT" "Screen is locked, can not enroll."
	exit 0
fi

# Enrollment function
triggerEnrollment () {
	logFunc "ACTION" "Displaying enrollment window"
	/bin/launchctl asuser "${uid}" /usr/bin/profiles renew -type enrollment
	exit 0
}

# Define the MDM Nag file location
depNagPlist="/private/var/db/ConfigurationProfiles/Settings/com.apple.mdm.depnag.plist"

# If the DEP Nag file doesn't exist, trigger enrollment
if [[ ! -f "${depNagPlist}" ]]; then
	logFunc "WARN" "com.apple.mdm.depnag not found."
	triggerEnrollment
fi

# Get the first nag time
firstNag=$(/usr/bin/plutil -extract "NagUI_${uid}.DateFirstShown" raw "${depNagPlist}")

# Make sure the Nag has already been displayed, if not trigger enrollment
if	[[ ${firstNag} = *"invalid"* ]]; then
	logFunc "WARN" "Have not previously nagged."
	triggerEnrollment
fi

# Log the first nag time
logFunc "DATE" "${firstNag} = First enrollment prompt"

# Convert the first nag time to epoch
firstNagEpoch=$(/bin/date -jf "%Y-%m-%dT%H:%M:%SZ" "${firstNag}" "+%s")

# Get the last nag time & log it
lastNag=$(/usr/bin/plutil -extract "NagUI_${uid}.DateShown" raw "${depNagPlist}")
logFunc "DATE" "${lastNag} = Last enrollment prompt"

# Convert the last nag time to epoch
lastNagEpoch=$(/bin/date -jf "%Y-%m-%dT%H:%M:%SZ" "${lastNag}" "+%s")

# Add 8 hours to calculate the deadline
deadlineEpoch=$((firstNagEpoch + 28800))

# Convert the deadline to human readable format
deadline=$(/bin/date -r "${deadlineEpoch}" +"%Y-%m-%dT%H:%M:%SZ")

# Log the deadline
logFunc "DATE" "${deadline} = Enrollment deadline"

# Get the current time
currentTimeEpoch=$(/bin/date +"%s")

# Calculate time left
timeLeft=$((deadlineEpoch - currentTimeEpoch))

# Calculate how much longer until the deadline and how recently we promoted.
	# Prompt every 60 minutes if there are more than 4 hours remaining
if	[[ ${timeLeft} -ge 14400 ]]; then
	logFunc "INFO" "More than 4 hours left to enroll"
	threshold=$((lastNagEpoch + 3600))
	if	[[ ${currentTimeEpoch} -ge ${threshold} ]]; then
		trigger=true
	fi
elif
	# Prompt every 30 minutes between 2-4 hours remaining
	[[ ${timeLeft} -ge 7200 ]]; then
	logFunc "INFO" "More than 2 hours left to enroll"
	threshold=$((lastNagEpoch + 1800))
	if	[[ ${currentTimeEpoch} -ge ${threshold} ]]; then
		trigger=true
	fi
elif
	# Prompt every 15 minutes under 2 hours remaining
	[[ ${timeLeft} -lt 7200 ]]; then
	logFunc "INFO" "Less than 2 hours left to enroll"
	threshold=$((lastNagEpoch + 900))
	if	[[ ${currentTimeEpoch} -ge ${threshold} ]]; then
		trigger=true
	fi
else
	trigger=false
fi

# Should we should prompt?
if	[[ ${trigger} = true ]]; then
	triggerEnrollment
else
	logFunc "EXIT" "Prompted recently, skipping"
fi
