#!/bin/sh
#install.sh-FreeRADIUS
dnf -y install net-tools dmidecode
TEXTRESET=$(tput sgr0)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
INTERFACE=$(nmcli | grep "connected to" | cut -c22-)
FQDN=$(hostname)
IP=$(hostname -I)
FQDN=$(hostname)
DOMAIN=$(hostname | sed 's/^[^.:]*[.:]//' |sed -e 's/\(.*\)/\U\1/')
USER=$(whoami)
MAJOROS=$(cat /etc/redhat-release | grep -Eo "[0-9]" | sed '$d')
DETECTIP=$(nmcli -f ipv4.method con show $INTERFACE)
NMCLIIP=$(nmcli | grep inet4 | sed '$d'| cut -c7- |cut -d / -f1)
HWKVM=$(dmidecode | grep -i -e manufacturer -e product -e vendor | grep KVM | cut -c16-)
HWVMWARE=$(dmidecode | grep -i -e manufacturer -e product -e vendor | grep Manufacturer | grep "VMware, Inc." | cut -c16- | cut -d , -f1)

#Checking for user permissions
if [ "$USER" = "root" ]; then
   echo " "
else
   echo ${RED}"This program must be run as root ${TEXTRESET}"
   echo "Exiting"
fi
#Checking for version Information
if [ "$MAJOROS" = "9" ]; then
   echo " "
else
   echo ${RED}"Sorry, but this installer only works on Rocky 9.X ${TEXTRESET}"
   echo "Please upgrade to ${GREEN}Rocky 9.x${TEXTRESET}"
   echo "Exiting the installer..."
   exit
fi
clear
cat <<EOF
Checking for static IP Address
EOF
sleep 1s

#Detect Static or DHCP (IF not Static, change it)
if [ -z "$INTERFACE" ]; then
   "Usage: $0 <interface>"
   exit 1
fi

if [ "$DETECTIP" = "ipv4.method:                            auto" ]; then
   echo ${RED}"Interface $INTERFACE is using DHCP${TEXTRESET}"
   read -p "Please provide a static IP address in CIDR format (i.e 192.168.24.2/24): " IPADDR
   read -p "Please Provide a Default Gateway Address: " GW
   read -p "Please provide the FQDN of this machine: " HOSTNAME
   read -p "Please provide the IP address of the Active Dircetory server: " DNSSERVER
   read -p "Please provide the domain search name:: " DNSSEARCH
   clear

   cat <<EOF
The following changes to the system will be configured:
IP address: ${GREEN}$IPADDR${TEXTRESET}
Gateway: ${GREEN}$GW${TEXTRESET}
DNS Search: ${GREEN}$DNSSEARCH${TEXTRESET}
DNS Server: ${GREEN}$DNSSERVER${TEXTRESET}
HOSTNAME: ${GREEN}$HOSTNAME${TEXTRESET}
EOF

   read -p "Press any Key to Continue"
   nmcli con mod $INTERFACE ipv4.address $IPADDR
   nmcli con mod $INTERFACE ipv4.gateway $GW
   nmcli con mod $INTERFACE ipv4.method manual
   nmcli con mod $INTERFACE ipv4.dns-search $DNSSEARCH
   nmcli con mod $INTERFACE ipv4.dns $DNSSERVER
   hostnamectl set-hostname $HOSTNAME

   cat <<EOF
The System must reboot for the changes to take effect. ${RED}Please log back in as root.${TEXTRESET}
The installer will continue when you log back in.
If using SSH, please use the IP Address: $IPADDR
EOF
   read -p "Press Any Key to Continue"
   clear
   echo "/root/FR-Installer/install.sh" >>/root/.bash_profile
   reboot
   exit
else
   echo ${GREEN}"Interface $INTERFACE is using a static IP address ${TEXTRESET}"
fi
clear


if [ "$FQDN" = "localhost.localdomain" ]; then
  cat <<EOF
