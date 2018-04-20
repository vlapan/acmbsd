#!/bin/sh

#ARG1: $1 - string to check
#ARG2: $2 - port address
#ARG3: $3 - function name
pkg.install() {
	out.message "Check for $1..." waitstatus
	if pkg info "$1*" > /dev/null 2>&1; then
		out.status green FOUND
	else
		out.status yellow 'NOT FOUND'
		out.message "Installing $1..."
		pkg install -y $2
		test "$3" && eval "`$3`"
		out.message "Check for $1..." waitstatus
		if pkg info "$1*" > /dev/null 2>&1; then
			out.status green FOUND
		else
			out.status red ERROR
			exit 1
		fi
	fi
}

#out.message 'pkg: module loaded'
