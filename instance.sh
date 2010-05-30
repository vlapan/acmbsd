#!/bin/sh
# acmbsd lib: Instance type
THIS.init() {
	echo "Instance 'THIS' object init..."
	#TODO: use from Group instead of fields
	export THIS_GROUPNAME=`echo THIS | tr -d '[0-9]'`
	export THIS_GROUPHOME=`$THIS_GROUPNAME.getField HOME`
	export THIS_GROUPID=`$THIS_GROUPNAME.getField ID`
	export THIS_GROUPLOGS=`$THIS_GROUPNAME.getField LOGS`

	export THIS_ID=`echo THIS | tr -d '[a-z]'`
	export THIS_HOME=$THIS_GROUPHOME/THIS-private
	export THIS_INTIP=172.16.0.$(($THIS_GROUPID+$THIS_ID-1))
	export THIS_OUT=$THIS_GROUPLOGS/stdout-THIS
	export THIS_OUTPREV=$THIS_GROUPLOGS/stdout-THIS.prev
	export THIS_RESTARTFILE=$THIS_HOME/control/restart
	export THIS_DAEMONFLAG=$THIS_HOME/daemon.flag
}
THIS.debug() {
	echo
	echo "ISACTIVE=`THIS.isActive > /dev/null && echo true || echo false`"
	echo "PID=`THIS.getPID`"
	echo "TYPE=`THIS.getType`"
	echo "NAME=THIS"
	echo "ID=$THIS_ID"
	echo "HOME=$THIS_HOME"
	echo "INTIP=$THIS_INTIP"
	echo "OUT=$THIS_OUT"
	echo "OUTPREV=$THIS_OUTPREV"
	echo "RESTARTFILE=$THIS_RESTARTFILE"
	echo "DAEMONFLAG=$THIS_DAEMONFLAG"
}
THIS.isExist() {
	test -d $THIS_HOME && return 0 || return 1
}
THIS.isActive() {
	System.message "Check instance 'THIS' daemon..." waitstatus
	if [ ! -f "`THIS.getField DAEMONFLAG`" ]; then
		System.print.status yellow OFFLINE && return 1
	else
		PID=`THIS.getPID`
		if System.daemon.isExist $PID ; then
			System.print.status green ONLINE && return 0
		fi
	fi
	System.print.status yellow OFFLINE && return 1
}
THIS.getPID() {
	[ -f "$THIS_DAEMONFLAG" ] && cat $THIS_DAEMONFLAG || echo STOPPED
}
THIS.getVersion() {
	[ -f "$THIS_VERSIONFILE" ] && cat $THIS_VERSIONFILE || echo 0
}
THIS.add() {
	echo "Add instance (THIS)..."
	THIS.setHierarchy || return 1
	${THIS_GROUPNAME}.isActive && THIS.start
	return 0
}
THIS.remove() {
	THIS.isExist || return 1
	THIS.isActive && THIS.stop
	echo "Remove instance (THIS)..."
	echo -n 'Removing instance private folder...'
	rm -rdf ${THIS_PRIVATE} && System.print.status green DONE || System.print.status red ERROR
	echo -n 'Removing user...'
	pw userdel THIS > /dev/null 2>&1 && System.print.status green DONE || System.print.status red ERROR
	echo "Instance (THIS) removed!"
}
THIS.openToPublic() {
	test "$($THIS_GROUPNAME.getExtIP)" || return 1
	System.message "Opening 'THIS' to internet..." waitstatus
	cat /etc/ipf/ipnat.conf | sed -l "/THIS/d" > /tmp/ipnat.conf && mv /tmp/ipnat.conf /etc/ipf
	for IP in $($THIS_GROUPNAME.getExtIP | tr ',' ' '); do
		EXTINTERFACE=$(Network.getInterfaceByIP "${IP}")
		echo "rdr ${EXTINTERFACE} ${IP}/255.255.255.255 port 80 -> ${THIS_INTIP} port 14080 round-robin # THIS" >> /etc/ipf/ipnat.conf 
		echo "rdr ${EXTINTERFACE} ${IP}/255.255.255.255 port 443 -> ${THIS_INTIP} port 14443 round-robin # THIS" >> /etc/ipf/ipnat.conf
		echo "rdr ${EXTINTERFACE} ${IP}/255.255.255.255 port 14022 -> ${THIS_INTIP} port 14022 round-robin # THIS" >> /etc/ipf/ipnat.conf 
		echo "rdr lo0 ${IP}/255.255.255.255 port 80 -> ${THIS_INTIP} port 14080 round-robin # THIS" >> /etc/ipf/ipnat.conf 
		echo "rdr lo0 ${IP}/255.255.255.255 port 443 -> ${THIS_INTIP} port 14443 round-robin # THIS" >> /etc/ipf/ipnat.conf
		echo "rdr lo0 ${IP}/255.255.255.255 port 14022 -> ${THIS_INTIP} port 14022 round-robin # THIS" >> /etc/ipf/ipnat.conf 
	done
	System.print.status green DONE
	THIS.reloadIPNAT
	return 0
}
THIS.closeFromPublic() {
	System.message "Closing 'THIS' from internet..." waitstatus
	cat /etc/ipf/ipnat.conf | sed -l "/THIS/d" > /tmp/ipnat.conf && mv /tmp/ipnat.conf /etc/ipf
	System.print.status green DONE
	THIS.reloadIPNAT
	return 0
}
THIS.isPublic() {
	cat /etc/ipf/ipnat.conf | fgrep -wq THIS && return 0 || return 1
}
THIS.reloadIPNAT(){
	System.message 'Reloading ipnat rules...' waitstatus
	if /etc/rc.d/ipnat reload > /dev/null 2>&1; then
		System.print.status green DONE
	else
		System.print.status red ERROR
	fi
}
THIS.setHierarchy() {
	echo -n "Check user 'THIS'..."
	if pw usershow THIS > /dev/null 2>&1; then
		System.print.status green OK
	else
		if pw useradd -d ${THIS_GROUPHOME} -n THIS -g ${THIS_GROUPNAME} -h - > /dev/null 2>&1; then
			System.print.status green ADDED
			echo -n "Adding user 'THIS' to group '${THIS_GROUPNAME}'..."
			if pw groupmod ${THIS_GROUPNAME} -m THIS > /dev/null 2>&1; then
				System.print.status green ADDED
			else
				System.print.status red ERROR && return 1
			fi
		else
			System.print.status red ERROR && return 1
		fi
	fi
	System.fs.dir.create ${THIS_HOME} || return 1
	System.changeRights ${THIS_HOME} ${THIS_GROUPNAME} THIS || return 1
}
THIS.setStartTime() {
	Config.setting.setValue THIS-starttime `date '+%s'`
}
THIS.getStartTime() {
	Config.setting.getValue THIS-starttime
}
THIS.startDaemon() {
	THIS.setStartTime
	System.fs.dir.create ${THIS_GROUPLOGS} > /dev/null 2>&1
	local PROGEXEC="java -server"
	test "`${THIS_GROUPNAME}.getEA`" = enable && PROGEXEC="$PROGEXEC -ea"
	PROGEXEC="${PROGEXEC} -Duser.home=${THIS_GROUPHOME}"
	PROGEXEC="${PROGEXEC} -Dru.myx.ae3.properties.groupname=${THIS_GROUPNAME}"
	PROGEXEC="${PROGEXEC} -Dru.myx.ae3.properties.hostname=${THIS_GROUPNAME}.`hostname`"
	PROGEXEC="${PROGEXEC} -Dru.myx.ae3.properties.log.level=`${THIS_GROUPNAME}.getLogLevel`"
	PROGEXEC="${PROGEXEC} -Dru.myx.ae3.properties.ip.wildcard.host=${THIS_INTIP}"
	PROGEXEC="${PROGEXEC} -Dru.myx.ae3.properties.ip.shift.port=14000"
	PROGEXEC="${PROGEXEC} -Dru.myx.ae3.properties.path.private=${THIS_HOME}"
	PROGEXEC="${PROGEXEC} -Dru.myx.ae3.properties.path.shared=${SHAREDPATH}"
	PROGEXEC="${PROGEXEC} -Dru.myx.ae3.properties.path.protected=`${THIS_GROUPNAME}.getField PROTECTED`"
	PROGEXEC="${PROGEXEC} -Dru.myx.ae3.properties.path.logs=${THIS_GROUPLOGS}"
	ADMINMAIL=`Config.setting.getValue adminmail`
	test "${ADMINMAIL}" && PROGEXEC="${PROGEXEC} -Dru.myx.ae3.properties.report.mailto=${ADMINMAIL}"
	PROGEXEC="${PROGEXEC} -Djava.net.preferIPv4Stack=true"
	PROGEXEC="${PROGEXEC} -Djava.awt.headless=true"
	PROGEXEC="${PROGEXEC} -Dfile.encoding=CP1251"
	PROGEXEC="${PROGEXEC} -Xmx`${THIS_GROUPNAME}.getMemory`"
	PROGEXEC="${PROGEXEC} -Xms`${THIS_GROUPNAME}.getMemory`"
	PROGEXEC="${PROGEXEC} -jar boot.jar"
	if [ -e "${THIS_OUT}" ]; then
		cp ${THIS_OUT} ${THIS_OUTPREV}
	fi
	echo "${PROGEXEC}" > ${THIS_HOME}/progexec
	System.message "Starting 'THIS' instance daemon..." waitstatus
	if su - THIS -c "umask 002 && cd `${THIS_GROUPNAME}.getField PUBLIC` && /usr/sbin/daemon -p ${THIS_DAEMONFLAG} ${PROGEXEC} > ${THIS_OUT} 2>&1"; then
		System.print.status green DONE && return 0
	else
		System.print.status red ERROR && return 1
	fi
}
THIS.start() {
	THIS.isActive && return 1
	#THIS.setHierarchy
	THIS.reset
	if [ -f ${THIS_RESTARTFILE} ]; then
		/bin/rm ${THIS_RESTARTFILE}
	fi
	ipcontrol bind lo0 ${THIS_INTIP}
	THIS.startDaemon || return 1
	System.message 'Waiting for instance to start' waitstatus
	local COUNT=0
	local CANFAIL=true
	local STARTEDSERVERS=''
	while true
	do
		printf .
		sleep 1
		COUNT=$((COUNT + 1))
		if [ "$1" -a "$1" = wait ]; then
			if [ -f ${THIS_RESTARTFILE} -a -f ${THIS_OUT} ]; then
				CANFAIL=false
				NEWSTARTEDSERVERS=`cat ${THIS_OUT} | fgrep starting: | cut -d' ' -f5 | tr '\n' ' '`
				for ITEM in ${NEWSTARTEDSERVERS}; do
					if [ -z "`echo ${STARTEDSERVERS} | fgrep -w ${ITEM}`" ]; then
						printf " \33[1m${ITEM}\33[0m "
						if [ -z "${STARTEDSERVERS}" ]; then
							STARTEDSERVERS="${ITEM}"
						else
							STARTEDSERVERS="${STARTEDSERVERS} ${ITEM}"
						fi
					fi
				done
				if [ "`cat $THIS_OUT | fgrep 'init finished'`" ]; then
					System.print.status green ONLINE
					break;
				fi
				if [ $COUNT -ge 600 ]; then
					System.print.status yellow FAILED && THIS.stop && return 1
				fi
			fi
		else
			if [ -f "$THIS_RESTARTFILE" ]; then
				System.print.status green ONLINE
				break;
			fi
		fi
		if [ ${COUNT} -ge 60 -a ${CANFAIL} = true ]; then
			System.print.status yellow FAILED && THIS.stop && return 1
		fi
	done
	[ "$1" = nopublic ] || THIS.openToPublic
	System.message "Instance 'THIS' started!" && return 0
}
THIS.stop() {
#		THIS.isActive || return 1
	System.message "Stoping 'THIS' instance"
	THIS.closeFromPublic
	${THIS_GROUPNAME}.isSingleActive && ! System.isShutdown && ${THIS_GROUPNAME}.setActive false
	[ "$1" = cooldown ] && System.cooldown
	killbylockfile ${THIS_DAEMONFLAG}
	THIS.setUptime
	ipcontrol unbind lo0 ${THIS_INTIP}
	THIS.reset
	System.message "Instance 'THIS' stopped!" && return 0
}
THIS.restart() {
	THIS.isActive || return 1
	[ ! -w $THIS_RESTARTFILE ] && System.print.error "you don't have permission for 'restart' operation, or unexpected flag condition" && return 1
	System.message "Restarting 'THIS' instance"
	killbylockfile $THIS_DAEMONFLAG noremove
	/bin/rm $THIS_RESTARTFILE > /dev/null 2>&1
	THIS.reset
	System.message "Waiting for instance to start" waitstatus
	COUNT=0
	while true
	do
		COUNT=$((COUNT + 1))
		if [ $COUNT = 29 ]; then
			System.print.status yellow DONE
			break;
		fi
		sleep 1
		if [ -e $THIS_RESTARTFILE ]; then
			System.print.status green ONLINE
			break;
		fi
		echo -n .
	done
	System.message "Instance 'THIS' restarted!" && return 0
}
THIS.setUptime() {
	if [ -e ${THIS_HOME}/starttime ]; then
		STARTTIME=`THIS.getStartTime`
		if [ "${STARTTIME}" ]; then
			NOW=`/bin/date '+%s'`
			TIME=$((NOW-STARTTIME))
			UPTIME=`getuptime $TIME`
			System.message "Setting last uptime (${UPTIME})..." waitstatus
			echo ${UPTIME} > ${THIS_HOME}/lastuptime
			System.print.status green DONE && return 0
		fi
	fi
	return 1
}
THIS.diskcache.clear() {
	[ "$THIS_HOME" ] || return 1
	for ITEM in $1; do
		echo -n "Reset '$THIS_HOME/$ITEM'..."
		if [ -d "$THIS_HOME/$ITEM" ]; then
			mv $THIS_HOME/$ITEM $THIS_HOME/$ITEM-tmp
			#TODO: remove dir in daemon mode? Check PID!
			rm -rdf $THIS_HOME/$ITEM-tmp &
			System.print.status green DONE
		else
			System.print.status red "NOT FOUND"
		fi
	done
}
THIS.reset() {
	RESET=`Console.getSettingValue reset`
	[ "$RESET" -a "$THIS_HOME" ] && echo all settings data cache temp | fgrep -qw $RESET || return 1
	if [ "$RESET" = all ]; then
		THIS.diskcache.clear "settings data cache temp"
	else
		THIS.diskcache.clear $RESET
	fi
	rm -rdf $THIS_HOME/boot.properties
	return 0
}
