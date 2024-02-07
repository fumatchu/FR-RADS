#!/bin/sh
#install.sh-FreeRADIUS
textreset=$(tput sgr0)
red=$(tput setaf 1)
yellow=$(tput setaf 3)
green=$(tput setaf 2)
interface=$(nmcli | grep "connected to" | cut -c22-)
FQDN=$(hostname)
IP=$(hostname -I)
FQDN=$(hostname)
majoros=$(cat /etc/redhat-release | grep -Eo "[0-9]" | sed '$d')
minoros=$(cat /etc/redhat-release | grep -Eo "[0-9]" | sed '1d')
cat <<stop
Checking for static IP Address
stop
sleep 1s
#Detect Static or DHCP (IF not Static, change it)
if [ -z "$interface" ]; then
   "Usage: $0 <interface>"
  exit 1
fi
method=$(nmcli -f ipv4.method con show $interface)
if [ "$method" = "ipv4.method:                            auto" ]; then
echo  ${red}"Interface $interface is using DHCP${textreset}"
read -p "Please provide a static IP address in CIDR format (i.e 192.168.24.2/24): " IPADDR
read -p "Please provide a Default Gateway Address: " GW
read -p "Please provide the domain search name (i.e. domain.com): " DNSSEARCH
read -p "Please provide an upstream DNS IP for resolution (AD Server): " DNSSERVER
read -p "Please provide the FQDN of this machine (i.e. machine.domain.com) " HOSTNAME  
clear
cat <<EOF
The following changes to the system will be configured:
IP address: ${green}$IPADDR${textreset}
Gateway: ${green}$GW${textreset}
DNS Search: ${green}$DNSSEARCH${textreset}
DNS Server: ${green}$DNSSERVER${textreset}
HOSTNAME: ${green}$HOSTNAME${textreset}
EOF
  read -p "Press any Key to Continue"
  nmcli con mod $interface ipv4.address $IPADDR
  nmcli con mod $interface ipv4.gateway $GW
  nmcli con mod $interface ipv4.method manual
  nmcli con mod $interface ipv4.dns-search $DNSSEARCH
  nmcli con mod $interface ipv4.dns $DNSSERVER
  hostnamectl set-hostname $HOSTNAME
cat <<EOF
The System must reboot for the changes to take effect. ${red}Please log back in as root.${textreset}
The installer will continue when you log back in.
If using SSH, please use the IP Address: $IPADDR
EOF
  read -p "Press Any Key to Continue"
  clear
  echo "/root/FR-Installer/install.sh" >> /root/.bash_profile
  reboot 
  exit
else
echo   ${green}"Interface $interface is using a static IP address ${textreset}"
fi
clear
#Checking for version Information
if [ "$majoros" != "9" ]; then
echo ${red}"Sorry, but this installer only works on Rocky 9.X ${textreset}"
echo "Please upgrade to ${green}Rocky 9.x${textreset}"
echo "Exiting the installer..."
exit 
else
echo ${green}"Version information matches..Continuing${textreset}"
fi
clear
cat <<EOF
*********************************************

This script was created for ${green}Rocky 9.x${textreset}
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

    1. ${yellow}An Active User in AD${textreset} that you can use to test the Radius Auth for MSCHAP.
    2. ${yellow}An Active Admin account${textreset} that you can use to join this server to the Windows domain
    3. Verify that this server is ${yellow}configured to use the DNS services of AD.${textreset}
    4. Verify that you know the ${yellow}REALM of the AD environment${textreset} you wish to join
    5. Make sure that you know the ${yellow}subnet, in CIDR notation${textreset} of NAS devices this server will accept
    6. Make sure you have the ${yellow}password${textreset} you would like to use for your ${yellow}NAS devices${textreset} 

