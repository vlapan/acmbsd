#!/bin/sh -e

Watchdog.start(){
	out.message "Starting watchdog process..." waitstatus
	/usr/sbin/daemon -p $WATCHDOGFLAG $0 watchdog > $ACMBSDPATH/watchdog.log 2>&1
	out.status green DONE
}

Watchdog.check() {
	if [ -e "$WATCHDOGFLAG" ]; then
		out.message 'Check for watchdog process...' waitstatus
		if ! System.daemon.isExist `cat $WATCHDOGFLAG`; then
			out.status yellow 'NOT FOUND'
			rm $WATCHDOGFLAG
			Watchdog.start
		else
			out.status green FOUND
		fi
	else
		Watchdog.start
	fi
}

Watchdog.restart() {
	if [ -e "$WATCHDOGFLAG" ]; then
		out.message 'Check for watchdog process...' waitstatus
		if ! System.daemon.isExist `cat $WATCHDOGFLAG`; then
			out.status yellow 'NOT FOUND'
			rm $WATCHDOGFLAG
			Watchdog.start
		else
			out.status green FOUND
			out.message 'Killing watchdog process...' waitstatus
			kill `cat $WATCHDOGFLAG`
			rm $WATCHDOGFLAG
			out.status green DONE
			Watchdog.start
		fi
	else
		Watchdog.start
	fi
}

#TODO: check and clean
Watchdog.command() {
	while true; do
		sleep 3
		if [ ! -f $WATCHDOGFLAG ]; then
			exit 1
		fi
		cfg.reload
		for GROUPNAME in $GROUPS; do
			Group.create $GROUPNAME
			Named.check
		done
		ACTIVATEDGROUPS=`Group.groups.getActive fresh`
		for GROUPNAME in $ACTIVATEDGROUPS; do
			Group.create $GROUPNAME
			echo
			echo "Active instances: "`$GROUPNAME.getInstanceActive`
			for INSTANCE in `$GROUPNAME.getInstanceActive`; do
				Instance.create $INSTANCE
				echo -n "Check for '$INSTANCE'..."
				if System.daemon.isExist `$INSTANCE.getPID`; then
					out.status green ONLINE
				else
					out.status yellow OFFLINE
					if [ -f `$INSTANCE.getField RESTARTFILE` ]; then
						out.info "instance crash detected!"
						FAILS=`cfg.getValue $GROUPNAME-fails`
						LASTFAIL=`cfg.getValue $GROUPNAME-lastfail`
						test "$FAILS" && FAILS=$(($FAILS+1)) || FAILS=1
						cfg.setValue $GROUPNAME-fails "$FAILS" && cfg.setValue $GROUPNAME-lastfail `date +%s`
						if [ "$LASTFAIL" ]; then
							local TIME = $(($(date +%s)-${LASTFAIL}))
							echo $TIME
						fi
						#TODO: last time in human readable format
						tail -n 2000 `$GROUPNAME.getField LOGS`/stdout-$INSTANCE > /tmp/acmbsd.$INSTANCE.stdout
						mail.sendfile "/tmp/acmbsd.$INSTANCE.stdout" "daemon '$GROUPNAME' instance crash detected" "global fail count: $FAILS, last fail $TIME seconds ago"
						rm /tmp/acmbsd.$INSTANCE.stdout
					fi
					$INSTANCE.startDaemon
				fi
			done
		done
		farm.listCheck
		SERVICETIME=`cfg.getValue autotime`
		LASTSERVICETIME=`cfg.getValue lastautotime`
		DAY=`date +%d`
		if [ "$DAY" != "$LASTSERVICETIME" -a "`date +%H:%M`" = "$SERVICETIME" ]; then
			cfg.setValue lastautotime $DAY
			$0 service > /tmp/acmbsd.service.log &
		fi
	done
}