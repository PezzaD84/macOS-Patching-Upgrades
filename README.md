# macOS Patching Upgrades

Script for handling macOS major version Upgrades on Intel and M1 macs

This script will look online for the latest version of macOS and download the installer and then upgrade the device. This only works on 10.15 and newer.

Update: A 4 day deferment/postponement has been added to the script to allow users to defer a mojor upgrade for 4 days. After 4 days the upgrade will be forced to run.

# Intel MacOS Upgrade

Intel devices will download the latest version of macOS using the softwareupdate command. Once the OS installer is downloaded the installation will be triggered with the --agreetolicense --forcequitapps switches and the installation will automatically reboot and complete the upgrade.

# M1 MacOS Upgrade

M1 devices will download the latest version of macOS using the softwareupdate command. The difference with M1 macs is that now the user will be prompted for their password to run the upgrade. 

If the user is not a local admin then the user will be prompted for the password of the local admin account to run the upgrade. 
There is an extra part of the script which can elevate the user to an admin to carry out the upgrade and then an extra script can be added after the upgrade is complete to demote the user back to a standard user.

There are 2 versions of the script with different ways to enable the elevate user function. One script uses a switch and the other needs the elevate functions unhashed.

The switch version will run with -e added after the script.
The other version will need line 35 unhashed.
