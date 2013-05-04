#!/bin/sh -e

load.module out

DATAFILE=$ACMBSDPATH/data.conf

cfg.reload() {
	if [ -f "$DATAFILE" ]; then
		local CKSUM=`md5 -q $DATAFILE`
		if [ "$DATAFILECKSUM" != "$CKSUM" ]; then
			DATAFILECKSUM=$CKSUM
			DATA=`cat $DATAFILE`
		fi
		return 0
	else
		return 1
	fi
}
cfg.remove() {
	[ "$1" ] && DATA=`echo "$DATA" | sed -l "/$1/d"` && echo "$DATA" > $DATAFILE && return 0 || return 1
}
cfg.setValue() {
	[ "$1" -a "$2" ] || return 1
	DATA=`echo "$DATA" | sed -l "/$1=/d"`
	if [ "$DATA" ]; then
		printf "$1=$2\n$DATA\n" > $DATAFILE
	else
		echo "$1=$2" > $DATAFILE
	fi
	DATA=`cat $DATAFILE`
	return 0
}
#TODO: config test case
cfg.getValue() {
	[ "$1" ] && TMPDATA=`echo -n "$DATA" | fgrep -w $1` || return 1
	#TODO: 'cut' always return true
	echo -n "$TMPDATA" | cut -d= -f2 && return 0 || return 1
}

[ ! -f "$DATAFILE" ] && touch $DATAFILE
cfg.reload

#out.message 'cfg: module loaded'
