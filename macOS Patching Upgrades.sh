#!/bin/bash
#
# Created by Perry 28/2/2022
#
# Script to Upgrade macOS
#
#################################################################

##############################################################
# Variables
##############################################################

Latest=$(curl https://en.wikipedia.org/wiki/MacOS | grep 'Latest release' | tr '<' '\n' | grep 'infobox-data' | sed -n 4p | sed -e 's#td class="infobox-data">##' | xargs)

processor=$(uname -m)

Notify=/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper

user=$(ls -l /dev/console | awk '{ print $3 }')

min_drive_space=45

free_disk_space=$(osascript -l 'JavaScript' -e "ObjC.import('Foundation'); var freeSpaceBytesRef=Ref(); $.NSURL.fileURLWithPath('/').getResourceValueForKeyError(freeSpaceBytesRef, 'NSURLVolumeAvailableCapacityForImportantUsageKey', null); Math.round(ObjC.unwrap(freeSpaceBytesRef[0]) / 1000000000)")  # with thanks to Pico

##############################################################
# Elevate user to admin
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

##############################################################
# Free space check
##############################################################

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

##############################################################
# Check if MIST is installed
##############################################################

if ! command -v mist &> /dev/null
then
	echo "Mist is not installed. App will be installed now....."
	sleep 2
	
	# Variables
	pkgfile="MIST.pkg"
	logfile="/Library/Logs/MISTInstallScript.log"
	version=$(curl -s https://github.com/ninxsoft/mist-cli | grep releases/tag | tr '/' ' ' | awk '{print $12}' | tr -d '"''>''v')
	url="https://github.com/ninxsoft/mist-cli/releases/download/v$version/mist-cli.$version.pkg"
	
	# Start Log entries
	echo "--" >> ${logfile}
	echo "`date`: Downloading latest version." >> ${logfile}
	
	# Download installer
	curl -L -J -o /tmp/${pkgfile} ${url}
	echo "`date`: Installing..." >> ${logfile}
	
	# Change to installer directory
	cd /tmp
	
	# Install application
	sudo installer -pkg ${pkgfile} -target /
	sleep 5
	echo "`date`: Deleting package installer." >> ${logfile}
	
	# Remove downloaded installer
	rm /tmp/"${pkgfile}"
else
	echo "MIST is installed. Continuing macOS Upgrade....."
fi

##############################################################
# Upgrade available and Deferment notification
##############################################################

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
-description "A macOS upgrade is available.
This process can take 20-60min so please do not turn off your device during this time.
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

This process can take 20-60min so please do not turn off your device during this time.
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

##############################################################
# Check and Download macOS
##############################################################

OScheck=$(ls /Applications/ | grep macOS)

if [[ $OScheck == "" ]]; then
	echo "No installer found. Downloading now"
    
	"$Notify" \
	-windowType hud \
	-lockHUD \
	-title "MacOS Upgrade" \
	-heading "MacOS Upgrade Downloading" \
	-description "A macOS upgrade is available to Download.
This process can take 20-60min so please do not turn off your device during this time.
Your device will continue the upgrade once the new OS has downloaded." \
	-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns &
	
	sudo launchctl kickstart -k system/com.apple.softwareupdated
	sleep 5
	
	sudo mist download installer "$Latest" application --output-directory "/Applications/" --quiet

	killall jamfHelper
else
	echo "macOS installer already downloaded"
fi

sleep 5

##############################################################
# Check Battery state
##############################################################

bat=$(pmset -g batt | grep 'AC Power')

model=$(ioreg -l | awk '/product-name/ { split($0, line, "\""); printf("%s\n", line[4]); }')

if [[ "$model" = *"Book"* ]]; then
	until [[ $bat == "Now drawing from 'AC Power'" ]]; do
	
	echo "Device not connected to power source"
	
	"$Notify" \
		-windowType hud \
		-lockHUD \
		-title "MacOS Updates" \
		-heading "Connect Charger" \
		-description "Please connect your device to a charger to continue installing updates." \
		-icon /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns \
		-button1 "Continue" \
		-defaultButton 1 \
	
		bat=$(pmset -g batt | grep 'AC Power')
		sleep 2
	done
fi

echo "Device connected to power source"

##############################################################
# Core upgrade script
##############################################################

if [[ $processor == arm64 ]]; then
	echo "Mac is M1"
	
	# Get credentials for upgrade
	
	user=$(ls -l /dev/console | awk '{ print $3 }')
	
	if dscl . read /Groups/admin | grep $user; then
		echo "$user is admin"
	adminuser=$user
	
	adminpswd=$(osascript -e 'Tell application "System Events" to display dialog "To install the available macOS upgrade please enter your password" buttons {"Continue"} default button 1 with title "macOS Upgrade" with icon alias "System:Applications:Utilities:Keychain Access.app:Contents:Resources:AppIcon.icns" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
		
		pswdCheck=$(dscl /Local/Default -authonly $user $adminPswd)
		
		until [[ $pswdCheck == "" ]]
		do
			echo "Password was incorrect"
			adminPswd=$(osascript -e 'Tell application "System Events" to display dialog "Password was incorrect. Please try again." buttons {"Continue"} default button 1 with title "macOS Upgrade" with icon alias "System:Applications:Utilities:Keychain Access.app:Contents:Resources:AppIcon.icns" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
			
			pswdCheck=$(dscl /Local/Default -authonly $user $adminPswd)
			echo $pswdCheck
		done
		
		echo "Password Validation passed. Continuing Updates....."
		sleep 5
	else
		echo "$user is not admin. Elevating user account....."
		
		# Create directory and removal script 
		
		mkdir -p /Library/.TRAMS/Scripts/
		sleep 2
        
		cat << EOF > /Library/.TRAMS/Scripts/RemoveAdmin.sh
#!/bin/bash

dseditgroup -o edit -d $user -t user admin
EOF
		
		if [[ -f /Library/.TRAMS/Scripts/RemoveAdmin.sh ]]; then
			echo "Admin removal script setup ok."
			chown root:wheel /Library/.TRAMS/Scripts/RemoveAdmin.sh
			chmod 755 /Library/.TRAMS/Scripts/RemoveAdmin.sh
		else
			echo "Admin removal script setup failed."
			exit 1 
		fi
		
		# Create plist to remove admin at next login
		
		cat << EOF > /Library/LaunchDaemons/com.Trams.adminremove.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.Trams.adminremove</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Library/.TRAMS/Scripts/RemoveAdmin.sh</string>
	</array>
	<key>RunAtLoad</key> 
	<true/>
</dict>
</plist>
EOF
		
# Permission plist
		
		if [[ -f /Library/LaunchDaemons/com.Trams.adminremove.plist ]]; then
			echo "Admin removal LaunchDaemon setup ok."
			chown root:wheel /Library/LaunchDaemons/com.Trams.adminremove.plist
			chmod 644 /Library/LaunchDaemons/com.Trams.adminremove.plist
			
		else
			echo "Admin removal LaunchDaemon setup failed."
			exit 1 
		fi
		
	fi
		
elevate 
		
sleep 5
		
adminuser=$user
	
adminpswd=$(osascript -e 'Tell application "System Events" to display dialog "To install the available macOS upgrade please enter your password" buttons {"Continue"} default button 1 with title "macOS Upgrade" with icon alias "System:Applications:Utilities:Keychain Access.app:Contents:Resources:AppIcon.icns" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
	
pswdCheck=$(dscl /Local/Default -authonly $user $adminPswd)
		
	until [[ $pswdCheck == "" ]]
		do
			echo "Password was incorrect"
			adminPswd=$(osascript -e 'Tell application "System Events" to display dialog "Password was incorrect. Please try again." buttons {"Continue"} default button 1 with title "macOS Upgrade" with icon alias "System:Applications:Utilities:Keychain Access.app:Contents:Resources:AppIcon.icns" with hidden answer default answer ""' -e 'text returned of result' 2>/dev/null)
			
			pswdCheck=$(dscl /Local/Default -authonly $user $adminPswd)
			echo $pswdCheck
		done
		
		echo "Password Validation passed. Continuing Updates....."
		sleep 5

		
	# Install macOS
	
	"$Notify" \
	-windowType hud \
	-lockHUD \
	-title "MacOS Upgrade" \
	-heading "MacOS Upgrade Installing" \
	-description "A macOS upgrade is now being Installed.
This process can take 20-60min so please do not turn off your device during this time.
Your device will Reboot automatically to finish off the install so please make sure any open work is saved." \
	-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns &
	
	OSInstaller=$(ls /Applications/ | grep -i 'install macOS' )
	
	echo $adminpswd | "/Applications/$OSInstaller/Contents/Resources/startosinstall" --agreetolicense --force --user $adminuser --stdinpass
else
	echo "Mac is Intel"

sleep 5
	
	# Install macOS
	
	"$Notify" \
	-windowType hud \
	-lockHUD \
	-title "MacOS Upgrade" \
	-heading "MacOS Upgrade Installing" \
	-description "A macOS upgrade is now being Installed.
This process can take 20-60min so please do not turn off your device during this time.
Your device will Reboot automatically to finish off the install so please make sure any open work is saved." \
	-icon /System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns &
	
	OSInstaller=$(ls /Applications/ | grep -i 'install macOS' )
	
	"/Applications/$OSInstaller/Contents/Resources/startosinstall" --agreetolicense --force
fi