${RED}This system is still using the default hostname (localhost.localdomain)${TEXTRESET}

EOF
  read -p "Please provide a valid FQDN for this machine: " HOSTNAME
  hostnamectl set-hostname $HOSTNAME
  cat <<EOF
The System must reboot for the changes to take effect.
${RED}Please log back in as root.${TEXTRESET}
The installer will continue when you log back in.
If using SSH, please use the IP Address: ${NMCLIIP}

EOF
  read -p "Press Any Key to Continue"
  clear
  echo "/root/FR-Installer/install.sh" >>/root/.bash_profile
  reboot
  exit
fi

clear

cat <<EOF

*********************************************

This script was created for ${GREEN}Rocky 9.x${TEXTRESET}
This script will quickly configure a FreeRADIUS Server

 What this script does:
    1. Update and install all dependencies for FreeRADIUS.
    2. Add radius ports to the Firewall
    3. Integrates this server into AD
    4. Configures winbind, PEAP/MS-CHAP, MAC Auth and Mac Auth with IPSK
    5. Tests winbind, MS-CHAP and FreeRadius

*********************************************

This will take around 10-15 minutes depending on your Internet connection
and processor speed/memory

EOF
read -p "Press any Key to continue or Ctrl-C to Exit"
clear

cat <<EOF

*********************************************
Checklist:
Before the Installer starts, please make sure you have the following information

    1. ${YELLOW}An Active User in AD${TEXTRESET} that you can use to test the Radius Auth for MSCHAP.
    2. ${YELLOW}An AD Group that the User in #1 is associated${TEXTRESET}. Something like "Wireless Users".
          ${YELLOW}(FR will look for an approved Group to allow access to the network)${TEXTRESET}
          If using RADS installer (Server Management Program)
          AD Management--> Create New Group
          AD Management--> Add User
          AD Management--> Move Users to Groups
          ${RED}(Make sure your case and spacing is noted as you must put it in exactly as you created it)${TEXTRESET}
    2. ${YELLOW}An Active Admin account${TEXTRESET} that you can use to join this server to the Windows domain
    3. Verify that this server is ${YELLOW}configured to use the DNS services of AD.${TEXTRESET}
    4. Verify that you know the ${YELLOW}REALM of the AD environment${TEXTRESET} you wish to join
    5. Make sure that you know the ${YELLOW}subnet, in CIDR notation${TEXTRESET} of NAS devices this server will accept
    6. Make sure you have the ${YELLOW}password${TEXTRESET} you would like to use for your ${YELLOW}NAS devices${TEXTRESET}

*********************************************


EOF
read -p "Press any Key to continue or Ctrl-C to Exit"

clear
#Checking for VM platform-Install client
echo ${GREEN}"Installing VMGuest${TEXTRESET}"
if [ "$HWKVM" = "KVM" ]; then
  echo ${GREEN}"KVM Platform detected ${TEXTRESET}"
  echo "Installing qemu-guest-agent"
  sleep 1
  dnf -y install qemu-guest-agent
else
  echo "Not KVM Platform"
fi

#Checking for VM platform-Install client
if [ "$HWVMWARE" = "VMware" ]; then
  echo ${GREEN}"VMWARE Platform detected ${TEXTRESET}"
  echo "Installing open-vm-tools"
  sleep 1
  dnf -y install open-vm-tools
else
  echo "Not VMware Platform"
fi
clear
#Allow FreeRADIUS Ports on firewall-cmd
echo "Updating Firewall Rules"
echo "${GREEN} "
firewall-cmd --add-service=radius --permanent
firewall-cmd --reload
clear
echo ${GREEN}"These are the services/ports now open on the server${TEXTRESET}"
echo
firewall-cmd --list-services --zone=public
echo "${TEXTRESET}"
echo "The Installer will continue in a moment or Press Ctrl-C to Exit"
sleep 8s
clear
cat <<EOF
${GREEN}Downloading and installing updates${TEXTRESET}
EOF
sleep 3s
dnf -y install epel-release
dnf -y install dnf-plugins-core
dnf config-manager --set-enabled crb
dnf -y update
dnf -y install ntsysv wget open-vm-tools oddjob oddjob-mkhomedir samba-winbind samba-winbind-clients samba-common-tools freeradius freeradius-utils realmd bind-utils dmidecode
systemctl disable iscsi
systemctl disable iscsi-onboot
clear

