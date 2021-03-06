ACMBSD automation script for ACMCMS on FreeBSD OS

1. Install

First you need to install FreeBSD
Do next sections after you get terminal access

1.1 Get script

*Method 1. CVS
cvs -d :pserver:guest:guest@cvs.myx.ru:/var/ae3 -fq -z 6 checkout -d acmbsd acm-install-freebsd/scripts

*Method 2. GIT
Requirements: FreeBSD, Port Tree
pkg install -y git
git clone git://github.com/vlapan/acmbsd.git

1.2 Prepare system
cd acmbsd
chmod +x acmbsd.sh
./acmbsd.sh preparebsd 	# install ports and configure system
Answer "Yes" when you will see "Would you like to activate Postfix in /etc/mail/mailer.conf [n]?"
reboot

1.3 Install script
*After reboot
cd acmbsd
./acmbsd.sh install

1.4 Add new group of instances
acmbsd add live
acmbsd update live

1.5 Configure system and group

To see config command syntax and available group list execute this command:
acmbsd config

Change manager email address:
acmbsd config system -email=user@example.net

Check other system settings:
acmbsd config system

Change available memory:
acmbsd config live -memory=640m

Check other group settings:
acmbsd config live

1.6 Start group of instances
acmbsd start live

1.7 Adding new host to cluster
acmbsd cluster activate
acmbsd cluster addto -host=user@cluster.example.org
acmbsd cluster cron -enable=true
* Note: 'cluster.example.org' it's host that already in cluster
