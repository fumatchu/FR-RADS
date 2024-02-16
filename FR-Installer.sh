#!/bin/sh
#FR-Installer.sh #Bootstrap to GIT REPO
cat <<EOF
**************************
Please wait while we gather some files
**************************


Installing wget and git
EOF
sleep 1

dnf -y install wget git

cat <<EOF
*****************************
Retrieving Files from GitHub
*****************************
EOF

sleep 1

mkdir /root/FR-Installer

git clone https://github.com/fumatchu/FR-RADS.git /root/FR-Installer

chmod 700 /root/FR-Installer/i*
clear

/root/FR-Installer/install.sh
