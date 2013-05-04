#!/bin/sh -e

FARMFILE=$SHAREDPATH/farm

farm.listCheck() {
	[ "$1" ] && local HOSTNAME=$1
	[ -f $FARMFILE ] || touch $FARMFILE
	if ! cat $FARMFILE | fgrep -qw $HOSTNAME; then
		echo "$HOSTNAME" >> $FARMFILE && farm.listSync
	fi
}

farm.listSync() {
	csync.synctarget $FARMFILE
}

farm.getId() {
	[ "$1" ] && local HOSTNAME=$1
	cat $FARMFILE | fgrep -wn $HOSTNAME | cut -d: -f1 && return 0 || return 1
}

farm.getClusterIP() {
	echo 10.200.1.`farm.getId`
}

farm.connect() {
	local IPADDR=`cat /etc/rc.conf | tr -d '"' | grep _tap0 | cut -d' ' -f2`
	local NETMASK=`cat /etc/rc.conf | tr -d '"' | grep _tap0 | cut -d' ' -f4`
	[ -z "$IPADDR" -o -z "$NETMASK" ] && echo 'can not find ipaddr for tap0 in rc.conf, check it' && return 1
	echo "ipaddr: $IPADDR/$NETMASK"
	# -L ?
	/usr/local/sbin/tincd -n myx -R --logfile -o Name=$(hostname -s)
	return 0
}

farm.init() {
	base.file.checkLine /etc/rc.conf cloned_interfaces=\"tap0\"
	sed -i '' '/_tap0/d' /etc/rc.conf
	base.file.checkLine /etc/rc.conf ifconfig_tap0 "ifconfig_tap0=\"inet `farm.getClusterIP` netmask 255.255.255.0\""
	/etc/rc.d/netif start
	/etc/rc.d/routing start
}

#out.message 'farm: module loaded'
