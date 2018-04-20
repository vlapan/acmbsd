#!/bin/sh -e

Group.create() {
	#Options:	1 - Group name
	local THIS=$1
	[ "$THIS" ] && Group.isGroup $THIS || return 1
	Function.isExist $THIS.isObject && return 0
	local EVAL="`sed s/THIS/$THIS/g $ACMBSDPATH/scripts/group.sh`"
	Object.create $THIS group "$EVAL"
	[ "$2" ] && $THIS.createInstances
	return 0
}

Group.updateAll() {
	for GROUPNAME in $GROUPS; do
		Group.create $GROUPNAME && $GROUPNAME.isExist && $GROUPNAME.update
	done
}

Group.startAll() {
	for GROUPNAME in $1; do
		Group.create $GROUPNAME && $GROUPNAME.isExist && $GROUPNAME.start
	done
	Watchdog.check
}

Group.stopAll() {
	for GROUPNAME in $1; do
		Group.create $GROUPNAME && $GROUPNAME.isExist && $GROUPNAME.stop
	done
	Watchdog.check
}

Group.getData() {
	if [ "$1" ]; then
		GROUPNAME=$1
	fi
	if Group.isGroup $GROUPNAME && Group.isExist $GROUPNAME ; then
		GROUPID="$(Group.default.id ${GROUPNAME})"
		GROUPPATH=${DEFAULTGROUPPATH}/${GROUPNAME}
		PUBLIC=${GROUPPATH}/public
		PUBLICBACKUP=${GROUPPATH}/public-backup
		PROTECTED=${GROUPPATH}/protected
		LOGS=${GROUPPATH}/logs
		SERVERSDIR=${PROTECTED}/conf/servers
		SERVERSCONF=${PROTECTED}/conf/servers.xml
		WEB=${PROTECTED}/web
		if [ -f ${GROUPPATH}/public/version/version ]; then
			ACMVERSION=$(cat ${GROUPPATH}/public/version/version)
		else
			ACMVERSION=0
		fi
		MEMORY=$(cfg.getValue "${GROUPNAME}-memory")
		EXTIP=$(cfg.getValue "${GROUPNAME}-extip")
		TYPE=$(cfg.getValue "${GROUPNAME}-type")
		BRANCH=$(cfg.getValue "${GROUPNAME}-branch")
		INSTANCELIST=$(ls $GROUPPATH | fgrep -w private | cut -d- -f1)
		Group.instances.getActive
		INSTANCESCOUNT=$(echo ${INSTANCELIST} | wc -w | tr -d ' ')
		return 0
	fi
	return 1
}

Group.groups.getActive() {
	[ -z "$ACTIVATEDGROUPS" -o "$1" ] && ACTIVATEDGROUPS=`echo "$DATA" | grep -w activated | cut -d- -f1`
	echo $ACTIVATEDGROUPS
}

Group.groups.getStatus() {
	printf "Groups list: available (${txtbld}${GROUPS}${txtrst}), active (${txtbld}${ACTIVATEDGROUPS}${txtrst})\n"
}

Group.instances.getActive() {
	ACTIVEINSTANCES=""
	local ITEM
	for ITEM in ${INSTANCELIST}; do
		local ITEMPRIVATE=${GROUPPATH}/${ITEM}-private
		local ITEMDAEMONFLAG=${ITEMPRIVATE}/daemon.flag
		if [ -f ${ITEMDAEMONFLAG} ]; then
		 	if [ -z "${ACTIVEINSTANCES}" ]; then
				ACTIVEINSTANCES="${ITEM}"
		 	else
		 		ACTIVEINSTANCES="${ACTIVEINSTANCES} ${ITEM}"
		 	fi
		fi
	done
}

Group.default.id() {
	case $1 in
		live)
			echo 20
		;;
		test)
			echo 40
		;;
		devel)
			echo 60
		;;
		temp)
			echo 80
		;;
		*)
			echo 100
	esac
}

Group.default.loglevel() {
	case $1 in
		live)
			echo NORMAL
		;;
		test)
			echo NORMAL
		;;
		devel)
			echo DEBUG
		;;
		*)
			echo DEBUG
	esac
}

Group.default.ea() {
	echo $1 | fgrep -qw live && echo disable || echo enable
}

Group.default.branch() {
	echo $1 | fgrep -qw live && echo release || echo current
}

Group.reset() {
	rm -rdf $PROTECTED/boot.properties
	for INSTANCE in $INSTANCELIST; do
		$INSTANCE.reset
	done
}

Group.isDigit() {
	echo 1 2 3 4 5 6 7 8 9 | fgrep -qw $1 && return 0 || return 1
}

Group.isGroup() {
	[ "$1" ] && echo $GROUPSNAME | fgrep -qw $1 && return 0 || return 1
}

#TODO: stale
Group.isBranch() {
	echo release current | fgrep -qw $1 && return 0 || return 1
}

Group.isLogLevel() {
	echo NORMAL DEBUG DEVEL MINIMAL | fgrep -qw $1 && return 0 || return 1
}

Group.isOptimizeMode() {
	echo default speed size | fgrep -qw $1 && return 0 || return 1
}

Group.isType() {
	echo minimal standard extended parallel | fgrep -qw $1 && return 0 || return 1
}

Group.isEA() {
	echo enable disable | fgrep -qw $1 && return 0 || return 1
}

Group.isMemory() {
	echo $1 | fgrep -qoE "\b([0-9]*?)m\b" && return 0 || return 1
}

Group.isExist() {
	[ "$2" = passAll -a "$1" = all ] && return 0
	#TODO: '-z "$1"'?
	[ -z "$1" -o -z "`echo $GROUPS | fgrep -w $1`" ] || return 0
	out.error "given group '$1' is not exist!"
	return 1
}

Group.isActive() {
	[ "$2" = passAll -a "$1" = all ] && return 0
	echo `Group.groups.getActive` | fgrep -qw $1 && return 0
	out.error "given group '$1' is not active!"
	return 1
}

Group.isPassive() {
	echo `Group.groups.getActive` | fgrep -qw $1 || return 0
	out.error "given group '$1' is active!"
	return 1
}
