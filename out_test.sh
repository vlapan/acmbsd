#!/usr/local/bin/bash -e

ACMBSDPATH=/tmp/acmbsd_test

mkdir -p $ACMBSDPATH

load.isLoaded() {
	eval echo \$MODULE_$1
}

load.module() {
	for MODULE in $@; do
		[ "`load.isLoaded $MODULE`" ] && continue || eval "MODULE_$MODULE=1"
		trap "echo 'Error while loading module - $MODULE'" 0
		test -f $MODULE.sh && . $MODULE.sh || . $ACMBSDPATH/scripts/$MODULE.sh
		trap - 0
	done
	return 0
}

load.module out

out.error out.error.string1
out.info out.info.string1
out.syntax out.info.string1
out.example out.example.string1
out.str out.str.string1
out.valuechange value1 value2 value3 && echo
out.valuechange value1 value2 value3 value4 && echo
out.status red STATUS_RED
out.status green STATUS_GREEN
out.status yellow STATUS_YELLOW
out.message message1
out.message message2 waitstatus
out.status green OK

rm -rdf $ACMBSDPATH
