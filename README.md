FreeRadius (R)ocky (A)ctive (D)irectory (S)cript Builder

This is a script to allow a Rocky (RHEL) Server (9.x) to become an integrated Radius server to read from AD for 802.1x
The installer will integrate this server into a pre-existing AD environment, via winbind (realmd) and configure itself for
8021.x, local MAc Auth and Mac Auth IPSK in the users file. 


####Pre-requisites
You should install Rocky from scratch. 
You should make sure the server has a static IP (the script will check).
During your setup, the hostname and domain name that you specify in the GUI installer of Rocky be what you want.
You do not need to (nor should you) install anything from dnf EXCEPT wget to grab the first installer file.


The Script will do the following:
  Validate that you have a static IP setup. If you do not it will prompt you.
  Sets SElinux
  Adds Firewall allowances
  Enable the Rocky REPOS needed to build 
    EPEL
    CRB 
Install the requirements needed by the samba source
    Modify chrony to point to point to your AD environment
    Download and install all updates
    Prompt you for time syncronization
    Join the Server to the AD domain
    Ask for an AD testing user and  password 
    Configure all files for ntlm_auth and winbind (permissions)
    Test with Wbinfo -t fopr RPC calls 
    Validate it can see Ad users and groups 
    Confirm that it can auth against AD with test user 
    Validate that MSCHAP is working from localhost. 
    Bootstrap local certificates for testing 
    Add examples for MAC auth format and IPSK at the top of the users file 
    Clean up all the install files (We like to be tidy)

####Sounds great! How do I get it?

Installing
Please see the EASY_INSTALL File 

#Installing
#Install Rocky Minimal
#Make sure you specify the domain name you want to use for AD.
#After the GUI install: 
#(Just copy and paste the following lines on the Rocky terminal)

cd /root/
dnf -y install wget 
wget https://raw.githubusercontent.com/fumatchu/RADS/main/DC-Installer.sh
chmod 700 ./DC-Installer.sh
/root/DC-Installer.sh