cat <<EOF
The Installer will now ask some questions from the checklist provided earlier.
Please make sure you have this information

EOF
read -p "Press any Key to continue or Ctrl-C to Exit"
clear
read -p "Please provide the AD username for testing: " FRUSER
read -p "Please provides this user's password: " FRPASS
read -p "Please provide the AD Group we will check for membership: " GROUP
read -p "Please provide the AD Domain (CAPS Preferred) name (Realm-i.e. $DOMAIN ): " ADDOMAIN
read -p "Please provide the IP/FQDN Address of your NTP/AD Server: " NTP
read -p "Please provide the Administrator Account to join this system to AD (Just username, not UPN): " DOMAINADMIN
read -p "Please provide the subnet in CIDR notation for NAS devices to talk to radius: " CIDRNAS
read -p "Please provide the shared secret your NAS devices will be using: " NASSECRET

clear
cat <<EOF
Validating your Entries:
Radius Testing Username: ${GREEN}$FRUSER${TEXTRESET}
Radius Testing Password: ${GREEN}$FRPASS${TEXTRESET}
GRoup Membership Name: ${GREEN}$GROUP${TEXTRESET}
Domain: ${GREEN}$ADDOMAIN${TEXTRESET}
NTP Server: ${GREEN}$NTP${TEXTRESET}
AD Administrator Account: ${GREEN}$DOMAINADMIN${TEXTRESET}
NAS client Subnet: ${GREEN}$CIDRNAS${TEXTRESET}
Password for NAS devices: ${GREEN}$NASSECRET${TEXTRESET}
EOF

read -p "Press any Key to continue or Ctrl-C to Exit"
clear

cat <<EOF
Joining server to Domain $ADDOMAIN
${RED}The screen may look frozen for up to a minute after the password is entered... Please wait${TEXTRESET}
EOF
realm join -U $DOMAINADMIN --client-software=winbind $ADDOMAIN
clear

sed -i "/pool /c\server $NTP iburst" /etc/chrony.conf
sed -i "/server /c\server $NTP iburst" /etc/chrony.conf
sed -e '2d' /etc/chrony.conf
systemctl restart chronyd
clear
echo ${RED}"Syncronizing time, Please wait${TEXTRESET}"
sleep 10s
clear
chronyc tracking

echo ${GREEN}"We should be syncing time${TEXTRESET}"
echo " "
sleep 8
clear

#Validate winbind is working
cat <<EOF
${GREEN}Testing RPC to Active Directory${TEXTRESET}
EOF
echo ${GREEN}
wbinfo -t
echo ${TEXTRESET}
echo " "
echo "The Installer will continue in a moment, otherwise Ctrl-C to stop processing"
sleep 8
clear

#Validate winbind sees users
cat <<EOF
${GREEN}AD Users${TEXTRESET}
Please make sure you see your AD users.
If you do not, then please resolve this issue first before proceeding.
EOF
echo ${GREEN}
wbinfo -u
echo ${TEXTRESET}
echo " "
echo "The Installer will continue in a moment, otherwise Ctrl-C to stop processing"
sleep 8
clear

#Validate winbind groups are seen
cat <<EOF
${GREEN}AD Groups${TEXTRESET}
Please make sure you see your AD groups.
If you do not, then please resolve this issue first before proceeding.
EOF
echo ${GREEN}
wbinfo -g
echo ${TEXTRESET}
echo " "
echo "The Installer will continue in a moment, otherwise Ctrl-C to stop processing"
sleep 10
clear

