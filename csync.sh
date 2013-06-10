#!/bin/sh

CSYNCPIDFILE=$LOCKDIRPATH/csync.pid
csync.sync() {
	/usr/sbin/daemon -p $CSYNCPIDFILE /usr/local/sbin/csync2 -vrx && [ -z "$1" ] && return 0
	sleep 1
	CSYNCPID=`cat $CSYNCPIDFILE`
	while true; do
		System.daemon.isExist $CSYNCPID || break
		sleep 1
	done
}
csync.synctarget() {
	/usr/sbin/daemon -p $CSYNCPIDFILE /usr/local/sbin/csync2 -vx $@
}
csync.syncinit() {
	if [ "$1" ]; then
		out.message "sync with $1"
		/usr/sbin/daemon -p $CSYNCPIDFILE /usr/local/sbin/csync2 -vrTI $HOSTNAME $1
		sleep 1
		CSYNCPID=`cat $CSYNCPIDFILE`
		while true; do
			System.daemon.isExist $CSYNCPID || break
			sleep 1
		done
		/usr/sbin/daemon -p $CSYNCPIDFILE /usr/local/sbin/csync2 -f /etc/hosts /usr/local/etc/csync2.cfg
		sleep 1
		CSYNCPID=`cat $CSYNCPIDFILE`
		while true; do
			System.daemon.isExist $CSYNCPID || break
			sleep 1
		done
		csync.sync wait
	else
		out.error 'give me hostname!'
	fi
}
csync.crontab() {
	local TIME=15
	[ "$1" ] && TIME=$1
	echo "*/$TIME * * * * root /usr/sbin/daemon -p $CSYNCPIDFILE /usr/local/sbin/csync2 -vxr"
}

csync.makecert() {
	cat <<-EOF
		PWDBAK=\`pwd\`
		DIRNAME=\`cat distinfo | grep SIZE | cut -d"(" -f2 | cut -d"." -f1-2\`
		cd $PWDBAK/work/$DIRNAME
		make cert
		cd $PWDBAK
	EOF
}

csync.check() {
	pkg.install.port gnutls security/gnutls
	pkg.install.port csync2 net/csync2 csync.makecert
	chmod 4550 /usr/local/sbin/csync2
}

#out.message 'csync: module loaded'
