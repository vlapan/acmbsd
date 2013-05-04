#!/bin/sh -e
#TODO: get rid of this
getSettingValue() {
	local RETVAL=1
	for ITEM in `echo "$SETTINGS" | fgrep -w $1`; do
		echo $ITEM | cut -d= -f2 && RETVAL=0
		[ $2 ] && break
	done
	return $RETVAL
}
Console.isSettingExist() {
	echo "$SETTINGS" | fgrep -qw $1 && return 0 || return 1
}
Console.getSettingValue() {
	for ITEM in `echo "$SETTINGS" | fgrep -w $1`; do
		echo $ITEM | cut -d= -f2 && return 0
	done
	return 1
}
Console.isOptionExist() {
	echo $OPTIONS | fgrep -qw $1 && return 0 || return 1
}
data.setTo() {
	local COUNT=1
	for ITEM in $VARS; do
		KEY=`eval echo '${'$COUNT'}'`
		[ -z "$KEY" ] && break
		if [ "$KEY" = '+' ]; then
			KEY=`eval echo '${'$((COUNT - 1))'}'`
			EVAL="$KEY='"`eval echo '${'$KEY'}'`" $ITEM'"
		else
			COUNT=$((COUNT + 1))
			EVAL="$KEY=$ITEM"
		fi
		eval $EVAL
	done
}
Function.getSettingValue() {
	for ITEM in `echo "$2" | fgrep -w $1`; do
		if echo $ITEM | fgrep -q =; then
			[ "`echo $ITEM | cut -d= -f1`" = "-$1" ] && echo $ITEM | cut -d= -f2 && return 0
		fi
	done
	return 1
}
Function.isOptionExist() {
	echo $2 | fgrep -qw $1 && return 0 || return 1
}
Function.isExist() {
	type $1 > /dev/null 2>&1 && return 0 || return 1
}
parseOpts() {
	for ITEM in $@; do
		[ $ITEM = $COMMAND ] && continue
		if echo $ITEM | fgrep -q -; then
			if echo $ITEM | fgrep -q =; then
				[ "$SETTINGS" ] && SETTINGS="$SETTINGS"`printf "\n$ITEM"` || SETTINGS=$ITEM
			else
				[ "$OPTIONS" ] && OPTIONS="$OPTIONS $ITEM" || OPTIONS=$ITEM
			fi
			continue
		fi
		[ "$MODS" ] && MODS="$MODS $ITEM" || MODS=$ITEM
	done
}

#out.message 'data: module loaded'