#Basic test against AD
cat <<EOF
${GREEN}Test a winbind login${TEXTRESET}
We are going to login with the test account ${GREEN}($FRUSER)${TEXTRESET}. Please make sure you see a valid response of:

${GREEN}challenge/response password authentication succeeded${TEXTRESET}
If you do not, then please resolve this issue first before proceeding.

EOF
echo ${GREEN}
wbinfo -a $FRUSER%$FRPASS
echo ${TEXTRESET}
echo " "
echo "The Installer will continue in a moment, otherwise Ctrl-C to stop processing"
sleep 10
clear

#Add support for NTLM_BIND to AD
sed -i '9i \       \ ntlm auth = mschapv2-and-ntlmv2-only' /etc/samba/smb.conf

#Modify PATH and DOMAIN for ntlm_auth
echo "Adding ntlm_auth"
sed -i 's\/path/to/ntlm_auth\/usr/bin/ntlm_auth\' /etc/raddb/mods-enabled/ntlm_auth

echo "Adding proper domain"
sed -i "s/--domain=MYDOMAIN/--domain=$ADDOMAIN/" /etc/raddb/mods-enabled/ntlm_auth

#Insert ntlm_auth line 512 for inner-tunnel and default
sed -i '512i \       \ #Added by FR-Installer' /etc/raddb/sites-enabled/default
sed -i '513i \       \ ntlm_auth' /etc/raddb/sites-enabled/default

sed -i '226i \       \ #Added by FR-Installer' /etc/raddb/sites-enabled/inner-tunnel
sed -i '227i \       \ ntlm_auth' /etc/raddb/sites-enabled/inner-tunnel

#Update /etc/issue so we can see the hostname and IP address Before logging in
rm -r -f /etc/issue
touch /etc/issue
cat <<EOF >/etc/issue
\S
Kernel \r on an \m
Hostname: \n
IP Address: \4
EOF

#Change permissions for winbind
systemctl stop winbind
usermod -a -G wbpriv radiusd
chown root:wbpriv /var/lib/samba/winbindd_privileged/
systemctl start winbind

#Add Modified ntlm_auth to mschap
touch /root/FR-Installer/ntlm_auth.tmp
echo 'ntlm_auth = "/usr/bin/ntlm_auth --request-nt-key --allow-mschapv2 --username=%{mschap:User-Name:-None} --domain=%{%{mschap:NT-Domain}:-MYDOMAIN} --challenge=%{mschap:Challenge:-00} --nt-response=%{mschap:NT-Response:-00}' >>/root/FR-Installer/ntlm_auth.tmp
sed -i "s/-MYDOMAIN/-$ADDOMAIN/" /root/FR-Installer/ntlm_auth.tmp
echo "--require-membership-of='$ADDOMAIN\\$GROUP'"\" >>/root/FR-Installer/ntlm_auth.tmp
awk '{if(NR%2==0) {print var,$0} else {var=$0}}' /root/FR-Installer/ntlm_auth.tmp >/root/FR-Installer/ntlm_auth.tmp.final
sed -i '83 r /root/FR-Installer/ntlm_auth.tmp.final' /etc/raddb/mods-enabled/mschap

#Enable MAC Base Auth
touch /root/FR-Installer/rewrite_MAC
echo "rewrite_calling_station_id" >>/root/FR-Installer/rewrite_MAC
sed -i '285 r /root/FR-Installer/rewrite_MAC' /etc/raddb/sites-enabled/default

clear

#Create our client CIDR for NAS access
touch /root/FR-Installer/nasclient
cat <<EOF >/root/FR-Installer/nasclient
#Added by FR-Installer
client private-network-1 {
       ipaddr        = $CIDRNAS
       secret        = $NASSECRET
}
EOF
sed -i '249 r /root/FR-Installer/nasclient' /etc/raddb/clients.conf
clear

#Create certs
cat <<EOF
${GREEN}Certificates${TEXTRESET}
Creating the default 60 day certs

