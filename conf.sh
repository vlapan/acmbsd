#!/bin/sh -e

#ARG1: $1 - conf name
#ARG2: $2 - install path
conf.install() {
	local CONFFILE=$ACMBSDPATH/scripts/conf/$1
	out.message "Installing $CONFFILE to $2..." waitstatus
	if [ -f $CONFFILE ]; then
		out.status green DONE
		cat $CONFFILE | sed -l s,\$ACMBSDPATH,$ACMBSDPATH,g > $2
	else
		out.status red 'NOT FOUND'
	fi
}