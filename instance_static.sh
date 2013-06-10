#!/bin/sh -e

Instance.create() {
	#Options:	1 - Instance name
	local THIS=$1
	#TODO: check isInstance
	[ "$THIS" ] || return 1
	local GROUPNAME=`echo $THIS | tr -d '[0-9]'`
	Group.isGroup $GROUPNAME || return 1
	Function.isExist $GROUPNAME.isObject || Group.create $GROUPNAME
	Function.isExist $THIS.isObject && return 0
	local EVAL="`sed s/THIS/$THIS/g $ACMBSDPATH/scripts/instance.sh`"
	Object.create $THIS instance "$EVAL"
	return 0
}

Instance.getData() {
	if [ "${1}" ]; then
		INSTANCE=${1}
	fi
	PRIVATE=${GROUPPATH}/${INSTANCE}-private
	ACMOUT=${LOGS}/stdout-${INSTANCE}
	ACMOUTLAST=${LOGS}/stdout-${INSTANCE}.prev
	RESTARTFILE=${PRIVATE}/control/restart
	DAEMONFLAG=${PRIVATE}/daemon.flag
	if [ -f ${DAEMONFLAG} ]; then
		DAEMONPID=$(cat ${DAEMONFLAG})
	fi
	INSTANCENUMBER=$(echo ${INSTANCE} | tr -d "[a-z]")
	INTIP="172.16.0.$((${GROUPID}+${INSTANCENUMBER}-1))"
}

Instance.isExist() {
	[ "$2" = "passAll" -a "$1" = "all" ] && return 0
	[ -z "$1" -o -z "`echo $INSTANCELIST | fgrep -w $1`" ] || return 0
	out.error "given instance '$1' do not exist!"
	return 1
}