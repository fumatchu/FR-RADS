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
echo "2. Download and Install FreeRADIUS"
echo "3. Configure FreeRADIUS against the already installed AD of this box"
echo "4. Configure itself for PEAP with MS-CHAP Authentication"
echo "5. Enable itself for MAC AUTH "
echo "*********************************************"
echo " "
read -p "Press Enter when you're ready"

clear
echo "We are going to need a testing user for PEAP-MSCHAP. It should already be a valid account in AD"
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

echo "Validating your Entries:"
echo " "
echo "Username: $FRUSER"
echo " "
echo "Password: $FRPASS"
echo " "
echo "Domain: $ADDOMAIN"
echo " "
read -p "Press any Key"
clear

echo "Now we need to get time from your AD Server."
echo " "
echo "Please provide the IP/FQDN Address of your NTP/AD Server:"
read NTP
echo " "
echo "You provided: $NTP"
echo " "
read -p "Press any Key"

echo "Adjusting the time for this server and restarting chrony"
echo "Please validate the settings are correct"

sed -i "/pool /c\server $NTP iburst" /etc/chrony.conf
sed -i "/server /c\server $NTP iburst" /etc/chrony.conf
sed -e '2d' /etc/chrony.conf
systemctl restart chronyd
clear
echo "Sleeping for 10 seconds for chrony"
sleep 10s
clear
chronyc tracking
echo " " 
echo " " 
echo ${green}"We should be syncing time${textreset}"
echo " "
read -p "Press Any Key"
clear 



echo "Joining the Machine to AD."
echo " "
echo "Please provide a user account that will allow you to join this server to the domain (i.e Administrator)"
echo "You will also need to provide the password when prompted"
echo " "
read DOMAINADMIN
echo " "

echo " "
echo "The screen may look frozen for a second.. Please wait"
realm join -U $DOMAINADMIN --client-software=winbind $ADDOMAIN
echo " "
echo " "

read -p "Press any Key"

clear 

echo "Checking that RPC Calls are successful"
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
echo "We are going to login with the test account. Please make sure you see a valid response of:"
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


#sed -i '15d' /filename

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
echo 'ntlm_auth = "/usr/bin/ntlm_auth --request-nt-key --allow-mschapv2 --username=%{mschap:User-Name:-None} --domain=%{%{mschap:NT-Domain}:-$ADDOMAIN} --challenge=%{mschap:Challenge:-00} --nt-response=%{mschap:NT-Response:-00}"'>>/root/FR-Installer/ntlm_auth.tmp
sed -i '83 r /root/FR-Installer/ntlm_auth.tmp' /etc/raddb/mods-enabled/mschap

#Enable MAC Base Auth 
touch /root/FR-Installer/rewrite_MAC
echo "rewrite_calling_station_id" >> /root/FR-Installer/rewrite_MAC
sed -i '285 r /root/FR-Installer/rewrite_MAC' /etc/raddb/sites-enabled/default

#Add NAS Client Subnet
echo " We are going to add the network allowed for NAS Devices to talk to FreeRADIUS"
echo "i.e This is the subnet of management IP addresses from Access Points, Switches, etc."
echo " "
echo "Please provide the NAS subnet in CIDR notation"
echo "i.e. 192.0.2.0/24"
read CIDRNAS

echo "Please provide the secret these NAS devices will be using:"
read NASSECRET

echo "You specified your network as:"
echo " "
echo "Network: $CIDRNAS"
echo " "
echo " And this is your secret"
echo "Password: $NASSECRET"
read -p "Press Any Key" 

touch /root/FR-Installer/nasclient
echo "#Added by FR-Installer" >> /root/FR-Installer/nasclient
echo "client private-network-1 {">> /root/FR-Installer/nasclient
echo "       ipaddr        = $CIDRNAS" >> /root/FR-Installer/nasclient
echo "       secret        = $NASSECRET" >>/root/FR-Installer/nasclient
echo "}" >>/root/FR-Installer/nasclient
sed -i '249 r /root/FR-Installer/nasclient' /etc/raddb/clients.conf


Create certs
echo "Creating the default 60 day certs"
echo "If you want to create your own self signed certs, please refer to"
echo "the README file in /etc/raddb/certs/ and the F Installation and configuration guide at:"
echo "https://github.com/fumatchu/FR-RADS"
read -p "Press Any Key"

/etc/raddb/certs/bootstrap
