#!/bin/bash
# nmap script
# ejc-2022
#
# Variables
# ADD YOUR USERNAME HERE BEFORE RUNNING
# Username is required as a variable since this script requires sudo access so the default variable for this will use root
username=myuser
nmap_output_path=/home/$username/Documents/nmap_outputs
# ADD YOUR NETWORK HERE IN IPV4 IN THE FORMAT OF X.X.X.0
net0=x.x.x.0
subnet0=/24
formatted_date=$(date +%m-%d-%Y)
timestamp=$(date +%H_%M)-UTC

#Check for root, or sudo access
if [ "$EUID" -ne 0 ]
  then echo "Please run as root, or use sudo as NMAP requires root privileges!"
  exit
fi

#Check for existance of directory, if not exist, make it
if [ ! -d /home/$username/Documents/nmap_outputs ] 
then
    mkdir /home/$username/Documents/nmap_outputs
fi

echo "Starting nmap Script"
echo ""
echo "Moving to directory..."
cd $nmap_output_path
sudo nmap -sS -sV -O -v $net0$subnet0 -oX report_$formatted_date.xml
echo "Done with nmap..."
echo ""
echo "Cleaning and generating HTML report..."
xsltproc report_*.xml -o report_$formatted_date-$timestamp.html
echo "Check reports at $nmap_output_path"