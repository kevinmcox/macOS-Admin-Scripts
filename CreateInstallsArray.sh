#!/bin/bash

## CreateInstallsArray
## Copyright © 2024 Kevin M. Cox
## MIT License
version="2.0"

# For details visit:
# https://www.kevinmcox.com/2024/11/create-a-munki-installs-array-for-multiple-files-at-once/

# Create a Munki "installs" array using the 'makepkginfo -f' tool from either a single file or multiple files by recursively searching an input directory.

# This is useful when deploying a custom package that installs files, as opposed to applications, and you want Munki to make sure they stay installed and unaltered.

# Output will be in 'InstallsArray.xml' on your desktop. Copy and paste the contents of this file into the Munki PkgInfo file for your package.

# Path to Munki's makepkginfo tool
MAKEPKGINFO=/usr/local/munki/makepkginfo

# Text color variables
cyan='\033[0;36m'
green='\033[0;32m'
red='\033[0;31m'
yellow='\033[3;33m' # Italics
no_color='\033[0m'
error="${red}ERROR:${no_color}"

# GETOPTS
while getopts ":vh" opt; do
	case $opt in
		h)
			echo -e "\nCreateInstallsArray.sh builds a Munki \"installs\" array using Munki's \"makepkginfo\" tool with the \"-f\" option from either a single file or multiple files by recursively searching an input directory.\n\nOutput will be in \"InstallsArray.xml\" on your desktop.\n" | fold -w 75 -s
			echo -e "Usage:\n  CreateInstallsArray.sh [/path/to/folder/or/file]\n"
			echo -e "Examples:"
			echo -e "  CreateInstallsArray.sh /Library/CompanyName/logos/"
			echo -e "  CreateInstallsArray.sh /Library/CompanyName/scripts/example.sh\n"
			echo -e "Options:"
			echo -e "  -h	Show this help message and exit."
			echo -e "  -v	Print the versions number.\n"
			echo -e "Requierments:"
			echo -e "  'makepkginfo' from Munki tools: https://github.com/munki/munki\n"
			exit 0
			;;
		v)
			echo "${version}"
			exit 0
			;;
		\?)
			echo -e "${error} Invalid option: -$OPTARG" >&2
			echo "CreateInstallsArray.sh -h for help"
			exit 1
			;;
	esac
done

# Validate the input before attempting to create the "installs" array
if
	# Confirm Munki is installed, if not warn and exit
	[[ ! -x ${MAKEPKGINFO} ]]; then
	echo -e "${error} Munki's 'makepkginfo' tool is not installed. See -h for help."
	exit 1
elif
	# Confirm input was provided, if not warn and exit
	[[ -z "$1" ]]; then
	echo -e "${error} Please provide the path to a file or directory. See -h for help."
	exit 1
elif
	# Confirm the input path exists, if not warn and exit
	[[ ! -e "$1" ]]; then
	echo -e "${error} The specified file or directory does not exist, please check the path. See -h for help."
	exit 1
fi

# Create the output file and setup the array; this overwrites any previous output
echo -e "\n${cyan}Creating 'InstallsArray.xml' on your desktop...${no_color}"
echo -e "	<key>installs</key>\n	<array>" > ~/Desktop/InstallsArray.xml
echo -e "${yellow}Generating an Installs dictionary for the following files:${no_color}"

# Generate the installs array
if
	# Don't look inside application bundles
	[[ "$1" == *.app || "$1" == *.app/ ]]; then
	echo "$1"
	${MAKEPKGINFO} -f "$1" | /usr/bin/awk '/<dict>/&&++k==3,/<\/dict>/' >> ~/Desktop/InstallsArray.xml
else
	# Trim trailing slashes from the input path
	inputTrimmed=$(echo "$1" | /usr/bin/sed 's:/*$::')
	# Loop through the input path and generate a Munki "installs" dictionary for each file found
	/usr/bin/find "${inputTrimmed}" \( -type f -o -type l \) ! -name '.DS_Store' -print0 | /usr/bin/sort -fz | while IFS= read -r -d '' filepath
	do
		echo "$filepath"
		${MAKEPKGINFO} -f "${filepath}" | /usr/bin/awk '/<dict>/&&++k==3,/<\/dict>/' >> ~/Desktop/InstallsArray.xml
	done
fi

# Close the array
echo "	</array>" >> ~/Desktop/InstallsArray.xml
echo -e "${green}Creation of 'InstallsArray.xml' is complete.\n"
