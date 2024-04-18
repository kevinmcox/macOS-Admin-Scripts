#!/bin/bash

## This script configures Touch ID for sudo (elevated permissions) on the command line interface.
## By Kevin M. Cox | https://www.kevinmcox.com
## Last updated: 2024-04-04
version=2.0

# Determine the macOS major version
majorOSversion=$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -c1-2)

# Configure the path based on macOS version being >= 14
if [ "${majorOSversion}" -ge 14 ]; then
	path=/etc/pam.d/sudo_local
else
	path=/etc/pam.d/sudo
fi

# Explicitly set the inital state of options
enable=false
disable=false
reportStatus=false

# GETOPTS
while getopts ":sedvh" opt; do
	case $opt in
		s)
			reportStatus=true
			;;
		e)
			enable=true
			;;
		d)
			disable=true
			;;
		v)
			echo "TouchIDSudo.sh: ${version}"
			exit 0
			;;
		h)
			echo "Usage: sudo $0 [-s|-e|-d|-v|-h]"
			echo "Options:"
			echo "	-s	Check status of Touch ID for sudo"
			echo "	-e	Enable Touch ID for sudo (requires sudo)"
			echo "	-d	Disable Touch ID for sudo (requires sudo)"
			echo "	-v	Print the script version number"
			echo "	-h	Display this help message"
			echo "Your terminal application may require Privacy permissions."
			exit 0
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			echo "Run '$0 -h' for help."
			exit 1
			;;
	esac
done

# Ensure an option is supplied
if [[ $# -eq 0 ]]; then
	echo "Error: Please supply an option." >&2
	echo "Run '$0 -h' for help."
	exit 1
fi

# Ensure -e and -d options are not used together
if [[ "${enable}" = true && "${disable}" = true ]]; then
	echo "Error: -e and -d cannot be used together." >&2
	echo "Run '$0 -h' for help."
	exit 1
fi

# Check if running with sufficient privileges if -e or -d option is used
if [[ ("${enable}" = true || "${disable}" = true) && $EUID -ne 0 ]]; then
	echo "Error: This script requires elevated privileges to enable or disable Touch ID for sudo." >&2
	echo "Please run the script with 'sudo'."
	echo "Run '$0 -h' for help."
	exit 1
fi

# The configuration
config="auth       sufficient     pam_tid.so"

# Check the current status
if /usr/bin/grep -xqs "${config}" "${path}" ; then
	status=enabled
else
	status=disabled
fi

# Report the current status
if [ "${reportStatus}" = true ]; then
	if [ "${status}" = enabled ]; then
		echo "Status: Touch ID for sudo is enabled"
	else
		echo "Status: Touch ID for sudo is disabled"
	fi
	exit 0
fi

# Enable Touch ID for sudo
if [[ "${enable}" = true && "${status}" = enabled ]]; then
	echo "Warning: Touch ID for sudo is already enabled." >&2; exit 1
elif [[ "${enable}" = true && "${status}" = disabled ]]; then
	if	[ "${majorOSversion}" -ge 14 ]; then
		# macOS 14 or higher
		if	[ -e "${path}" ]; then
			# If "/etc/pam.d/sudo_local" already exists
			# Check for a commented-out configuration, if found back up the file and uncomment
			if /usr/bin/grep -xq "#${config}" "${path}" ; then
				/usr/bin/sed -i '.bak' "s/^#${config}/${config}/" "${path}"
			else
				# If the configuration is completely missing, back up the file and insert the needed configuration
				/usr/bin/sed -i '.bak' "3s/^/${config}\\n/g" "${path}"
			fi
		else
			# Copy the template file into place
			/bin/cp /etc/pam.d/sudo_local.template "${path}"
			# Uncomment the example configuration
			/usr/bin/sed -i '' "s/^#${config}/${config}/" "${path}"
		fi
	else
		# macOS 13 or lower
		# Backup "/etc/pam.d/sudo" then insert the needed configuration
		/usr/bin/sed -i '.bak' "2s/^/${config}\\n/g" "${path}"
	fi
	# Check to make sure any of the four possible sed commands above were successful
	if [ $? = 0 ]; then
		echo "Success: TouchID for sudo has been enabled"; exit 0
	else
		echo "Error: There was an error enabling Touch ID for sudo" >&2; exit 1
	fi
fi

# Disable Touch ID for sudo
if [[ "${disable}" = true && "${status}" = disabled ]]; then
	echo "Warning: Touch ID for sudo is already disabled." >&2; exit 1
elif [[ "${disable}" = true && "${status}" = enabled ]]; then
	if [ "${majorOSversion}" -ge 14 ]; then
		# macOS 14 or higher
		# Backup "/etc/pam.d/sudo_local" then disable the configuration
		/usr/bin/sed -i '.bak' "s/^${config}/#&/" "${path}"
	else
		# macOS 13 or lower
		# Backup "/etc/pam.d/sudo" then delete the configuration
		/usr/bin/sed -i '.bak' "/${config}/d" "${path}"
	fi
	# Check to make sure either of the two possible sed commands above were successful
	if [ $? = 0 ]; then
		echo "Success: TouchID for sudo has been disabled"; exit 0
	else
		echo "Error: There was an error disabling Touch ID for sudo" >&2; exit 1
	fi
fi
