#!/bin/bash

## AWS VPN Diagnostics and log gathering
## Version 1.0, April 26, 2023
## By Kevin M. Cox

## This script gathers AWS VPN Client logs and runs tests for analysis
## then creates a tarball so users can attach the results to IT tickets for evaluation.

# Get the current date and time
dateShort=$(/bin/date '+%F_%H.%M')
dateLong=$(/bin/date '+%B %d, %Y @ %T %Z')

# Define the output folder
outputFolder="/Users/Shared/AWS_VPN_Diagnostics_$dateShort"

# Get the username of the current user
currentUser="$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ { print $3 }')"

# Make sure AWS VPN Client and logs actually exist, in case a user runs this accidentally
if	[[ ! -d "/Applications/AWS VPN Client/AWS VPN Client.app" ]]; then
	echo "AWS VPN Client is not installed."
	exit 1
else
	if	[[ ! -d "/Users/$currentUser/.config/AWSVPNClient/logs/" ]]; then
		echo "AWS VPN Client logs do not exist."
		exit 1
	fi
fi

# Make the output folder to gather the results
/bin/mkdir "$outputFolder"
# Make the folder for the VPN Logs
/bin/mkdir "$outputFolder"/VPN_LOGS/
# Make the folder for the PCAP files
/bin/mkdir "$outputFolder"/PCAPS/

# Copy the VPN Logs
/bin/cp -pr /Users/"$currentUser"/.config/AWSVPNClient/logs/ "$outputFolder"/VPN_LOGS/

# Run the DNS checks and create the RESULTS.txt file
{
	#Write the current user and date/time to the top of the file
	echo "$dateLong"
	echo "USER: $currentUser"
	# Output the DNS serers in use
	echo -e "\n#### DNS SERVERS ####\n"
	/usr/sbin/scutil --dns | /usr/bin/grep nameserver
	# Run a DNS lookup on Google
	echo -e "\n#### GOOGLE LOOKUP ####\n"
	/usr/bin/nslookup google.com
	# Run an internal DNS lookup
	echo -e "\n#### INTERNAL LOOKUP ####\n"
	/usr/bin/nslookup internal.company.net
} > "$outputFolder"/RESULTS.txt

# Get a list of all tunnel names and add them to an array
tunnels=()
while IFS='' read -r line; do tunnels+=("$line"); done < <(/sbin/ifconfig | /usr/bin/grep "utun.*:" | /usr/bin/awk -F ':' '{print $1}')

# Loop through the tunnel names
for utun in "${tunnels[@]}"
do
	{
	# Run ifconfig on each tunnel and add the RESULTS
	echo -e "\n#### $utun ####\n"
	/sbin/ifconfig "$utun"
	} >> "$outputFolder"/RESULTS.txt
done

# Detect the active interface
interface=$(/sbin/route get internal.company.net | /usr/bin/grep interface | /usr/bin/cut -d":" -f2 | /usr/bin/awk '{$1=$1};1')

# Get the primary DNS server being used
dnsServer=$(/usr/sbin/scutil --dns | /usr/bin/grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | /usr/bin/head -1)

# If a tunnel is active run tcpdump, otherwise log an error
if [[ $interface = utun* ]]; then
	# Capture 10 packets with tcpdump for analysis
	/usr/sbin/tcpdump -c 10 -nni "$interface" dst port 53 -w "$outputFolder"/PCAPS/utunPort53.pcap 2> "$outputFolder"/PCAPS/utunPort53.txt
	/usr/sbin/tcpdump -c 10 -nni "$interface" host "$dnsServer" -w "$outputFolder"/PCAPS/utunHost.pcap 2> "$outputFolder"/PCAPS/utunHost.txt
	/usr/sbin/tcpdump -c 10 -nni any dst port 53 -w "$outputFolder"/PCAPS/AnyPort53.pcap 2> "$outputFolder"/PCAPS/AnyPort53.txt
	/usr/sbin/tcpdump -c 10 -nni any host "$dnsServer" -w "$outputFolder"/PCAPS/AnyHost.pcap 2> "$outputFolder"/PCAPS/AnyHost.txt
else
	echo -e "Tunnel not active\nActive Interface: $interface" > "$outputFolder"/PCAPS/Error.txt
fi

# Create a compressed tar archive of the files for attaching to the ITSD ticket
cd /Users/Shared/ || (echo "Changing directories failed, unable to tar logs" && exit 1)
/usr/bin/tar -czf AWS_VPN_Diagnostics_"$dateShort".tgz "AWS_VPN_Diagnostics_$dateShort"

# Change the ownership on the archive
/usr/sbin/chown "$currentUser":wheel AWS_VPN_Diagnostics_"$dateShort".tgz

# Move it to the desktop
/bin/mv AWS_VPN_Diagnostics_"$dateShort".tgz /Users/"$currentUser"/Desktop/AWS_VPN_Diagnostics_"$dateShort".tgz

# Delete the output folder
/bin/rm -rf "$outputFolder"
	
