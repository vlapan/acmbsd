#!/bin/sh -e

base.file.checkLine() {
	[ ! -f "$1" ] && touch $1
	out.message "Check for '$2' in '$1'..." waitstatus
	if cat $1 | egrep -q "$2"; then
		out.status green FOUND && return 0
	else
		if [ "$3" ]; then
			echo "$3" >> $1
		else
			echo "$2" >> $1
		fi
		out.status green ADDED && return 1
	fi
}

#out.message 'base: module loaded'
