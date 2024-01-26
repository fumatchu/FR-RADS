#!/bin/sh
#Install1-FreeRADIUS
textreset=$(tput sgr0) # reset the foreground colour
red=$(tput setaf 1)
yellow=$(tput setaf 3)
green=$(tput setaf 2)
echo " "
echo " "
echo "*********************************************"
echo " "
echo "This script was created for ${green}Rocky 9.x${textreset}"
echo "This script will quickly configure a FreeRADIUS Server"
echo "There will be some manual intervention needed later in the install" 
echo "for final configuration."
echo " "
echo "What this script does:"
echo "1. Disable SELINUX"
echo "2. Add Radius ports to the Firewall"
echo "2. Disable un-needed Services"
echo "2. Install the REPO(s) needed"
echo "3. Install all dependencies"
echo ${red}"4. After the Server restarts, PLEASE LOG BACK IN as root to continue${textreset}"
echo " "
echo "*********************************************"
echo " "
echo "This will take around 10-15 minutes depending on your Internet connection"
echo "and processor speed/memory"
echo " "
echo ${red}"PLEASE NOTE: When you setup your server via the Rocky installer,"
echo "You should have specified the static IP and FQDN of this machine"
echo "It is assumed this is the correct information and will be utilized for the install."
echo "If this information is not correct, i.e. ip address, hostname, domain name, use${textreset} ${yellow}nmtui${textreset} ${red}to modify it,"
echo "and start the installer again${textreset}"
read -p "Press Enter to conitnue or CtrL-C to terminate the installer"



sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

clear
#Allow FreeRADIUS Ports on firewall-cmd
echo "Updating Firewall Rules"
echo "${green} "
firewall-cmd --add-service=radius --permanent
firewall-cmd --reload
echo ${green}"These are the services/ports now open on the server${textreset}"
echo
firewall-cmd --list-services --zone=public
echo "${textreset}"

read -p "Press Any Key to Continue"

dnf -y install epel-release
dnf -y install dnf-plugins-core
dnf config-manager --set-enabled crb
dnf -y update 

dnf -y install cockpit cockpit-storaged ntsysv wget open-vm-tools freeradius freeradius-utils realmd

systemctl enable cockpit.socket 

systemctl disable iscsi
systemctl disable iscsi-onboot

echo "/root/FR-Installer/install2.sh" >> /root/.bash_profile

clear
echo " "
echo "************************************************ "
echo "The Server is ready to reboot"
echo ${red}"Please make sure you are logging back in as root"
echo "for the second part of the install${textreset}"
echo "************************************************ "
echo " "
read -p "Press Any key when you're ready"
reboot
