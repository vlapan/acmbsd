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
load.module cfg

KEY=test_key
VALUE=test_value

out.message 'undefined key...' waitstatus
[ "" = "`cfg.getValue $KEY`" ] && out.status green OK || out.status red FAILED

out.message 'defined key...' waitstatus
cfg.setValue $KEY "$VALUE"
[ "$VALUE" = "`cfg.getValue $KEY`" ] && out.status green OK || out.status red FAILED

out.message 'removed key...' waitstatus
cfg.remove $KEY
[ "" = "`cfg.getValue $KEY`" ] && out.status green OK || out.status red FAILED

out.message 'multikey...' waitstatus
cfg.setValue $KEY-t1 v1 && cfg.setValue $KEY-t2 v2
[ "`printf "v2\nv1"`" = "`cfg.getValue $KEY`" ] && out.status green OK || out.status red FAILED

echo
perfwrite() {
	for ITEM in $SEQ; do
		cfg.setValue "key_$ITEM" "value_$ITEM"
	done
	return 0
}

perfread() {
	for ITEM in $SEQ; do
		cfg.getValue "key_$ITEM" > /dev/null
	done
	return 0
}

SEQ=''
COUNT=0
while true; do
	COUNT=$((COUNT+1))
	[ "$SEQ" ] && SEQ="$SEQ $COUNT" || SEQ="$COUNT"
	[ $COUNT -eq 100 ] && break
done

out.message 'read performance test - 100 lines (empty values)'
time perfread
echo
out.message 'write performance test - 100 lines'
time perfwrite
echo
out.message 'read performance test - 100 lines'
time perfread
echo

rm -rdf $ACMBSDPATH