*********************************************
EOF
read -p "Press any Key to continue or Ctrl-C to Exit"
clear
#Allow FreeRADIUS Ports on firewall-cmd
echo "Updating Firewall Rules"
echo "${green} "
firewall-cmd --add-service=radius --permanent
firewall-cmd --reload
clear
echo ${green}"These are the services/ports now open on the server${textreset}"
echo
firewall-cmd --list-services --zone=public
echo "${textreset}"
echo "The Installer will continue in a moment or Press Ctrl-C to Exit"
sleep 8s
clear
dnf -y install epel-release
dnf -y install dnf-plugins-core
dnf config-manager --set-enabled crb
dnf -y update 
dnf -y install cockpit cockpit-storaged ntsysv wget open-vm-tools freeradius freeradius-utils realmd
systemctl enable cockpit.socket 
systemctl disable iscsi
systemctl disable iscsi-onboot
clear
cat <<EOF
Please provide the following information:
EOF
read -p "Please provide the AD username for testing: " FRUSER
read -p "Please provide this user's password: " FRPASS
read -p "Please provide the (CAPS Preferred) REALM name (i.e. CONTOSO.COM): " ADDOMAIN
read -p "Please provide the IP/FQDN Address of your NTP/AD Server: " NTP
read -p "Please provide the Administrator Account to join this system to AD: " DOMAINADMIN
read -p "Please provide the subnet in CIDR notation for NAS devices to talk to radius: " CIDRNAS
read -p "Please provide the password your NAS devices will be using: " NASSECRET
clear
cat <<EOF
Validating your Entries:
Radius Testing Username: ${green}$FRUSER${textreset}
Radius Testing Password: ${green}$FRPASS${textreset} 
Domain: ${green}$ADDOMAIN${textreset}
NTP Server: ${green}$NTP${textreset}
AD Administrator Account: ${green}$DOMAINADMIN${textreset}
NAS client Subnet: ${green}$CIDRNAS${textreset}
Password for NAS devices: ${green}$NASSECRET${textreset}
EOF
read -p "Press any Key to continue or Ctrl-C to Exit"
clear
sed -i "/pool /c\server $NTP iburst" /etc/chrony.conf
sed -i "/server /c\server $NTP iburst" /etc/chrony.conf
sed -e '2d' /etc/chrony.conf
systemctl restart chronyd
clear
echo ${red}"Syncronizing time, Please wait${textreset}"
sleep 10s
clear
chronyc tracking
echo ${green}"We should be syncing time${textreset}"
echo " "
sleep 8
clear 
cat  <<EOF
Joining server to Domain $ADDOMAIN 
Please enter the Admin Password:
${red}The screen may look frozen for a second after the password is entered... Please wait${textreset}
EOF
realm join -U $DOMAINADMIN --client-software=winbind $ADDOMAIN
clear
cat <<EOF
Checking that RPC Calls are successful to Active Directory
EOF
echo ${green}
wbinfo -t
echo ${textreset}
#Validate winbind is working 
cat <<EOF
Please make sure you see your AD users.
If you do not, then please resolve this issue first before proceeding.
EOF
echo ${green}
wbinfo -u
echo ${textreset}
echo " "
read -p "If successful, press any Key, otherwise Ctrl-C to stop processing"
echo " "
clear
#Validate Winbind Groups are seen
cat <<EOF
Please make sure you see your AD groups.
If you do not, then please resolve this issue first before proceeding.
EOF
echo ${green}
wbinfo -g
echo ${textreset}
echo " "
read -p "If successful, press any Key, otherwise Ctrl-C to stop processing"
clear
#Basic test against AD
cat <<EOF
We are going to login with the test account ($FRUSER). Please make sure you see a valid response of:

${green}challenge/response password authentication succeeded${textreset}

If you do not, then please resolve this issue first before proceeding.
${yellow}
Logging in with:
${textreset}
EOF
echo ${green}
echo wbinfo -a $FRUSER%$FRPASS
wbinfo -a $FRUSER%$FRPASS | grep challenge
echo ${textreset}
read -p "If successful, press any Key, otherwise Ctrl-C to stop processing"

