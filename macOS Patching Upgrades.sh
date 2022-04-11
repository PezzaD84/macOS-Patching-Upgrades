#!/bin/bash
#
# Created by Perry 28/2/2022
#
# Script to Upgrade macOS
#
#################################################################

Latest=$(curl https://en.wikipedia.org/wiki/MacOS | grep 'Latest release' | tr '<' '\n' | grep 'infobox-data' | sed -n 5p | sed -e 's#td class="infobox-data">##' | xargs)

processor=$(uname -m)

Notify=/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper

user=$(ls -l /dev/console | awk '{ print $3 }')

#################################################################
# Elevate user to admin # To use this feature use the switch -e #
#################################################################	

elevate(){
	# Check user has Securetoken
	token=$(sudo dscl . -read /Users/$user AuthenticationAuthority | grep -o 'SecureToken')
	
	if [[ $token == SecureToken ]]; then
		echo "$user has a secure token. Continuing to elevate user."
	else
		echo "$user does not have a secure token. A local admin will be needed to run upgrades."
	fi
	
	# Elevate user account
	dscl . -append /groups/admin GroupMembership $user
	
}

while getopts ":e" option; do
	case $option in
		e) # Elevate switch
			echo "Elevate user to admin specified"
			elevate;;
		\?) # Invalid option
			echo "Error: Invalid option"
			exit 1;;
	esac
done

# Check and Download macOS

if [[ -f /Applications/Install\ macOS\ Monterey.app/Contents/Info.plist ]];then
	echo "macOS installer already downloaded"
else
	echo "No installer found. Downloading now"
	
softwareupdate -d --fetch-full-installer --full-installer-version $Latest

fi

sleep 5

# Notify Users that a MacOS Upgrade is available

message=$("$Notify" \
-windowType hud \
-lockHUD \
-title "MacOS Upgrade" \
-heading "MacOS Upgrade Available" \
-description "A macOS upgrade is available to install.
This process can take 20-40min so please do not turn off your device during this time.
Your device will reboot by itself once completed." \
-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns \
-button1 "Install now" \
-button2 "Postpone" \
-defaultButton 1 \
)

if [[ $message == 0 ]]; then
	echo "User agreed to install macOS upgrade"
else
	echo "User postponed the macOS upgrade"
	exit 1
fi

sleep 5

# Core upgrade script

if [[ $processor == arm64 ]]; then
	echo "Mac is M1 so lets confuse everyone with popups!!!"
	
	# Get credentials for upgrade
	
	user=$(ls -l /dev/console | awk '{ print $3 }')
	
	if dscl . read /Groups/admin | grep $user; then
		echo "$user is admin"
	adminuser=$user
	
	adminpswd=$(osascript -e 'Tell application "System Events" to display dialog "To install the available macOS upgrade please enter your password" with title "macOS Upgrade" with icon alias "System:Applications:Utilities:Keychain Access.app:Contents:Resources:AppIcon.icns" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
	
	else
		echo "$user is not admin"
	adminuser=$(dscl . list /Users UniqueID | grep 501 | awk '{print $1}')
	
	adminpswd=$(osascript -e 'Tell application "System Events" to display dialog "To install the available macOS upgrade please enter the password for user '$adminuser'" with title "macOS Upgrade" with icon alias "System:Applications:Utilities:Keychain Access.app:Contents:Resources:AppIcon.icns" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
	fi
	
sleep 5
		
	# Install macOS
	
	OSInstaller=$(ls /Applications/ | grep -i 'install macOS' )
	
	"/Applications/$OSInstaller/Contents/Resources/startosinstall" --agreetolicense --forcequitapps --user $adminuser --stdinpass $adminpswd
else
	echo "Mac is Intel so things are simple from here!!!"

sleep 5
	
	# Install macOS
	
	OSInstaller=$(ls /Applications/ | grep -i 'install macOS' )
	
	"/Applications/$OSInstaller/Contents/Resources/startosinstall" --agreetolicense --forcequitapps
fi
		
