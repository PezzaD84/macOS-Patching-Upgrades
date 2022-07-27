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

min_drive_space=45

free_disk_space=$(osascript -l 'JavaScript' -e "ObjC.import('Foundation'); var freeSpaceBytesRef=Ref(); $.NSURL.fileURLWithPath('/').getResourceValueForKeyError(freeSpaceBytesRef, 'NSURLVolumeAvailableCapacityForImportantUsageKey', null); Math.round(ObjC.unwrap(freeSpaceBytesRef[0]) / 1000000000)")  # with thanks to Pico

##############################################################
# Elevate user to admin # To use this feature unhash line 35 #
##############################################################	

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
#elevate

# Free space check

if [[ ! "$free_disk_space" ]]; then
	# fall back to df -h if the above fails
	free_disk_space=$(df -Pk . | column -t | sed 1d | awk '{print $4}')
fi

if [[ $free_disk_space -ge $min_drive_space ]]; then
	echo "OK - $free_disk_space GB free/purgeable disk space detected"
else
	echo "ERROR - $free_disk_space GB free/purgeable disk space detected"
	exit 1
fi

# Check and Download macOS
OScheck=$(ls /Applications/ | grep macOS)

if [[ $OScheck == "" ]]; then
	echo "No installer found. Downloading now"
	sudo launchctl kickstart -k system/com.apple.softwareupdated
	sleep 5
	softwareupdate -d --fetch-full-installer --full-installer-version $Latest
	
else
	echo "macOS installer already downloaded"
fi

sleep 5

# Upgrade available and Deferment notification

day1=/var/tmp/postponed.txt
day2=/var/tmp/postponed2.txt
day3=/var/tmp/postponed3.txt
day4=/var/tmp/postponed4.txt

deferment(){
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
	rm $day1
	rm $day2
	rm $day3
	rm $day4
elif [[ ! -f $day1 ]]; then
	echo "User postponed the macOS upgrade 1st Day" > $day1
	echo "User postponed the macOS upgrade 1st Day"
	exit 0
elif [[ -f $day1 ]] && [[ ! -f $day2 ]]; then
	echo "User postponed the macOS upgrade 2nd Day" > $day2
	echo "User postponed the macOS upgrade 2nd Day"
	exit 0
elif [[ -f $day1 ]] && [[ -f $day2 ]] && [[ ! -f $day3 ]]; then
	echo "User postponed the macOS upgrade 3rd Day" > $day3
	echo "User postponed the macOS upgrade 3rd Day"
	exit 0
elif [[ -f $day1 ]] && [[ -f $day2 ]] && [[ -f $day3 ]] && [[ ! -f $day4 ]]; then
	echo "User postponed the macOS upgrade 4th Day" > $day4
	echo "User postponed the macOS upgrade 4th Day"
	exit 0
elif [[ -f $day4 ]]; then
	message=$("$Notify" \
-windowType hud \
-lockHUD \
-title "MacOS Upgrade" \
-heading "MacOS Upgrade Available" \
-description "Update postponement has passed 4 days.
Your device will now be updated.

This process can take 20-40min so please do not turn off your device during this time.
Your device will reboot by itself once completed." \
-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns \
-button1 "Install now" \
-defaultButton 1 \
)
	rm $day1
	rm $day2
	rm $day3
	rm $day4
fi
}

deferment

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
	
	"/Applications/$OSInstaller/Contents/Resources/startosinstall" --agreetolicense --force --user $adminuser --stdinpass $adminpswd
else
	echo "Mac is Intel so things are simple from here!!!"

sleep 5
	
	# Install macOS
	
	OSInstaller=$(ls /Applications/ | grep -i 'install macOS' )
	
	"/Applications/$OSInstaller/Contents/Resources/startosinstall" --agreetolicense --force
fi
		
