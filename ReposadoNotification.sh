#!/bin/bash

# Version 1.1
# For information on this script visit:
# https://www.kevinmcox.com/2019/04/automating-reposado-with-slack-notifications

# File locations - Change as needed
LIST="/tmp/ReposadoUpdateList.txt" # List of updates not in any branches
REPO_SYNC="/usr/local/reposado/repo_sync" # Location of the repo_sync binary
REPOUTIL="/usr/local/reposado/repoutil" # Location of the repoutil binary

# Options for automatically adding new updates to a branch - Change as desired
AUTOADD=true
BRANCH="testing"

# Variables for Slack Notifications
SLACK_NOTIFY=true
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/<COMPLETE URL HERE>"
SLACK_ICON_URL="https://raw.githubusercontent.com/wdas/reposado/master/other/reposado.jpg"

# Make sure the Storage volume is mounted before continuing
if
	[ ! -f /Volumes/Storage/reposado/html/index.html ]
	then
	echo "Storage volume does not appear to be mounted, exiting."
	curl -X POST -H 'Content-type: application/json' --data '{"username":"Reposado","icon_url":"'"$SLACK_ICON_URL"'","text":"*WARNING:* The Storage volume is not mounted."}' $SLACK_WEBHOOK_URL
	exit 1
fi

# Run repo_sync to fetch latest updates from Apple
$REPO_SYNC

# List available updates that are not in any branch and are not marked as deprecated
echo "Searching for non-deprecated updates that are not in any branch..."
$REPOUTIL --non-deprecated | grep "\[\]" > $LIST

# Count the new updates
UPDATECOUNT=$(cat $LIST | wc -l | tr -d ' ')
echo "$UPDATECOUNT updates found."

# If updates are available add them to a designated branch and send the Slack notification
if [ "$UPDATECOUNT" -gt 0 ]; then

	# If AUTOADD is enabled then add the updates to the designated branch to mirror Apple's branch
	if [ "$AUTOADD" = true ]; then

		# Remove deprecated updates from the designated branch
		echo "Removing deprecated updates from the $BRANCH branch..."
		$REPOUTIL --remove-product deprecated $BRANCH

		# Add the new updates to the designated branch
		NEWPRODUCTIDS=$(cat $LIST | awk '{ print $1 }' | tr '\n' ' ')
		echo "Adding $NEWPRODUCTIDS to $BRANCH branch..."
		$REPOUTIL --add-product=$NEWPRODUCTIDS $BRANCH
	fi
fi

# Send notification to Slack webhook if needed
if [ $SLACK_NOTIFY = true ]; then
	if [ -s $LIST ]; then
		echo "Sending Slack notification."
		if [ "$AUTOADD" = true ]; then
			curl -X POST -H 'Content-type: application/json' --data '{"username":"Reposado","icon_url":"'"$SLACK_ICON_URL"'","text":"*The following updates were added to the _'"$BRANCH"'_ branch:* \n '"$(cat $LIST)"'"}' $SLACK_WEBHOOK_URL
		else
			curl -X POST -H 'Content-type: application/json' --data '{"username":"Reposado","icon_url":"'"$SLACK_ICON_URL"'","text":"*The following updates are available for addition to a branch:* \n '"$(cat $LIST)"'"}' $SLACK_WEBHOOK_URL
		fi		
	else
	echo "No notification needed."
	fi
fi
