#!/bin/sh
#Install2-FreeRADIUS
textreset=$(tput sgr0) # reset the foreground colour
red=$(tput setaf 1)
yellow=$(tput setaf 3)
green=$(tput setaf 2)
IP=$(hostname -I)
DOMAIN=$(hostname | sed 's/...//')
FQDN=$(hostname)


clear
echo " "
echo " "
echo "*********************************************"
echo " "
echo "This script will install FreeRADIUS on this server."
echo " "
echo "What this script does:"
echo "1. Validate winbind is functional"
echo "2. Configure this server for Active Directory Join"
echo "3. Configure itself for PEAP with MS-CHAP Authentication"
echo "3. Enable itself for MAC AUTH "
echo "*********************************************"
echo " "
read -p "Press Enter when you're ready"

clear
echo "We are going to need a testing user for MSCHAP. It should already be a valid account in Active Directory"
echo "Please provide the username and password for this account and the DOMAIN (REALM)"
echo " "
echo "Please provide the AD username:"
read FRUSER
echo " "
echo "Please provides this user's password:"
read FRPASS
echo " "
echo "Please provide the AD Domain name (Realm):"
echo "All CAPS (i.e TEST.INT)"
echo " "
read ADDOMAIN
clear
echo "Validating your Entries:"
echo " "
echo "Username: ${green}$FRUSER${textreset}"
echo " "
echo "Password: ${green}$FRPASS${textreset} "
echo " "
echo "Domain: ${green}$ADDOMAIN${textreset}"
echo " "
read -p "Press any Key"
clear

echo "Now we need to get time from your AD Server."
echo " "
echo "Please provide the IP/FQDN Address of your NTP/AD Server:"
read NTP
clear
echo " "
echo "You provided: ${green}$NTP${textreset}"
echo " "
read -p "Press any Key"

sed -i "/pool /c\server $NTP iburst" /etc/chrony.conf
sed -i "/server /c\server $NTP iburst" /etc/chrony.conf
sed -e '2d' /etc/chrony.conf
systemctl restart chronyd
clear
echo ${red}"Syncronizing time, Please wait${textreset}"
sleep 10s
clear
chronyc tracking
echo " " 
echo " " 
echo ${green}"We should be syncing time${textreset}"
echo " "
read -p "Press Any Key"
clear 



echo "Joining the Machine to Active Directory."
echo " "
echo "Please provide a user account that will allow you to join this server to the domain (i.e Administrator)"
echo "Make sure it is just the username. WE DO NOT need the UPN of the account here"
echo "You will also need to provide the password when prompted"
echo " "
read DOMAINADMIN
echo " "

echo " "
echo ${red}"The screen may look frozen for a second.. Please wait${textreset}"
realm join -U $DOMAINADMIN --client-software=winbind $ADDOMAIN
echo " "
echo " "

read -p "Press any Key"

clear 

echo "Checking that RPC Calls are successful to Active Directory"
echo " "
echo ${green}
wbinfo -t
echo ${textreset}
echo " "


#Validate winbind is working 
echo "We are going to run wbinfo. Please make sure you see your AD users."
echo "If you do not, then please resolve this issue first before proceeding."
echo " "
echo ${green}
wbinfo -u
echo ${textreset}
echo " "
read -p "If successful, press any Key, otherwise Ctrl-C to stop processing"
echo " "
clear
#Validate Winbind Groups are seen
echo "We are going to run wbinfo. Please make sure you see your AD groups."
echo "If you do not, then please resolve this issue first before proceeding."
echo " "
echo ${green}
wbinfo -g
echo ${textreset}
echo " "
read -p "If successful, press any Key, otherwise Ctrl-C to stop processing"
echo " "
clear
#Basic test against AD
echo "We are going to login with the test account($FRUSER). Please make sure you see a valid response of:"
echo " "
echo ${green}"challenge/response password authentication succeeded${textreset}"
echo " "
echo "If you do not, then please resolve this issue first before proceeding."
echo " "
echo ${green}
echo wbinfo -a $FRUSER%$FRPASS
wbinfo -a $FRUSER%$FRPASS
echo ${textreset}
echo " "
read -p "If successful, press any Key, otherwise Ctrl-C to stop processing"

#Add support for NTLM_BIND to AD
sed -i '9i \       \ ntlm auth = mschapv2-and-ntlmv2-only' /etc/samba/smb.conf

#Modify PATH and DOMAIN
echo "Adding ntlm_auth"
sed -i 's\/path/to/ntlm_auth\/usr/bin/ntlm_auth\' /etc/raddb/mods-enabled/ntlm_auth

echo "Adding proper domain"
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
#Add NAS Client Subnet
echo "We are going to add the network/subnet for NAS Devices to talk to FreeRADIUS"
echo "i.e This is the subnet of management IP addresses from Access Points, Switches, etc."
echo "You can always add more than one in /etc/raddb/clients.conf"
echo " "
echo "Please provide the subnet in CIDR notation"
echo "(i.e. 192.0.2.0/24)"
echo " "
read CIDRNAS

echo "Please provide the secret these NAS devices will be using:"
read NASSECRET
clear
echo "You specified your network as:"
echo " "
echo "Network: ${green}$CIDRNAS${textreset}"
echo " "
echo "And this is your secret"
echo " "
echo "Password: ${green}$NASSECRET${textreset}"
read -p "Press Any Key" 
clear
touch /root/FR-Installer/nasclient
echo "#Added by FR-Installer" >> /root/FR-Installer/nasclient
echo "client private-network-1 {">> /root/FR-Installer/nasclient
echo "       ipaddr        = $CIDRNAS" >> /root/FR-Installer/nasclient
echo "       secret        = $NASSECRET" >>/root/FR-Installer/nasclient
echo "}" >>/root/FR-Installer/nasclient
sed -i '249 r /root/FR-Installer/nasclient' /etc/raddb/clients.conf
clear

#Create certs
echo "Creating the default 60 day certs"
echo "If you want to create your own self signed certs, please refer to"
echo "the README file in /etc/raddb/certs/ and the Installation and configuration guide at:"
echo "https://github.com/fumatchu/FR-RADS"
read -p "Press Any Key"

/etc/raddb/certs/bootstrap

#Start radiusd
echo "Starting radiusd and enabling for boot time"
systemctl enable radiusd
systemctl start radiusd 
clear
#Test MSCHAP
echo "We are going to test MSCHAP from the local server"
echo "If this returns allowed, your server is configured properly"
echo "${green}"
radtest -t mschap $FRUSER $FRPASS localhost 0 testing123
echo "${textreset}"

#clean up our mess
sed -i '$ d' /root/.bash_profile
rm -r -f /root/FR-Installer
rm -r -f /root/FR-Installer.sh
