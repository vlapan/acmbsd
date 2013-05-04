#!/bin/sh

#DEP: group

zone.aliasesnice() {
	echo
	for ITEM in `echo $1 | tr ';' ' '`; do
		printf "\t\t$ITEM\n"
	done
}

zone.getData() {
	SERVERSFILE=${SERVERSDIR}/$1.xml
	ZONE_ID=`zone.get id`
	ZONE_DOMAIN=`zone.get domain`
	ZONE_ENTRANCE=`zone.get entrance`
	ZONE_ALIASES=`zone.get aliases`
	ZONE_EXCLUDE=`zone.get exclude`
	ZONE_CLASS=`zone.get class`
}

zone.list() {
	ls ${SERVERSDIR} | grep -vw disabled | sed -l 's/.xml//'
	return 0
}

zone.listDisabled() {
	ls ${SERVERSDIR} | grep -w disabled | sed -l 's/.xml//'
	return 0
}

zone.listdetail() {
	for ITEM in `zone.list`; do
		zone.getData $ITEM
		[ $ITEM != $ZONE_ID ] && out.error 'filename and id inside are different.' && return 0
		ZONE_ALIASES_NICE=`zone.aliasesnice $ZONE_ALIASES`
		printf "${txtbld}$ZONE_ID${txtrst}\n\tclass($ZONE_CLASS), domain($ZONE_DOMAIN), entrance($ZONE_ENTRANCE),\n\taliases($ZONE_ALIASES_NICE\n\t),\n\texclude($ZONE_EXCLUDE)\n"
		echo
	done
	return 0
}

zone.enable() {
	#ATTR: id
	[ -z "$1" ] && out.error "zone.enable function: no id(\$1) provided." && return 1
	SERVERSFILE=$SERVERSDIR/$1.xml.disabled
	out.info "Zone file: $SERVERSFILE"
	echo -n "Trying to enable zone..."
	if [ ! -f $SERVERSFILE ]; then
		out.status red "NOT FOUND"
		return 1
	else
		mv $SERVERSFILE ${SERVERSFILE%.disabled}
		case $? in
			0)
				out.status green ENABLED
			;;
			*)
				out.status red ERROR
				return 1
			;;
		esac
	fi
	return 0
}

zone.disable() {
	#ATTR: id
	[ -z "$1" ] && out.error "zone.enable function: no id(\$1) provided." && return 1
	SERVERSFILE=$SERVERSDIR/$1.xml
	out.info "Zone file: $SERVERSFILE"
	echo -n "Trying to disable zone..."
	if [ ! -f $SERVERSFILE ]; then
		out.status red "NOT FOUND"
		return 1
	else
		mv $SERVERSFILE $SERVERSFILE.disabled
		case $? in
			0)
				out.status green DISABLED
			;;
			*)
				out.status red ERROR
				return 1
			;;
		esac
	fi
	return 0
}

zone.isDisabled() {
	#ATTR: id
	[ -z "$1" ] && out.error "zone.isDisabled function: no id(\$1) provided." && return 1
	echo -n "Check for zone file..."
	local ZONELISTING=`ls $SERVERSDIR | grep -w $1`
	if [ -z "$ZONELISTING" ]; then
		out.status red "NOT FOUND"
		return 10
	fi
	if echo "$ZONELISTING" | grep -qw disabled; then
		out.status green DISABLED
		return 0
	else
		out.status yellow ENABLED
		return 1
	fi
}

zone.get() {
	#ATTR: attr
	/usr/local/bin/xml select -t -m server -v "@$1" $SERVERSFILE
}

zone.update() {
	#ATTR: attr value
	/usr/local/bin/xml edit --update "//server[@$1]/@$1" --value "$2" $SERVERSFILE
}

#out.message 'zone: module loaded'
