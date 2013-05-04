#!/bin/sh

#ARG1: $1 - string to check
#ARG2: $2 - port address
#ARG3: $3 - function name
pkg.install.port() {
	out.message "Check for $1..." waitstatus
	if pkg_info -Eq $1-*; then
		out.status green FOUND
	else
		out.status yellow 'NOT FOUND'
		out.message "Installing $1..."
		if !test -d /usr/ports && test -d /usr/ports/$2; then
			out.error "ports tree or specified port couldn't be found"
			exit 1
		fi
		cd /usr/ports/$2 && make clean && make install
		test "$3" && eval "`$3`"
		make clean
		out.message "Check for $1..." waitstatus
		PKGINFO=`pkg_info`
		if pkg_info -Eq $1-*; then
			out.status green FOUND
		else
			out.status red ERROR
			exit 1
		fi
	fi
}

#ARG1: $1 - string to check
#ARG2: $2 - package to install
#ARG3: $3 - function name
pkg.install.pkg() {
	out.message "Check for $1..." waitstatus
	if pkg_info -Eq $1-*; then
		out.status green FOUND
	else
		out.status yellow 'NOT FOUND'
		out.message "Installing $1..."
		pkg_add -r $2
		out.message "Check for $1..." waitstatus
		PKGINFO=`pkg_info`
		if pkg_info -Eq $1-*; then
			out.status green FOUND
		else
			out.status red ERROR
			exit 1
		fi
	fi
}

#out.message 'pkg: module loaded'