If you want to create your own self signed certs
please use the server management program (server-manager).
In the FreeRADIUS module, there is an option to generate
new certificates (Generate self-signed certs)

EOF
echo "The Installer will continue in a moment, otherwise Ctrl-C to stop processing"
sleep 10
clear

/etc/raddb/certs/bootstrap

#Start radiusd
systemctl enable radiusd
systemctl start radiusd
clear

#Test MSCHAP
cat <<EOF
${GREEN}Testing MS-CHAP from local server${TEXTRESET}
If this returns ${GREEN}Allowed${TEXTRESET}, your server is configured properly

EOF
echo "${GREEN}"
radtest -t mschap $FRUSER $FRPASS localhost 0 testing123 | grep Allowed
echo "${TEXTRESET}"
echo "The Installer will continue in a moment, otherwise Ctrl-C to stop processing"
sleep 8
clear

#Add MAC Examples to users file
touch /root/FR-Installer/mac_auth_tmp
cat <<EOF >/root/FR-Installer/mac_auth_tmp

##########################################*MAC Auth Examples*################################################
#If you are only using MAC based (Open) authentication, then the format would be the following:
#abdcef123456 Cleartext-Password := abdcef123456, Calling-Station-Id == AB-DC-EF-12-34-56
#If you are using IPSK with MAC, the following format would be needed:
#abdcef123456 Cleartext-Password := <MAC Address>, Calling-Station-Id == AB-DC-EF-12-34-56
#         Tunnel-Password = letmein <--This must be indented
#You MUST RESTART RADIUSD for a new entry to be considered active (systemctl restart radiusd)
#If you are manually editing this file, DO NOT USE server-management GUI to manage it, CHOOSE ONE OR THE OTHER APPROACH
#BEGIN SERVER-MANAGEMENT INSERTIONS
############################################################################################################
#
#
#
#
############################################################################################################
#END SERVER-MANAGEMENT INSERTIONS
#
#IF YOU ARE MANUALLY ADDING ENTRIES OR ADDING EN MASSE PLACE THEM BELOW THIS LINE
############################################################################################################
#THE FORMAT SHOULD BE 2 LINES FOR MAC AUTH (ENTRY, DESCRIPTION), 3 LINES FOR MAC AUTH iPSK (ENTRY, TUNNEL, DESCRIPTION)
#OTHERWISE IF YOU USE SERVER MANAGER TO DELETE LINES IT MAY MISTAKENLY REMOVE THE WRONG LINE
EOF

sed -i '2 r /root/FR-Installer/mac_auth_tmp' /etc/raddb/mods-config/files/authorize

cat <<EOF
${GREEN}********************************
   Server Installation Complete
********************************${TEXTRESET}

Example entries for MAC Auth and Mac with IPSK are included in:
/etc/raddb/users at the top of the file.

If all tests completed successfully, the server is now ready to serve NAS endpoints for
   1. 802.1x (PEAP and MS-CHAP)
         (Make sure your AD users are a Member of the group: ${GREEN}$GROUP${TEXTRESET})
   2. Open MAC Auth (Provide the entries in the users file or user ${GREEN}server-manager${TEXTRESET})
   3. Mac Auth with IPSK (Provide the entries in the users file or use ${GREEN}server-manager${TEXTRESET})
The Installer will continue in a moment

${YELLOW}Getting Ready to install Server Management${TEXTRESET}

EOF
sleep 12

#Clean up FR Install files
sed -i '$ d' /root/.bash_profile
rm -r -f /root/FR-Installer
rm -r -f /root/FR-Installer.sh

cat <<EOF
${GREEN}******************************
Installing Server Management
******************************${TEXTRESET}

EOF
sleep 3
cd /root/
dnf -y install wget
wget https://raw.githubusercontent.com/fumatchu/FR-RADS-SM/main/FR-RADS-SMInstaller.sh
chmod 700 ./FR-RADS-SMInstaller.sh
/root/FR-RADS-SMInstaller.sh
