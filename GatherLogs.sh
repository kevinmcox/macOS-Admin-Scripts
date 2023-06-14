#!/bin/bash

## Gather Logs
## Version 1.0, June 3, 2023
## By Kevin M. Cox

## This script gathers macOS and application logs then creates a tarball so users can attach the results to IT tickets for evaluation.

# Get the current date and time
dateShort=$(/bin/date '+%F_%H.%M')

# Define the output folder
outputFolder="/Users/Shared/macOS_Logs_$dateShort"

# Get the username of the current user
currentUser="$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ { print $3 }')"

# Make the output folder to gather the results
/bin/mkdir "$outputFolder"

# Munki logs
/bin/mkdir "$outputFolder"/Managed-Software-Center/
/bin/cp -pr /Library/Managed\ Installs/Logs/ "$outputFolder"/Managed-Software-Center/

# System logs
/bin/mkdir "$outputFolder"/private-var-log/
/bin/mkdir "$outputFolder"/private-var-logs/
/bin/cp -pr /private/var/log/ "$outputFolder"/private-var-log/
/bin/cp -pr /private/var/logs/ "$outputFolder"/private-var-logs/

# Library logs
/bin/mkdir "$outputFolder"/Library-Logs/
/bin/cp -pr /Library/Logs/ "$outputFolder"/Library-Logs/

# User logs
/bin/mkdir "$outputFolder"/User-Library-Logs/
/bin/cp -pr /Users/"$currentUser"/Library/Logs/ "$outputFolder"/User-Library-Logs/

# AWS VPN logs
if	[ -d /Users/"$currentUser"/.config/AWSVPNClient/logs/ ]; then
	/bin/mkdir "$outputFolder"/AWS-VPN-logs/
	/bin/cp -pr /Users/"$currentUser"/.config/AWSVPNClient/logs/ "$outputFolder"/AWS-VPN-logs/
fi

# Create a compressed tar archive of the files
cd /Users/Shared/ || (echo "Changing directories failed, unable to tar logs" && exit 1)
/usr/bin/tar -czf macOS_Logs_"$dateShort".tgz "macOS_Logs_$dateShort"

# Change the ownership on the archive
/usr/sbin/chown "$currentUser":wheel macOS_Logs_"$dateShort".tgz

# Move it to the desktop
/bin/mv macOS_Logs_"$dateShort".tgz /Users/"$currentUser"/Desktop/macOS_Logs_"$dateShort".tgz

# Delete the output folder
/bin/rm -rf "$outputFolder"
