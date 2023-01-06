#!/bin/bash

# Version 1.0
# By Kevin M. Cox

# Recursively search an input directory and generate a Munki "installs_array" for every file found, outputting the results as individual files in a folder on your desktop.
# This is useful when building a custom package that installs a variety of random files and you want Munki to make sure they stay installed and unaltered.
# This is intended to target a folder of files and not a folder of application bundles.

# Example usage:
# ./MakePkgInfoLoop.sh /Library/CompanyName/logos

# Path to Munki's makepkginfo tool
MAKEPKGINFO=/usr/local/munki/makepkginfo

# Make sure Munki is installed
if
	[[ ! -e $MAKEPKGINFO ]]
	then
	echo "Munki is not installed, exiting."
	exit 1
fi

# Create the output directory if is doesn't already exist
if
	[[ ! -d ~/Desktop/MakePkgInfo/ ]]
	then
	/bin/mkdir ~/Desktop/MakePkgInfo/
fi

# Loop through the input directory and generate a Munki "installs_arrray" for each file found
for filepath in $(find "$1" -type fl -name '*.*'); do
	echo "${filepath}"
	file=$(echo "${filepath}" | sed 's:.*/::')
	$MAKEPKGINFO -f "${filepath}" > ~/Desktop/MakePkgInfo/"${file}".xml
done