#Add support for NTLM_BIND to AD
sed -i '9i \       \ ntlm auth = mschapv2-and-ntlmv2-only' /etc/samba/smb.conf
#Modify PATH and DOMAIN
echo "Adding ntlm_auth"
sed -i 's\/path/to/ntlm_auth\/usr/bin/ntlm_auth\' /etc/raddb/mods-enabled/ntlm_auth
sed -i "s/--domain=MYDOMAIN/--domain=$ADDOMAIN/" /etc/raddb/mods-enabled/ntlm_auth
#insert ntlm_auth line 512
sed -i '512i \       \ #Added by FR-Installer' /etc/raddb/sites-enabled/default
sed -i '513i \       \ ntlm_auth' /etc/raddb/sites-enabled/default
sed -i '226i \       \ #Added by FR-Installer' /etc/raddb/sites-enabled/inner-tunnel
sed -i '227i \       \ ntlm_auth' /etc/raddb/sites-enabled/inner-tunnel
#Change permissions for winbind
systemctl stop winbind
usermod -a -G wbpriv radiusd
chown root:wbpriv /var/lib/samba/winbindd_privileged/
systemctl start winbind
#Add Modified ntlm_auth to mschap
touch /root/FR-Installer/ntlm_auth.tmp
echo 'ntlm_auth = "/usr/bin/ntlm_auth --request-nt-key --allow-mschapv2 --username=%{mschap:User-Name:-None} --domain=%{%{mschap:NT-Domain}:-MYDOMAIN} --challenge=%{mschap:Challenge:-00} --nt-response=%{mschap:NT-Response:-00}"'>>/root/FR-Installer/ntlm_auth.tmp
sed -i "s/-MYDOMAIN/-$ADDOMAIN/" /root/FR-Installer/ntlm_auth.tmp
sed -i '83 r /root/FR-Installer/ntlm_auth.tmp' /etc/raddb/mods-enabled/mschap
#Enable MAC Base Auth 
touch /root/FR-Installer/rewrite_MAC
echo "rewrite_calling_station_id" >> /root/FR-Installer/rewrite_MAC
sed -i '285 r /root/FR-Installer/rewrite_MAC' /etc/raddb/sites-enabled/default
clear
touch /root/FR-Installer/nasclient
cat <<EOF > /root/FR-Installer/nasclient
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
Creating the default 60 day certs

If you want to create your own self signed certs, please refer to
the README file in /etc/raddb/certs/ and the Installation and configuration guide at:
https://github.com/fumatchu/FR-RADS
EOF
read -p "Press Any Key to continue"
/etc/raddb/certs/bootstrap
#Start radiusd
echo "Starting radiusd and enabling for boot time"
systemctl enable radiusd
systemctl start radiusd 
clear
#Test MSCHAP
cat <<EOF
We are going to test MSCHAP from the local server
If this returns ${green}MS-MPPE-Encryption-Policy = Encryption-Allowed${textreset}, your server is configured properly
EOF
echo "${green}"
radtest -t mschap $FRUSER $FRPASS localhost 0 testing123
echo "${textreset}"
#Add MAC Examples to users file
touch /root/FR-Installer/mac_auth_tmp
cat <<EOF > /root/FR-Installer/mac_auth_tmp

#####MAC Auth Examples#####" >> /root/FR-Installer/mac_auth_tmp
#If you are only using MAC based (Open) authentication, then the format would be the following:
#<MAC Address> Cleartext-Password := <MAC Address>, Calling-Station-Id == <MAC Address in CAPS with hyphens>
#This is an example:
#abdcef123456 Cleartext-Password := abdcef123456, Calling-Station-Id == AB-DC-EF-12-34-56

#If you are using IPSK with MAC, the following format would be needed:
#<MAC Address> Cleartext-Password := <MAC Address>, Calling-Station-Id == <MAC Address in CAPS with hyphens>
#         Tunnel-Password = <Tunnel Password>"
#You MUST restart radiusd for a new entry to be registered"
EOF

sed -i '2 r /root/FR-Installer/mac_auth_tmp' /etc/raddb/mods-config/files/authorize
cat <<EOF
***********************
 Installation Complete
***********************
If you want to use MAC Based Auth or IPSK with MAC Auth, please refer to the file:
/etc/raddb/users (For Examples, at the top of the file)
EOF
read -p "Press any Key to continue" 
#clean up our mess
sed -i '$ d' /root/.bash_profile
rm -r -f /root/FR-Installer
rm -r -f /root/FR-Installer.sh
cat <<EOF
It's suggested to reboot the Server now
EOF

while true; do

read -p "Do you want to reboot now? (y/n) " yn

case $yn in 
   [yY] ) reboot;
      break;;
   [nN] ) echo exiting...;
      exit;;
   * ) echo invalid response;;
esac

done
exit
