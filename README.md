# macOS Patching Upgrades

Script for handling macOS major version Upgrades on Intel and M1 macs

This script will look online for the latest version of macOS and download the installer and then upgrade the device. This only works on 10.15 and newer.

Update: A 4 day deferment/postponement has been added to the script to allow users to defer a major upgrade for 4 days. After 4 days the upgrade will be forced to run.

If you are liking the work then help me stay awake to carry on writing by buying me a coffee ☕️ https://www.buymeacoffee.com/pezza

# Intel MacOS Upgrade

Intel devices will download the latest version of macOS using MIST https://github.com/ninxsoft/mist-cli. Once the OS installer is downloaded the installation will be triggered with the --agreetolicense --forcequitapps switches and the installation will automatically reboot and complete the upgrade.

# M1 MacOS Upgrade

M1 devices will download the latest version of macOS using MIST https://github.com/ninxsoft/mist-cli. The difference with M1 macs is that now the user will be prompted for their password to run the upgrade. 

If the user is not a local admin then the user will be elevated to admin and demoted after the upgrade is complete. 

