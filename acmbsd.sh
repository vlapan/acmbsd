#!/bin/sh
#TODO: set -e
#TODO: use 'column', man column, (printf "PERM LINKS OWNER GROUP SIZE MONTH DAY "; printf "HH:MM/YEAR NAME\n"; ls -l | sed 1d) | column -t

#TODO: generate scripts for bash-completion, example in ~/.bashrc
#TODO: security, check for vulnerable packages 'portaudit -Fda'
#TODO: speedup boot, in /boot/defaults/loader.conf insert 'autoboot_delay="-1"' and 'beastie_disable="YES"'

#FAQ: if ssh take long time to connect, add to /etc/ssh/sshd_config line 'UseDNS no'
#DONE: if publicip empty then get extip instead

System.setShutdown() {
	RCACM=$1
}
System.isShutdown() {
	[ "$RCACM" = true ] && return 0 || return 1
}
System.cmd.begin() {
	if [ -z "$NESTINGCOUNT" ]; then
		NESTINGCOUNT=0
	fi
	if [ -z "$(echo $OPTIONS | fgrep -w verbose)" -a "$SIMPLEOUTPUT" ]; then
		NESTINGCOUNT=$((NESTINGCOUNT + 1))
		if [ $NESTINGCOUNT = 1 ]; then
			echo -n "$1{ "
		else
			echo -n " $1{ "
		fi
	fi
}
System.cmd.end() {
	if [ -z "$(echo $OPTIONS | fgrep -w verbose)" -a "$SIMPLEOUTPUT" ]; then
		echo -n ' }'
	fi
}
System.fs.dir.create() {
	out.message $1... waitstatus
	if [ -d "$1" ]; then
		out.status green FOUND
	else
		if mkdir -p $1; then
			out.status green CREATED
		else
			out.status red ERROR && return 1
		fi
	fi
	return 0
}
System.fs.file.get() {
	if [ -f $1 ]; then
		cat $1
	else
		echo $2
	fi
}
System.daemon.isExist() {
	kill -0 $1 > /dev/null 2>&1 && return 0 || return 1
}
Java.classpath() {
	local FIRST=true
	for ITEM in $(ls $1 | fgrep -w jar); do
		test $FIRST = true && FIRST=false || echo -n :
		echo -n $1/$ITEM
	done
	echo
}
Java.classpath.stats(){
	cat <<-EOF
		`echo $CLASSPATH | tr ':' '\n' | wc -l | tr -d ' '` files in classpath:
		\t	axiom: `echo $AXIOMDIR | tr ':' '\n' | wc -l | tr -d ' '`
		\t	features: `echo $FEATURESDIR | tr ':' '\n' | wc -l | tr -d ' '`
		\t	boot: `echo $BOOTDIR | tr ':' '\n' | wc -l | tr -d ' '`
		\t	modules: `echo $MODULESDIR | tr ':' '\n' | wc -l | tr -d ' '`
	EOF
}

#TODO: H2
Database.h2.backupAll() {
	out.nextrelease
	for ITEM in `ls $DBDIR | cut -d. -f1-2 | uniq`; do
		Database.h2.backup $ITEM
	done
}
Database.h2.backup() {
	out.nextrelease
	java -cp $PUBLIC/axiom/h2-*.jar org.h2.tools.Script -url jdbc:h2:$DBDIR/$ITEM -user sa -script $BACKUPDIR/$ITEM/$ITEM.zip -options compression zip;
}
Database.h2.restore() {
	out.nextrelease
	java -cp $PUBLIC/axiom/h2-*.jar org.h2.tools.RunScript -url jdbc:h2:$DBDIR/$ITEM -user sa -script $BACKUPDIR/$ITEM/$ITEM.zip -options compression zip;
}
Database.check() {
	echo '\q' | /usr/local/bin/psql $1 pgsql > /dev/null 2>&1 && return 0 || return 1
}
Database.create() {
	if ! Database.check $1 ; then
		cp ${DBTEMPLATEFILE} /usr/local/pgsql
		su - pgsql -c "createdb $1"
		su - pgsql -c "pg_restore -d $1 /usr/local/pgsql/acmbsd.backup"
		rm /usr/local/pgsql/acmbsd.backup
		return 0
	else
		return 1
	fi
}
Database.getSize() {
	/usr/local/bin/psql -tA -c "select pg_size_pretty(pg_database_size('$1'))" postgres pgsql | tr -d ' ' | tr -d 'B' | tr 'k' 'K'
}
Database.counter.set() {
	TABLE=`echo $2 | cut -d_ -f1`
	FIELD=`echo $2 | cut -d_ -f2`
	/usr/local/bin/psql -tA -c "select setval('${2}_seq', (select max($FIELD) from $TABLE))" $1 pgsql
}
Database.counters.correct() {
	COUNTERS="d1dictionary_code d1folders_fldluid d1queue_queluid d1sources_srcluid m1inbox_msgluid m1queue_msgluid m1sent_msgluid s3tree_lnkluid s3dictionary_code"
	echo -n Refreshing DB counters...
	for COUNTER in $COUNTERS; do
		COUNTERVAL=`Database.counter.set $1 $COUNTER`;
		if [ "$COUNTERVAL" ]; then
			printf " $COUNTERVAL"
		else
			printf ' 0'
		fi
	done
	out.status green OK
}
Database.template.update() {
	out.message "Fetching db-template..." waitstatus
	if Network.cvs.fetch /var/ae3 db-template ae3/distribution/acm.cm5/bsd/db-template > /dev/null 2>&1 ; then
		out.status green DONE
	else
		out.status red FAILED
	fi
}
Network.getInterfaceByIP() {
	[ $1 ] && IP=$1 || return 1
	for ITEM in `/sbin/ifconfig -lu`; do
		/sbin/ifconfig $ITEM | fgrep -q $IP && echo $ITEM && return 0
	done
	return 1
}
Network.cvs.fetch() {
	echo cvs -d :pserver:guest:guest@cvs.myx.ru:$1 -fq -z 6 checkout -P -d $2 $3
	cvs -d :pserver:guest:guest@cvs.myx.ru:$1 -fq -z 6 checkout -P -d $2 $3 || return 1
}
IPOCT='(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)'
LASTIPOCT='(25[0-4]|2[0-4][0-9]|[01]?[0-9][0-9]?)'
Network.isIP() {
	echo $1 | fgrep -v 127.0.0.1 | fgrep -qoE "\b$IPOCT\.$IPOCT\.$IPOCT\.$LASTIPOCT\b" && return 0 || return 1
}
Network.getIPList() {
	/sbin/ifconfig | fgrep -w inet | cut -d' ' -f2 | grep -oE "\b$IPOCT\.$IPOCT\.$IPOCT\.$LASTIPOCT\b" | grep -v 127.0.0.1 | grep -v 172.16.0
}
Network.getFreeIPList() {
	local BUSYIP="$(cfg.getValue extip)"
	local FIRST=true
	for ITEM in $(Network.getIPList); do
		if ! echo "$BUSYIP" | fgrep -qw $ITEM; then
			[ "$FIRST" = true ] && FIRST=false || echo -n ' '
			echo -n $ITEM
		fi
	done
	echo
}
Network.isFreeIP() {
	Network.getFreeIPList | fgrep -q $1 && return 0 || return 1
}
ipcontrol() {
	if ! Network.isIP $3; then
		echo "error is not IP:$3"
		return 1
	fi
	NETMASK=255.255.255.0
	[ "$4" ] && NETMASK=$4
	out.message "Check for '$3' IP-address on '$2' interface..." waitstatus
	if /sbin/ifconfig | fgrep -qw $3; then
		if [ "$1" = bind ]; then
			out.status yellow FOUND
		else
			/sbin/ifconfig $2 inet $3 -alias > /dev/null 2>&1
			out.status green UNALIASED
		fi
	else
		if [ "$1" = bind ]; then
			/sbin/ifconfig $2 inet $3 netmask $NETMASK alias > /dev/null 2>&1
			out.status green ALIASED
		else
			out.status yellow 'NOT FOUND'
		fi
	fi
	return 0
}
killbylockfile() {
	#	$1 - lockfile path
	#	$2 - remove lockfile, 'yes' or 'no', default 'yes'
	#	$3 - function name
	#TODO: print.warning
	[ ! -e "$1" ] && out.error "Unable to find lock file ($1)" && return 1
	local PID=`cat $1`
	if [ -z "$2" -o "$2" = yes ]; then
		out.message "Removing lock file ($1)..." waitstatus
		rm $1 > /dev/null 2>&1 && out.status green DONE || out.status red FAILED
	fi
	out.message "Trying to kill gracefully ($PID)..." waitstatus
	kill $PID > /dev/null 2>&1
	out.status green DONE
	out.message 'Waiting for process to die' waitstatus
	local COUNT=0
	while true; do
		if [ $COUNT = 60 ]; then
			out.status yellow 'STILL ALIVE'
			test "$3" && eval "`$3`"
			out.message "Trying to kill(9) ($PID)..." waitstatus
			kill -9 $PID > /dev/null 2>&1
			out.status red KILLED
			break;
		fi
		sleep 1
		if ! System.daemon.isExist $PID; then
			out.status green DIED
			break;
		fi
		COUNT=$((COUNT + 1))
		echo -n .
	done
}
scriptlink() {
	[ -e "$2" ] || return 1
	out.message "Link '$2' to '$1'..." waitstatus
	#TODO: check exit code
	ln -f $2 $1
	out.status green DONE
	out.message "Change rights for '$1'..." waitstatus
	chown acmbsd:acmbsd $1 && chmod 0774 $1
	out.status green DONE
	return 0
}

System.changeRights() {
	OPTS="$@"
	local RSTR=`Function.getSettingValue recursive "$OPTS"`
	local REQURSIVE=`([ "$RSTR" ] && [ "$RSTR" = false -o "$RSTR" = no -o "$RSTR" = 0 ]) || echo '-R'`
	[ ! -d "$1" -o -z "$2" ] && return 1
	if ! pw usershow $3 > /dev/null 2>&1; then
		out.error "no user '$3'!"
		return 1
	fi
	if ! pw groupshow $2 > /dev/null 2>&1; then
		out.error "no group '$2'!"
		return 1
	fi
	[ "$4" ] && RIGHTS=$4 || RIGHTS='ug=rwX,o='
	out.message "Modifying FS rights (dir:$1,user:$3,group:$2,rights:$RIGHTS,o:$REQURSIVE)..." waitstatus
	#TODO: change to find
	chown $REQURSIVE $3:$2 $1 && chmod $REQURSIVE $RIGHTS $1
	out.status green DONE && return 0
}
cvsacmcm() {
	ONLYCHECK=$3
	RETVAL=0
	System.fs.dir.create $ACMCM5PATH > /dev/null 2>&1
	cd $ACMCM5PATH
	out.message "Fetching ACM.CM5 (sys-$1) version..." waitstatus
	if Network.cvs.fetch /var/share tmp export/sys-$1/version/version ; then
		out.status green DONE
	else
		out.status red FAILED
		RETVAL=1
	fi
	if [ -f tmp/version ]; then
		CVSVERSION=`cat tmp/version 2> /dev/null`
		if [ "$CVSVERSION" ]; then
			#TODO: use function for getting option
			if [ "`echo $OPTIONS | fgrep -w force`" -o -z "$ONLYCHECK" -a "$2" != $CVSVERSION ]; then
				out.message "ACM.CM5 (sys-$1) version: Latest - '$CVSVERSION', Local - '$2'"
				out.message "Fetching latest ACM.CM5 (sys-$1)..."
				if Network.cvs.fetch /var/share $1 export/sys-$1 ; then
					out.message 'Finish...' waitstatus
					out.status green OK
				else
					out.message 'Finish...' waitstatus
					out.status red ERROR
					RETVAL=1
				fi
			else
				out.message "ACM.CM5 (sys-$1) version already updated to $CVSVERSION"
			fi
		fi
	fi
	rm -rdf tmp
	return $RETVAL
}
Object.getField() {
	eval echo \$${1}_${2}
}
#TODO: Object factory
Object.create() {
	#Options:
	#			1 - Object name
	#			2 - Object type
	#			3 - Extend
	local THIS=$1
	test "$THIS" || return 1
	Function.isExist $THIS.isObject && return 1
	local TMPFILE=$(mktemp -q /tmp/$SCRIPTNAME.$THIS.obj.XXXXXX)
	if [ $? -ne 0 ]; then
		echo "$0: Can't create temp file, exiting..."
		return 1
	fi
	cat >> $TMPFILE <<-EOF
		${THIS}.isObject() {
			return 0;
		}
		${THIS}.getType() {
			echo ${2}
		}
		${THIS}.getName() {
			echo ${1}
		}
		${THIS}.setField() {
			echo \${1} | tr 'a-z' 'A-Z'
		}
		${THIS}.getField() {
			Object.getField ${THIS} \${1}
		}
		${THIS}.isExist() {
			echo "true:\${1}"
		}
		${THIS}.init() {
			echo 'Default object init...'
		}
	EOF
	local EVAL="$(cat ${TMPFILE})"
	rm ${TMPFILE}
	eval "${EVAL}" && eval "${3}" && ${THIS}.init || return 1
	return 0
}
System.cooldown() {
	out.message 'Cooldown...' waitstatus
	local COUNT=0
	while true; do
		COUNT=$((COUNT + 1))
		if [ ${COUNT} = 10 ]; then
			out.status green DONE
			break;
		fi
		sleep 1
		echo -n .
	done
}
Script.update.check() {
	cd $ACMBSDPATH
	rm -rdf tmp
	mkdir -p tmp
	out.message "Fetching ACMBSD version from CVS..." waitstatus
	if Network.cvs.fetch /var/ae3 tmp acm-install-freebsd/scripts/version > /dev/null 2>&1 ; then
		out.status green DONE
		CVSVERSION=`cat tmp/version`
		rm -rdf tmp
	else
		out.status red FAILED
	fi
	if [ "$CVSVERSION" ]; then
		out.message "ACMBSD version: Latest - '$CVSVERSION', Local - '$VERSION'"
		if [ ! -e "$ACMBSDPATH/scripts/acmbsd.sh" -o $CVSVERSION -gt $VERSION -o "$(echo $OPTIONS | fgrep -w now)" ]; then
			return 0
		fi
	fi
	return 1
}
Script.update.fetch () {
	out.message "Fetching ACMBSD..." waitstatus
	if Network.cvs.fetch /var/ae3 scripts acm-install-freebsd/scripts > /dev/null 2>&1 ; then
		out.status green DONE
		chmod 775 $ACMBSDPATH/scripts/acmbsd.sh
		out.message "Running 'acmbsd install -noupdate'..." waitstatus
		if $ACMBSDPATH/scripts/acmbsd.sh install -noupdate > /dev/null 2>&1 ; then
			out.status green DONE
			mail.send "<html><p>acmbsd script updated from '<b>$VERSION</b>' to '<b>$CVSVERSION</b>' version</p></html>" "acmbsd script updated" html
		else
			out.status red FAILED
		fi
	else
		out.status red FAILED
	fi
}
Script.update () {
	if Script.update.check || Console.isOptionExist clean; then
		Console.isOptionExist clean && rm ${ACMBSDPATH}/scripts/acmbsd.sh
		Script.update.fetch
	fi
	Database.template.update
}
sys.grp.chk() {
	[ "$1" ] || return 1
	for ITEM in $1; do
		echo -n "Check group '$ITEM'..."
		if pw groupshow $ITEM > /dev/null 2>&1; then
			out.status green OK
		else
			if pw groupadd -n $ITEM > /dev/null 2>&1; then
				out.status green ADDED
			else
				out.status red ERROR && return 1
			fi
		fi
	done
	return 0
}
sys.usr.chk() {
	[ "$1" ] || return 1
	for ITEM in `echo $1 | tr ',' ' '`; do
		echo -n "Check user '$ITEM'..."
		if pw usershow $ITEM > /dev/null 2>&1; then
			out.status green OK
		else
			if pw useradd -n $ITEM -h - > /dev/null 2>&1; then
				out.status green ADDED
			else
				out.status red ERROR && return 1
			fi
		fi
	done
	return 0
}
sys.usr.setHome() {
	[ "$1" -a "$2" ] || return 1
	pw usermod "$1" -d "$2" && return 0 || return 1
}
getfiledate() {
	if [ ! -f "${1}" ]; then
		return 1
	fi
	ls -lrtT ${1} | tr -s " " | cut -d" " -f6-8
}
gettimevalue() {
	if [ -z "$TIME" -o $TIME = 0 ]; then
		echo -n 0$2
		return 0
	fi
	if [ $TIME -ge $1 ]; then
		echo -n "$(($TIME/$1))$2"
		TIME=$(($TIME%$1))
	fi
}
getuptime() {
	TIME=$1
	gettimevalue 86400 d:
	gettimevalue 3600 h:
	gettimevalue 60 m:
	gettimevalue 1 s
}
domainchecker() {
	echo -n "Try to resolve hostname '$1'..."
	IPADDR=`host $1 | head -n 1 | cut -d' ' -f4`
	if [ "$IPADDR" = "found:" ]; then
		out.status red ERROR
		return 1
	else
		if [ "$IPADDR" = alias ]; then
			IPADDR=`host $1 | awk 'NR==2{print $0}' | cut -d' ' -f4`
		fi
		if echo $EXTIP | fgrep -q $IPADDR; then
			out.status green $IPADDR
		else
			out.status red $IPADDR
			return 1
		fi
	fi
	echo -n "Try to get request from http server on '$1'..."
	RESPONSECODE=`curl -I $1 2> /dev/null | head -n 1 | cut -d' ' -f2`
	if [ "$RESPONSECODE" ]; then
		if [ $RESPONSECODE = 401 ]; then
			out.status red $RESPONSECODE
		else
			out.status green $RESPONSECODE
		fi
	else
		out.status red FAIL
	fi
	return 0
}
domainschecker() {
	for ITEM in `zone.list`; do
		zone.getData $ITEM
		[ $ITEM != $ZONE_ID ] && out.error 'filename and id inside are different.' && return 0

		printf "\n${txtbld}$ZONE_ID$txtrst zone.\n"

		if [ "$ZONE_ENTRANCE" ]; then
			echo "Found entrance '${ZONE_ENTRANCE#http://}'."
			domainchecker ${ZONE_ENTRANCE#http://}
		fi

		if [ "$ZONE_ALIASES" ]; then
			for ALIAS in `echo $ZONE_ALIASES | tr ';' ' '`; do
				if echo ${ALIAS#*.} | fgrep . > /dev/null 2>&1 ; then
					if ! echo ${ALIAS#*.} | fgrep .test > /dev/null 2>&1 ; then
						echo "Found alias '${ALIAS#*.}'."
						domainchecker ${ALIAS#*.}
					fi
				fi
			done
		fi
	done

	return 0
}
dbuserscheck() {
	[ -f "$SERVERSCONF" ] || return 1
	SERVERSDATA=`/usr/local/bin/xml sel -t -m 'servers' -m 'server' -v '@user' -o '|' -v '@password' -n $SERVERSCONF`
	[ "$1" ] && SERVERSDATA=`echo "$SERVERSDATA" | tr ' ' '\012' | fgrep -w $1`
	out.message "$SERVERSDATA"
	for ITEM in $SERVERSDATA; do
		ID=`echo $ITEM | cut -d'|' -f1`
		PASSWORD=`echo $ITEM | cut -d'|' -f2`
		[ -z "$(/usr/local/bin/psql -tAc "\\du \"$ID\"" postgres pgsql)" ] && echo "CREATE USER \"$ID\";" | /usr/local/bin/psql postgres pgsql -q
		{
			echo 'BEGIN;'
			if [ -z "$(/usr/local/bin/psql -tAc "\\du access" "$ID" pgsql)" ]; then echo "CREATE GROUP access;"; fi
			cat <<-EOF
				ALTER USER "$ID" ENCRYPTED PASSWORD '${PASSWORD}';
				GRANT access TO "$ID";
				GRANT ALL ON DATABASE "$ID" TO access;
				GRANT ALL ON SCHEMA public TO access;
			EOF
			/usr/local/bin/psql "$ID" pgsql -F\  -Atc '\d' | while read schema table dummy; do echo "GRANT ALL ON TABLE \"$schema\".\"$table\" TO access;"; done
			echo 'COMMIT;'
		} | /usr/local/bin/psql "$ID" pgsql -q
		out.info "'$ID' db user created!"
	done
}
domainrebuilder() {
	CONST="id url user password"
	Group.getData ${GROUPNAME}
	DOMAINSDATA=$(cat ${SERVERSCONF} | fgrep -w server)
	if echo "${DOMAINSDATA}" | fgrep -v " />" | fgrep -v " -->" > /dev/null 2>&1 ; then
		out.error "broken servers.xml in '${GROUPNAME}' group"
		return
	fi
	DOMAINDATA=$(echo "${DOMAINSDATA}" | fgrep -w "${ID}'")
	echo -n "Check for '${ID}' in servers.xml of '${GROUPNAME}' group..."
	if [ -z "${DOMAINDATA}" ];then
		out.status yellow "NOT FOUND"
	else
		out.status green FOUND
		DOMAINSDATA=$(echo "${DOMAINSDATA}" | fgrep -v -w "${ID}'")
		echo -n "'${ID}' status in servers.xml..."
		if [ "$(echo ${DOMAINDATA} | grep '\!--')" ]; then
			out.status yellow "DISABLED"
			case "${1}" in
				true)
					echo -n "Enabling '${ID}' in servers.xml..."
					START="<servers>\n\t<server"
					STOP=" />\n${DOMAINSDATA}\n</servers>\n"
					ENABLEPROCESSED="${ENABLEPROCESSED} ${GROUPNAME}"
					out.status green ENABLED
				;;
				*)
					START="<servers>\n\t<!-- server"
					STOP=" / -->\n${DOMAINSDATA}\n</servers>\n"
				;;
			esac
		else
			out.status green ENABLED
			case "${1}" in
				false)
					echo -n "Disabling '${ID}' in servers.xml..."
					START="<servers>\n\t<!-- server"
					STOP=" / -->\n${DOMAINSDATA}\n</servers>\n"
					DISABLEPROCESSED="${DISABLEPROCESSED} ${GROUPNAME}"
					out.status green DISABLED
				;;
				*)
					START="<servers>\n\t<server"
					STOP=" />\n${DOMAINSDATA}\n</servers>\n"
				;;
			esac
		fi
		printf "${START}" > ${SERVERSCONF}
		PASSWORD=''
		for ITEM in ${DOMAINDATA}; do
			if [ "$(echo ${ITEM} | fgrep =)" ]; then
				KEY=$(echo ${ITEM} | cut -d "=" -f 1)
				if [ "${COMMAND}" = "domain" -a "$(echo ${CONST} | fgrep -wv ${KEY})" -a "$(echo ${SETTINGS} | fgrep -w ${KEY})" ]; then
					PASTVALUE=$(echo ${ITEM} | cut -d= -f2 | tr -d "'" | tr -d '"')
					VALUE=$(getSettingValue ${KEY})
					out.info "Value of '${KEY}' key for '${ID}' in '${GROUPNAME}' group has changed from '${PASTVALUE}' to '${VALUE}'"
				else
					VALUE=$(echo ${ITEM} | cut -d= -f2 | tr -d "'" | tr -d '"')
				fi
				if [ "${KEY}" = user ] && [ "${VALUE}" != "${ID}" -o "`echo ${OPTIONS} | fgrep -w force`" ]; then
					VALUE=${ID}
					PASSWORD=$(echo "$ID.$HOST" | md5)
					if [ -z "$(/usr/local/bin/psql -tAc "\\du \"$ID\"" postgres pgsql)" ]; then echo "CREATE USER \"$ID\";"; fi | /usr/local/bin/psql postgres pgsql -q
					{
						echo 'BEGIN;'
						[ -z "$(/usr/local/bin/psql -tAc "\\du access" "$ID" pgsql)" ] && echo "CREATE GROUP access;"
						cat <<-EOF
							ALTER USER "$ID" ENCRYPTED PASSWORD '$PASSWORD';
							GRANT access TO "$ID";
							GRANT ALL ON DATABASE "$ID" TO access;
							GRANT ALL ON SCHEMA public TO access;
						EOF
						/usr/local/bin/psql "$ID" pgsql -F\  -Atc '\d' | while read -r schema table dummy; do echo "GRANT ALL ON TABLE \"$schema\".\"$table\" TO access;"; done
						echo 'COMMIT;'
					} | /usr/local/bin/psql "$ID" pgsql -q
					out.info "Value of '${KEY}' key for '${ID}' in '${GROUPNAME}' group has changed!"
				fi
				if [ "${PASSWORD}" -a "${KEY}" = "password" ]; then
					VALUE=${PASSWORD}
				fi
				printf " ${KEY}='${VALUE}'" >> ${SERVERSCONF}
			fi
		done
		printf "${STOP}" >> ${SERVERSCONF}
		out.info "Saving new servers.xml for '${GROUPNAME}' group!"
	fi
}
domainsync() {
	if [ "$(echo ${GROUPS} | fgrep -w ${FROMGROUP})" ]; then
		Group.getData ${FROMGROUP}
		FROMWEB=${WEB}
		if [ ! -d ${FROMWEB}/${ID} ]; then
			out.error "can not find domain with '${ID}' id on '${FROMGROUP}' group"
			exit 1
		fi
		for GROUPNAME in ${TOGROUPS}; do
			Group.getData ${GROUPNAME}
			if [ "$(echo ${GROUPS} | fgrep -w ${GROUPNAME})" -a "${GROUPNAME}" != "${FROMGROUP}" ]; then
				System.fs.dir.create ${WEB}/${ID}
				echo "Syncing domain with '${ID}' id from '${FROMWEB}/${ID}/' group to '${WEB}/${ID}'..."
				rsync -avCO --delete ${FROMWEB}/${ID}/ ${WEB}/${ID}
				System.changeRights ${WEB}/${ID} ${GROUPNAME} ${GROUPNAME}1 || return 1
			else
				out.error "'${GROUPNAME}' group not exist!"
			fi
		done
	else
		out.error "'${FROMGROUP}' group not exist!"
	fi
}
domainadd() {
	Group.getData ${GROUPNAME}
	DOMAINSDATA=$(cat ${SERVERSCONF} | fgrep -w server)
	DOMAINDATA=$(echo "${DOMAINSDATA}" | fgrep -w ${ID})
	echo -n "Check for '${ID}' in servers.xml of '${GROUPNAME}' group..."
	if [ "${DOMAINDATA}" ];then
		out.status yellow "SKIP"
		out.error "domain with '${ID}' id already exist"
	else
		out.status green "NOT FOUND"
		echo -n "Adding domain with '${ID}'..."
		System.fs.dir.create ${WEB} > /dev/null 2>&1
		if [ ! -d ${WEB}/${ID} ]; then
			System.fs.dir.create ${WEB}/${ID} > /dev/null 2>&1
		fi
		START="<servers>\n\t<server"
		STOP=" />\n${DOMAINSDATA}\n</servers>\n"
		printf "${START}" > ${SERVERSCONF}
		printf " id='${ID}'" >> ${SERVERSCONF}
		DOMAIN=$(getSettingValue domain)
		if [ -z "${DOMIAN}" ]; then
			if [ "${GROUPNAME}" = "live" ]; then
				DOMAIN="$(echo ${ID} | cut -d'.' -f2).$(echo ${ID} | cut -d'.' -f1)"
			else
				DOMAIN="${GROUPNAME}.$(echo ${ID} | cut -d'.' -f2).$(echo ${ID} | cut -d'.' -f1)"
			fi
		fi
		printf " domain='${DOMAIN}'" >> ${SERVERSCONF}
		ENTRANCE=$(getSettingValue entrance)
		if [ -z "${ENTRANCE}" ]; then
			ENTRANCE="http://${DOMAIN}"
		fi
		printf " entrance='${ENTRANCE}'" >> ${SERVERSCONF}
		CLASS=$(getSettingValue class)
		if [ -z "${CLASS}" ]; then
			CLASS="ae1:RT3"
		fi
		printf " class='${CLASS}'" >> ${SERVERSCONF}
		ALIASES=$(getSettingValue aliases)
		printf " aliases='${ALIASES}'" >> ${SERVERSCONF}
		EXCLUDE=$(getSettingValue exclude)
		printf " exclude='${EXCLUDE}'" >> ${SERVERSCONF}
		case ${GROUPNAME} in
			live)
				#pool(2,2)
				printf " url='jdbc:sticky(16,5m,30s):jdbc:profile:${ID}-sql,5000:jdbc:postgresql:${ID}'" >> ${SERVERSCONF}
			;;
			*)
				printf " url='jdbc:sticky(16,5m,30s):jdbc:profile:${ID}-sql,0:jdbc:postgresql:${ID}'" >> ${SERVERSCONF}
			;;
		esac
		PASSWORD=$(dd "if=/dev/random" count=1 bs=8 | md5)
		/usr/local/bin/psql -tA -c "CREATE USER \"${ID}\" WITH PASSWORD '${PASSWORD}'" postgres pgsql
		/usr/local/bin/psql -tA -c "ALTER USER \"${ID}\" WITH PASSWORD '${PASSWORD}'" postgres pgsql
		/usr/local/bin/psql -tA -c "GRANT ALL ON DATABASE \"${ID}\" TO \"${ID}\"" postgres pgsql
		printf " user='${ID}'" >> ${SERVERSCONF}
		printf " password='${PASSWORD}'" >> ${SERVERSCONF}
		printf "${STOP}" >> ${SERVERSCONF}
		out.status green OK
	fi
}

System.status.getLoadAvg(){
	echo $(sysctl -n vm.loadavg | tr -d "{}")
}

System.checkPermisson() {
	#TODO: use '|| System.isSystemGroup'
	System.isRoot && return 0
	echo $GROUPSNAME | fgrep -qw `echo $USER | tr -d '[0-9]'` && return 0 || return 1
}
System.fileWriteAccess() {
	[ -w $1 ] || return 1
}
System.isRoot() {
	[ `whoami` = root ] || return 1
}
System.isSystemGroup() {
	echo `groups` | fgrep -qw acmbsd && return 0 || return 1
}
System.runAsUser() {
	# echo "Enter the password of '$1' user if prompted..."
	# su - $1 -c "$2"
	[ `whoami` != $1 ] && echo "Must be run under '$1' user!" && return 1
	$2
}
System.vars.groups() {
	echo "devel test live"
}
Command.depend.activeGroup() {
	if [ -z "$(Group.groups.getActive)" ]; then
		out.error "no active groups, this command need at least one active group!"
		exit 1
	fi
	return 0
}
System.waiting() {
	while true; do echo -n . && sleep $1; done
}
Syntax.getStatus() {
	[ "$GROUPS" ] && Group.groups.getStatus || out.error 'no groups exist!'
}
Syntax.checksites() {
	Syntax.getStatus
	out.syntax 'dnsreload ( all | {groupname} )'
	[ $1 ] && exit 1
}
Syntax.start() {
	Syntax.getStatus
	out.syntax 'start ( all | {groupname} )'
}
Syntax.restart() {
	Syntax.getStatus
	out.syntax "restart ( all | {groupname} ) [-fast] [-skipwarmup] [-reset=(all | settings | cache | data )]"
}
Syntax.stop() {
	Syntax.getStatus
	out.syntax "stop ( all | {groupname} )"
}
Syntax.telnet() {
	out.syntax "telnet ( {group} | {instance} )"
	echo "Example: ${0} telnet live"
	echo
}
Syntax.mixlog(){
	CMDNAME="mixlog"
	out.syntax "${CMDNAME} ( all | {groupname} ) year month day hour [minute] [second]"
	out.example
	out.str "${CMDNAME} live 2010 01 08 21 [0-9]{2} [0-9]{2}"
	echo
}
Syntax.zoneenable(){
	CMDNAME="zoneenable"
	out.syntax "${CMDNAME} ( all | {groupname} ) -id={domain}"
	out.example
	out.str "${CMDNAME} live -id=ru.myx"
	echo
}
Syntax.watchlog() {
	CMDNAME="watchlog"
	printf "Active groups: ${txtbld}$(echo ${ACTIVATEDGROUPS})${txtrst}\n"
	echo "Logs:"
	for GROUPNAME in ${ACTIVATEDGROUPS}; do
		Group.getData ${GROUPNAME}
		INSTANCE=$(echo ${ACTIVEINSTANCES} | cut -d " " -f 1)
		Instance.getData
		if [ -d "${LOGS}" ]; then
			LOGSNAMES=$(ls ${LOGS} | sed "/log.prev/d")
			printf "\t${txtbld}${GROUPNAME}${txtrst}\t$(echo ${LOGSNAMES})\n"
		fi
	done
	echo
	out.syntax "${CMDNAME} ( all | {groupname} ) [logname]"
	out.example
	out.str "${CMDNAME} all"
	out.str "${CMDNAME} test log default stdout"
	echo
}
Syntax.domain() {
	CMDNAME="domain"
	out.syntax "${CMDNAME} (add | remove | config | push | sync)"
	out.example
	out.str "${CMDNAME} ${txtbld}add${txtrst} -id={domain} [-group={groupname}] [-domain=value] [-entrance=value] [-aliases=value] [-exclude=value] [-class=value]"
	out.str "${CMDNAME} ${txtbld}remove${txtrst} -id={domain} [-group={groupname}]"
	out.str "${CMDNAME} ${txtbld}config${txtrst} -id={domain} [-group={groupname}] [-enable=( true | false )] [-domain=value] [-entrance=value] [-aliases=value] [-exclude=value] [-class=value]"
	out.str "${CMDNAME} ${txtbld}sync${txtrst} -id={domain} -from={groupname} -to={groupname} [-to={groupname}]"
	out.str "${CMDNAME} ${txtbld}push${txtrst} -id={domain} -group=( devel | test )"
}
Syntax.cluster() {
	CMDNAME='cluster'
	out.syntax "${CMDNAME} ( activate | addto | cron | connect | vpninit | sync | forget )"
	out.example
	out.str "${CMDNAME} ${txtbld}activate${txtrst}"
	out.str "${CMDNAME} ${txtbld}addto${txtrst} -host=user@server1.cluster.net"
	out.str "${CMDNAME} ${txtbld}cron${txtrst} -enable=true"
	out.str "${CMDNAME} ${txtbld}connect${txtrst}"
	out.str "${CMDNAME} ${txtbld}vpninit${txtrst}"
	out.str "${CMDNAME} ${txtbld}sync${txtrst}"
	out.str "${CMDNAME} ${txtbld}forget${txtrst} -host=server1.cluster.net (for now it's just 'csync2')"
}
Syntax.help() {
	filtercommand(){
		echo "$COMMENTEDCOMMANDS" | fgrep -A1 -w $1 | grep -v '#' | fgrep -oE '\b[a-z]*\)?\b' | tr '\n' ' '
	}
	# [ -d $ACMBSDPATH ] || $0 install notips
	cat <<-EOF
		ACMBSD Script $VERSION
		Commands:
		    Everyday - $(filtercommand EVERYDAY)
		    Infrequent - $(filtercommand INFREQ)
		    Devel - $(filtercommand DEVEL)
		    *Not ready - $(filtercommand NOTREADY)
		    *System - $(filtercommand SYSTEM)
	EOF

	out.syntax '{command} [args]'
	out.info "type '$SCRIPTNAME {command}' for more detail help"
	[ $1 ] && exit 1
}

SCRIPTNAME=acmbsd
GROUPSNAME='devel test live temp'
RUNSTR="$0 $@"
COMMAND=$1
VERSION=160

System.checkPermisson || { System.runAsUser root "$RUNSTR"; exit 1; }

#-varSet
ARCH=`uname -p`
OSVERSION="`uname -r` (`uname -v | sed 's/  / /g' | cut -d' ' -f5-6`)"
OSMAJORVERSION=`uname -r | cut -d. -f1`
CVSREPO=cvs.myx.ru
#OLD: PATH="${PATH:+$PATH:}/usr/local/bin"
HOSTNAME=`hostname`

LOCKDIRPATH=/var/run/acmbsd
mkdir -p $LOCKDIRPATH

ACMBSDPATH=/usr/local/$SCRIPTNAME
ACMCM5PATH=$ACMBSDPATH/acm.cm5
GEOSHAREDPATH=$ACMBSDPATH/geo
DBTEMPLATEFILE=$ACMBSDPATH/scripts/db-template/acmbsd.backup
WATCHDOGFLAG=$LOCKDIRPATH/watchdog.pid
PGDATAPATH=/usr/local/pgsql/data
ACMBSDCOMPFILE=/tmp/acmbsd.cli.completion.list
PORTSUPDLOGFILE=/tmp/acmbsd.updports.log
OSUPDLOGFILE=/tmp/acmbsd.updbsd.log

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

load.module out base cfg data named mail group_static instance_static zone watchdog report

COMMENTEDCOMMANDS=`cat $0 | fgrep -A1 '#COMMAND:'`
COMMANDS=`echo "$COMMENTEDCOMMANDS" | grep -v '#' | grep -oE '\b[a-z]*\)?\b'`
[ "$COMMAND" ] && echo "$COMMANDS" | fgrep -qw $COMMAND || Syntax.help exit

VARS=`eval echo '${@#'$COMMAND'}'`
parseOpts $VARS
[ "$COMMAND" != updatebsd -a "$COMMAND" != preparebsd ] && umask 002

[ ! -d "$ACMBSDPATH" ] && System.fs.dir.create $ACMBSDPATH > /dev/null

DEFAULTGROUPPATH=`cfg.getValue groupspath`
if [ -z "$DEFAULTGROUPPATH" ]; then
	cfg.setValue groupspath /usr/local/acmgroups
	DEFAULTGROUPPATH=/usr/local/acmgroups
fi

#TODO: use SHAREDPATH to store non-group data. already done?
SHAREDPATH=`cfg.getValue sharedpath`
if [ -z "$SHAREDPATH" ]; then
	cfg.setValue sharedpath /usr/local/acmshared
	SHAREDPATH=/usr/local/acmshared
fi
mkdir -p $SHAREDPATH
BACKUPPATH=$SHAREDPATH/backup

BACKUPLIMIT=`cfg.getValue backuplimit`
if [ -z "$BACKUPLIMIT" ]; then
	cfg.setValue backuplimit 7
	BACKUPLIMIT=7
fi

load.module farm csync

#TODO: move to groups_static
System.getGroups() {
	GROUPS=""
	if [ -d $DEFAULTGROUPPATH ]; then
		local GROUPNAME
		for GROUPNAME in `ls $DEFAULTGROUPPATH`; do
			test -d $DEFAULTGROUPPATH/$GROUPNAME/public && GROUPS="$GROUPS$GROUPNAME "
		done
		GROUPS=${GROUPS% }
	fi
}
System.getGroups

ACTIVATEDGROUPS=`Group.groups.getActive`

case $COMMAND in
	#COMMAND:EVERYDAY
	cli)
		if Console.isOptionExist rlwrap; then
			while true; do
				printf "acmbsd# "
				read CMD
				if echo "quit exit" | fgrep -qw $CMD; then
					printf "\n"
					exit 0
				fi
				$0 $CMD
			done
			exit 0
		fi
		MODS="system snitch all system check"
		SETTINGS="autotime extip memory branch type instances ru.myx.ae3.properties.log.level ea rollback reset"
		printf "$GROUPS\n$COMMANDS\n$MODS\n$SETTINGS" > $ACMBSDCOMPFILE
		rlwrap -f $ACMBSDCOMPFILE $0 cli -rlwrap
	;;
	#COMMAND:EVERYDAY
	start)
		data.setTo GROUPNAME
		if Group.create $GROUPNAME && $GROUPNAME.isExist; then
			$GROUPNAME.start
			Watchdog.check
			exit 0
		fi
		case $GROUPNAME in
			all)
				Group.startAll "$GROUPS"
			;;
			rcacm)
				[ "`cfg.getValue cluster`" ] && farm.connect
				Group.startAll "$ACTIVATEDGROUPS"
				mail.send "`/sbin/dmesg -a`" 'server started' plain
			;;
			*)
				Syntax.start
			;;
		esac
	;;
	#COMMAND:DEVEL
	profile)
		data.setTo GROUPNAME
		if Group.getData $GROUPNAME && Group.isPassive $GROUPNAME; then
			Instance.getData ${GROUPNAME}1
#			PRIVATE=$HOME/acmprofile
			System.fs.dir.create $PRIVATE > /dev/null 2>&1
#			LOGS=$PRIVATE/logs
			System.fs.dir.create $LOGS > /dev/null 2>&1
			cd $PUBLIC
			ADMINMAIL=$(cfg.getValue adminmail)
			PROGEXEC="java -server"
			ACMEA=$(cfg.getValue $GROUPNAME-ea)
			if [ "$ACMEA" = enable ]; then
				PROGEXEC="$PROGEXEC -ea"
			fi
			for ITEM in $EXTIP; do
				IP=$ITEM
				break
			done
		#	-agentpath:/home/vlapan/yjp-8.0.6/bin/freebsd-x86-32/libyjpagent.so=listen=192.168.1.254:14777
		#	-Dtijmp.jar=/usr/local/share/java/classes/tijmp.jar -agentlib:tijmp
		#	-XX:+HeapDumpOnOutOfMemoryError -agentlib:hprof=heap=dump,format=b
		#	-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=14888 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false
			PROGEXEC="$PROGEXEC -Duser.home=$HOME -Dru.myx.ae3.properties.groupname=$GROUPNAME -Dru.myx.ae3.properties.hostname=$GROUPNAME.$(sysctl -n kern.hostname) -Dru.myx.ae3.properties.log.level=$ACMLOGLEVEL -Djava.net.preferIPv4Stack=true -Dru.myx.ae3.properties.ip.wildcard.host=$IP -Dru.myx.ae3.properties.ip.shift.port=14000 -Dru.myx.ae3.properties.path.private=$PRIVATE -Dru.myx.ae3.properties.path.protected=$PROTECTED -Dru.myx.ae3.properties.path.logs=$LOGS -Xmx$MEMORY -Xms$MEMORY -Dfile.encoding=CP1251 -Dru.myx.ae3.properties.report.mailto=$ADMINMAIL -jar boot.jar"
			$PROGEXEC
			exit 0
		fi
		out.syntax "profile {GROUPNAME}"
		exit 1
	;;
	#COMMAND:SYSTEM
	watchdog)
		Watchdog.command
	;;
	#COMMAND:EVERYDAY
	stop)
		data.setTo GROUPNAME
		if Group.create $GROUPNAME && $GROUPNAME.isExist; then
			$GROUPNAME.stop
			Watchdog.check
			exit 0
		fi
		case $GROUPNAME in
			all)
				Group.stopAll "$GROUPS"
			;;
			rcacm)
				System.setShutdown true
				out.info "next start: $ACTIVATEDGROUPS"
				Group.stopAll "$ACTIVATEDGROUPS"
				mail.send "`Report.getFullReport`" "server shutdown" "html"
			;;
			*)
				Syntax.stop
			;;
		esac
	;;
	#COMMAND:EVERYDAY
	restart)
		data.setTo GROUPNAME
		if Group.create $GROUPNAME && $GROUPNAME.isActive; then
			Watchdog.check
			$GROUPNAME.restart
			exit 0
		fi
		case $GROUPNAME in
			all)
				for GROUPNAME in $ACTIVATEDGROUPS ; do
					Group.create $GROUPNAME && $GROUPNAME.isExist && $GROUPNAME.restart
				done
				Watchdog.check
			;;
			*)
				Syntax.restart
		esac
	;;
	#COMMAND:EVERYDAY
	update)
		RETVAL=0
		data.setTo GROUPNAME
		if Group.isGroup $GROUPNAME; then
			if ! Group.create $GROUPNAME && $GROUPNAME.isExist;then
				out.error "can't find group"
				echo && exit 1
			fi
			if Console.isOptionExist rollback; then
				Group.getData
				out.message "Check for public backup($PUBLICBACKUP) and his version..." waitstatus
				if [ -f "$PUBLICBACKUP/version/version" ]; then
					out.status green "`cat $PUBLICBACKUP/version/version`"
					out.message "Rollback in the previous version..." waitstatus
#						echo 'Rollback in the previous version...'
					cd $GROUPPATH
					$0 stop $GROUPNAME
					mv $PUBLIC $PUBLIC-tmp && mv $PUBLICBACKUP $PUBLIC && rm -rdf $PUBLIC-tmp
					rm protected/boot.properties
					for INSTANCE in $INSTANCELIST; do
						Instance.getData
						rm -rdf $PRIVATE/data/
						rm -rdf $PRIVATE/cache/
						rm -rdf $PRIVATE/settings/
						rm -rdf $PRIVATE/temp/
						rm $PRIVATE/boot.properties
					done
					$0 start $GROUPNAME
					out.message "Set update status to 'freeze'..." waitstatus
#						echo -n "Set update status to 'freeze'..."
					out.status green DONE
## TODO: freeze update
				else
					out.status red "NOT FOUND"
					echo
					exit 1
				fi
				echo
				exit 0
			fi
			out.message "Command '$COMMAND' running" no "[$COMMAND]"
			BRANCH=`$GROUPNAME.getBranch`
			VERSIONFILE=$ACMCM5PATH/$BRANCH/version/version
			cvsacmcm $BRANCH `cat $VERSIONFILE 2> /dev/null || echo 0` || exit 1
			Group.create $GROUPNAME && $GROUPNAME.update
			echo
			exit $RETVAL
		fi
		# If it wasn't group name then it's probably one of commands
		case $GROUPNAME in
			all)
				out.message "Command '$COMMAND' running" no "[$COMMAND]"
				# Script.update
				for ITEM in `ls $ACMCM5PATH/$BRANCH`; do
					VERSIONFILE=$ACMCM5PATH/$ITEM/version/version
					cvsacmcm $ITEM `cat $VERSIONFILE 2> /dev/null || echo 0`
				done
				Group.updateAll
			;;
			system)
				out.message "Command '$COMMAND' running" no "[$COMMAND]"
				Script.update
			;;
			geo)
				Command.depend.activeGroup
				System.fs.dir.create $GEOSHAREDPATH
				fetch -v -a -m -o $GEOSHAREDPATH ftp://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-latest
				fetch -v -a -m -o $GEOSHAREDPATH ftp://ftp.apnic.net/pub/stats/apnic/delegated-apnic-latest
				fetch -v -a -m -o $GEOSHAREDPATH/delegated-arin-latest ftp://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest
				fetch -v -a -m -o $GEOSHAREDPATH ftp://ftp.apnic.net/pub/stats/iana/delegated-iana-latest
				fetch -v -a -m -o $GEOSHAREDPATH ftp://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-latest
				fetch -v -a -m -o $GEOSHAREDPATH ftp://ftp.ripe.net/ripe/stats/delegated-ripencc-latest

				for GROUPNAME in $ACTIVATEDGROUPS; do
					Group.create $GROUPNAME
					for INSTANCE in `$GROUPNAME.getInstanceActive`; do
						if Instance.create $INSTANCE && $INSTANCE.isExist && $INSTANCE.isActive; then
							INSTANCE_GEOFOLDER=`$INSTANCE.getField HOME`/import/ip_geography

							echo $INSTANCE_GEOFOLDER
							cd $INSTANCE_GEOFOLDER

							cp $GEOSHAREDPATH/* $INSTANCE_GEOFOLDER/

							rm delete.when.ready
						else
							out.error 'bad instance name or not exists or not active'
							exit 1
						fi
						break;
					done
				done
			;;
			check)
				out.message "Command '$COMMAND' running" no "[$COMMAND]"
				Script.update.check
				for ITEM in `ls $ACMCM5PATH/$BRANCH`; do
					VERSIONFILE=$ACMCM5PATH/$ITEM/version/version
					cvsacmcm $ITEM `cat $VERSIONFILE 2> /dev/null || echo 0` onlycheck
				done
			;;
			*)
				out.syntax "update ( all | system | geo | check | {groupname} ) [-rollback] [-force]"
				cat <<-EOF
					Options:
					 	rollback - rollback to the previous version and set 'frozen' status
					 	release - removes the frozen status of the group
					 	freeze - establishes a frozen status of the group
					 	force - update group(s) without check
					`[ "$GROUPS" ] && Group.groups.getStatus || out.error 'no groups exist!'`
				EOF
				echo
				exit 1
			;;
		esac
		echo
		exit ${RETVAL}
	;;
	#COMMAND:INFREQ
	add)
		#TODO: check is there a function to do it
		for ITEM in $GROUPSNAME; do
			if ! echo $GROUPS | fgrep -qw $ITEM; then
				if [ "$FREEGROUPS" ]; then
					FREEGROUPS="$FREEGROUPS $ITEM"
				else
					FREEGROUPS=$ITEM
				fi
			fi
		done
		echo -n Check for free groups...
		if [ -z "$FREEGROUPS" ]; then
			out.status red "ALL IN USE"
			out.info "All groups are already added!"
			exit 1
		else
			out.status green FOUND
		fi
		data.setTo GROUPNAME
		if Group.create $GROUPNAME && ! $GROUPNAME.isExist; then
			if ! Console.isSettingExist extip && [ "`Network.getFreeIPList`" ]; then
				for ITEM in `Network.getFreeIPList`; do
					$GROUPNAME.add -extip=$ITEM
					break
				done
			else
				$GROUPNAME.add
			fi
			out.info "group '$GROUPNAME' is added, you can change group setting by '$SCRIPTNAME config $GROUPNAME'!"
		else
			cat <<-EOF
				Settings info:
				 	-extip=192.168.1.1 - IP-address that not used by acm.cm already
				 	-memory=256m - memory for each one instance in group, default '512m'
				 	-branch=( release | current ) - branch of acm.cm5, default to live group is 'release'
				 	-type=( minimal | standard | extended | parallel ) - type of group, default 'standard'

				Group type information:
				 	minimal - 1 instance always, hard restart
				 	standard - 1 instance running of 2 instances, soft restart
				 	extended - 2 instances running, but traffic pass only to one, soft restart
				 	parallel - 2 or more instances running, soft restart

				Free groups: $FREEGROUPS
				Free IP-addresses: `Network.getFreeIPList`

				Example: $SCRIPTNAME $COMMAND {groupname} -extip=192.168.1.1 [-branch=release] [-memory=512m] [-type=standard]
			EOF
		fi
		return 0
	;;
	#COMMAND:EVERYDAY
	status)
		case "${MODS}" in
			full)
				Report.system | elinks -dump-width 200 -dump
				echo
				Report.ipnat | elinks -dump-width 200 -dump
				echo
				Report.domains | elinks -dump-width 200 -dump
				echo
				Report.daemons | elinks -dump-width 200 -dump
				echo
				Report.connections | elinks -dump-width 200 -dump
				echo
				Report.diskusage | elinks -dump-width 200 -dump
				echo
				Report.groups | elinks -dump-width 200 -dump
			;;
			system)
				Report.system | elinks -dump-width 200 -dump
			;;
			ipnat)
				Report.ipnat | elinks -dump-width 200 -dump
			;;
			domains)
				Report.domains | elinks -dump-width 200 -dump
			;;
			daemons)
				Report.daemons | elinks -dump-width 200 -dump
			;;
			connections)
				Report.connections | elinks -dump-width 200 -dump
			;;
			diskusage)
				Report.diskusage | elinks -dump-width 200 -dump
			;;
			groups)
				Report.groups | elinks -dump-width 200 -dump
			;;
			*)
				out.info "paths: acmbsd - $ACMBSDPATH, groups - $DEFAULTGROUPPATH, shared - $SHAREDPATH"
				out.syntax "status (system | ipnat | domains | daemons | connections | diskusage | groups | full)"
				exit 1
			;;
		esac
	;;
	#COMMAND:INFREQ
	remove)
		data.setTo GROUPNAME
		if Group.create $GROUPNAME instances && $GROUPNAME.isExist; then
			while true; do
				echo Are you sure?
				echo -n "Commit (yes/no): "
				read COMMIT
				echo $COMMIT | fgrep -q no && exit 0
				echo $COMMIT | fgrep -qw yes && break
			done
			$GROUPNAME.remove
		else
			out.info "You can use 'acmbsd remove {groupname}'"
			exit 1
		fi
	;;
	#COMMAND:INFREQ
	domain)
		ID=`getSettingValue id`
		if [ -z "${ID}" ]; then
			Syntax.domain
			exit 1
		fi
		case ${MODS} in
			config)
				GROUPSARG=$(getSettingValue group)
				if [ "${GROUPSARG}" ]; then
					GROUPSPROCESS=${GROUPSARG}
				else
					GROUPSPROCESS=${GROUPS}
				fi
				CONST="id url user password enable"
				ENABLEARG=$(getSettingValue enable)
				for GROUPNAME in ${GROUPSPROCESS}; do
					if [ "$(echo $GROUPS | fgrep -w $GROUPNAME)" ]; then
						printf "Processing $txtbld$GROUPNAME$txtrst group...\n"
						Group.getData $GROUPNAME
						SERVERSFILE=$SERVERSDIR/$ID.xml
						zone.isDisabled $ID
						case $? in
							0)
								[ "$ENABLEARG" = true ] && zone.enable $ID
							;;
							1)
								if [ "$ENABLEARG" = false ]; then
									zone.disable $ID
								else
									for ITEM in $SETTINGS; do
										KEY=$(echo ${ITEM#-} | cut -d "=" -f 1)
										if [ "$KEY" ] && [ "$(echo $CONST | fgrep -wv $KEY)" ]; then
											PASTVALUE=$(zone.get $KEY)
											VALUE=$(getSettingValue $KEY)
											if [ "$PASTVALUE" = "$VALUE" ]; then
												out.info "Value of '$KEY' key for '$ID' in '$GROUPNAME' group is the same with provided."
											else
												zone.update $KEY $VALUE > $SERVERSFILE.tmp
												mv $SERVERSFILE.tmp $SERVERSFILE
												out.info "Value of '$KEY' key for '$ID' in '$GROUPNAME' group has changed from '$PASTVALUE' to '$VALUE'."
											fi
										fi
									done
								fi
							;;
						esac
						echo
					fi
				done
			;;
			add)
				GROUPSARG=$(getSettingValue group)
				if [ "${GROUPSARG}" ]; then
					GROUPSPROCESS=${GROUPSARG}
				else
					GROUPSPROCESS=${GROUPS}
				fi
				echo "Create database with '${ID}' name..."
				if Database.create ${ID} > /dev/null 2>&1; then
					out.status green DONE
				else
					out.status yellow FAILED
				fi
				# for GROUPNAME in ${GROUPSPROCESS}; do
				# 	if [ "$(echo ${GROUPS} | fgrep -w ${GROUPNAME})" ]; then
				# 		domainadd
				# 	fi
				# done
			;;
			dbuserscheck)
				GROUPSARG=$(getSettingValue group)
				if [ "$GROUPSARG" ]; then
					GROUPSPROCESS=$GROUPSARG
				else
					GROUPSPROCESS=$GROUPS
				fi
				for GROUPNAME in $GROUPSPROCESS; do
					[ "$(echo $GROUPS | fgrep -w $GROUPNAME)" ] && Group.getData $GROUPNAME && dbuserscheck
				done
			;;
			remove)
				for GROUPNAME in ${GROUPS}; do
					Group.getData ${GROUPNAME}
					DOMAINSDATA=$(cat ${SERVERSCONF} | fgrep -w server)
					DOMAINDATA=$(echo "${DOMAINSDATA}" | fgrep -w ${ID})
					echo -n "Check for '${ID}' in servers.xml of '${GROUPNAME}' group..."
					if [ -z "${DOMAINDATA}" ];then
						out.status yellow "NOT FOUND"
					else
						out.status green "FOUND"
						echo -n "Remove entry '${ID}' from '${GROUPNAME}' group..."
						DOMAINSDATA=$(echo "${DOMAINSDATA}" | fgrep -v -w ${ID})
						printf "<servers>\n${DOMAINSDATA}\n</servers>\n" > ${SERVERSCONF}
						out.status green "OK"
						echo -n "Remove '${WEB}/${ID}'..."
						rm -rdf ${WEB}/${ID}
						out.status green "OK"
					fi
				done
			;;
			push)
				GROUPNAME=$(getSettingValue group)
				if [ -z "${GROUPNAME}" ]; then
					out.syntax "domain push -id={domain} -group=( devel | test )\n\n"
				fi
				DEVEL=$(echo ${GROUPS} | fgrep devel)
				TEST=$(echo ${GROUPS} | fgrep test)
				LIVE=$(echo ${GROUPS} | fgrep live)
				case ${GROUPNAME} in
					test)
						if [ "${TEST}" -a "${LIVE}" ]; then
							FROMGROUP=test
							TOGROUPS=live
							domainsync
						fi
					;;
					devel)
						FROMGROUP=devel
						if [ "${DEVEL}" -a "${TEST}" ]; then
							TOGROUPS=test
							domainsync
						else
							if [ "${DEVEL}" -a "${LIVE}" ]; then
								TOGROUPS=live
								domainsync
							fi
						fi
					;;
				esac
			;;
			sync)
				FROMGROUP=$(getSettingValue from)
				TOGROUPS=$(getSettingValue to)
				if [ -z "${FROMGROUP}" -o -z "${TOGROUPS}" ]; then
					out.syntax "domain sync -id={domain} -from={groupname} -to={groupname} [-to={groupname}]\n\n"
					exit 1
				fi
				domainsync
			;;
			*)
				Syntax.domain
			;;
		esac
	;;
	#COMMAND:INFREQ
	config)
		#TODO: MODS?
		if [ "$MODS" ] && echo $GROUPS | fgrep -q $MODS; then
			Group.create $MODS
			if [ -z "$SETTINGS" ]; then
				$MODS.getSettings
				out.syntax "$COMMAND {groupname} [-branch=(current | release)] [-memory=256m] [-optimize=(deafult | speed | size)] [-extip=10.1.1.1] [-publicip=10.1.1.2] [-type=standard] [-instances={1,9}] [-namedtransfer=10.1.0.1]\n"
				exit 1
			fi
			$MODS.config && exit 0
		fi
		case "$MODS" in
			system)
				ADMIN=`cfg.getValue adminusers`
				ADMINMAIL=`cfg.getValue adminmail`
				AUTOTIME=`cfg.getValue autotime`
				#TODO: global?
				SHAREDPATH=`cfg.getValue sharedpath`
				BACKUPLIMIT=`cfg.getValue backuplimit`
				NAMEDTRANSFER=`cfg.getValue namedtransfer || echo none`
				RELAYHOST=`cfg.getValue relayhost`
				if [ -z "$SETTINGS" ]; then
					cat <<-EOF
						Settings info and thier values:
						 	-path=$DEFAULTGROUPPATH - default store path for new groups
						 	-admin=$ADMIN - user that control system, list allowed with ',' as separator
						 	-email=$ADMINMAIL - administrator's email for errors and others
						 	-autotime=$AUTOTIME - time, like 02:30, when service daemon starts, value can be 'off'
						 	-shared=$SHAREDPATH - shared dir for backup store and etc
						 	-relay=$RELAYHOST - SMTP relay host
						 	-namedtransfer=$NAMEDTRANSFER - to set global 'allow-transfer' option in named.conf, list allowed with ',' as separator, 'none' to turn off
						 	-backuplimit=$BACKUPLIMIT - how many auto backups need to store (1-16), default is '7'

						Example: acmbsd config system -email=someone@domain.org,anotherone@domain.org -autotime=04:00 -path=/usr/local/acmgroups
					EOF
				fi
				for ITEM in $SETTINGS; do
					KEY=`echo $ITEM | cut -d= -f1`
					VALUE=`echo $ITEM | cut -d= -f2`
					if [ -z "$VALUE" ]; then
						out.error "bad value on '$KEY' key!"
						exit 1
					fi
					case $KEY in
						#TODO: change groups user home path `pw usermod live1 -d /usr/local/acmbsd/groups/live`
						-path)
							PASTVALUE=$DEFAULTGROUPPATH
							[ "$PASTVALUE" = $VALUE ] && out.info 'Same here' && exit 1
							cfg.setValue groupspath $VALUE
							out.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-admin)
							PASTVALUE=$ADMIN
							[ "$PASTVALUE" = $VALUE ] && out.info 'Same here' && exit 1
							cfg.setValue adminusers $VALUE
							$0 access
							out.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-relay)
							PASTVALUE=$RELAYHOST
							[ "$PASTVALUE" = $VALUE ] && out.info 'Same here' && exit 1
							cfg.setValue relayhost $VALUE
							MAINCF=`cat /usr/local/etc/postfix/main.cf | sed -l '/^relayhost/d'`
							echo "$MAINCF" > /usr/local/etc/postfix/main.cf
							echo "relayhost = $VALUE" >> /usr/local/etc/postfix/main.cf
							/usr/local/etc/rc.d/postfix stop
							/usr/local/etc/rc.d/postfix start
							out.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-email)
							PASTVALUE=$ADMINMAIL
							[ "$PASTVALUE" = $VALUE ] && out.info 'Same here' && exit 1
							cfg.setValue adminmail $VALUE
							#TODO: diff PASTVALUE VALUE
							#TODO: check message set vertical split
							mail.send "PASTVALUE:'$PASTVALUE' VALUE:'$VALUE'" "administrator's email changed" plain -email=$PASTVALUE,$VALUE
							out.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
							mail.aliases.check
						;;
						-autotime)
							PASTVALUE=$AUTOTIME
							[ "$PASTVALUE" = $VALUE ] && out.info 'Same here' && exit 1
							cfg.setValue autotime $VALUE
							out.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-shared)
							PASTVALUE=$SHAREDPATH
							[ "$PASTVALUE" = $VALUE ] && out.info 'Same here' && exit 1
							cfg.setValue sharedpath $VALUE
							out.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-backuplimit)
							echo $VALUE | fgrep -vwqoE "[0-9]{1,2}" && out.error "setting '$KEY' has bad value!" && continue
							PASTVALUE=$BACKUPLIMIT
							[ "$PASTVALUE" = $VALUE ] && out.info 'Same here' && exit 1
							cfg.setValue backuplimit $VALUE
							out.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-namedtransfer)
							PASTVALUE=$NAMEDTRANSFER
							[ "$PASTVALUE" = $VALUE ] && out.info 'Same here' && exit 1
							[ $VALUE = none ] || for IP in `echo $VALUE | tr ',' ' '`; do
								out.message "Check IP '$IP'..." waitstatus
								! Network.isIP $IP && out.status red BAD && exit 1
								out.status green OK
							done
							[ $VALUE = none ] && cfg.remove namedtransfer || cfg.setValue namedtransfer $VALUE
							out.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
					esac
				done
			;;
			*)
				out.syntax "config ( system | {groupname} ) {settings}"
				if [ "$GROUPS" ]; then
					printf "Groups list: ${txtbld}`echo $GROUPS`${txtrst}\n"
				else
					out.error "no groups exist!"
				fi
			;;
		esac
		echo
	;;
	#COMMAND:INFREQ
	install)
		out.message "Command '$COMMAND' running" no "[$COMMAND]"
		System.fs.dir.create $ACMBSDPATH
		System.fs.dir.create $DEFAULTGROUPPATH
		System.changeRights $DEFAULTGROUPPATH acmbsd acmbsd 0775 -recursive=false

		MIG1_SHAREDPATH=`cfg.getValue sharedpath`
		if [ -z "$MIG1_SHAREDPATH" -o ! -d $MIG1_SHAREDPATH ]; then
			MIG1_BACKUPPATH=`cfg.getValue backuppath`
			if [ "$MIG1_BACKUPPATH" ]; then
				cfg.setValue sharedpath $MIG1_BACKUPPATH
				SHAREDPATH=$MIG1_BACKUPPATH
				System.fs.dir.create $SHAREDPATH
				cfg.remove backuppath
			fi
		else
			System.fs.dir.create $SHAREDPATH
		fi

		base.file.checkLine /etc/rc.conf postgresql_enable=\"YES\"
		out.message "Check for '/usr/local/pgsql/data" waitstatus
		if [ -d /usr/local/pgsql/data ]; then
			out.status green FOUND
		else
			out.status yellow "NOT FOUND"
			if /usr/local/etc/rc.d/postgresql initdb; then
				/usr/local/etc/rc.d/postgresql start
			else
				out.error "can not initdb!"
				exit 1
			fi
		fi
		if ! echo $OPTIONS | fgrep -q noupdate; then
			echo
			out.message "Running 'acmbsd update all'..."
			#TODO: error when 'acmbsd.sh' not executable
			$0 update all
		fi
		scriptlink /usr/local/bin/acmbsd $ACMBSDPATH/scripts/acmbsd.sh
		scriptlink /usr/local/etc/rc.d/rcacm.sh $ACMBSDPATH/scripts/rcacm.sh
		Watchdog.restart
		echo
	;;
	#COMMAND:INFREQ
	deinstall)
		echo -n "Commit this operation (yes/NO): "
		#TODO: one pipe for read and grep?
		read COMMIT
		echo $COMMIT | fgrep -w yes || exit 0
		#TODO: REDO
		/usr/local/etc/rc.d/rcacm.sh stop
		rm -rdf $ACMBSDPATH
		rm /usr/local/bin/acmbsd
		rm /usr/local/etc/rc.d/rcacm.sh
		out.info "untouched directories: $DEFAULTGROUPPATH $SHAREDPATH"
		#TODO: full dependencies list
		out.info "additional packages not removed such as bash, postgresql, mpd5 and etc!"
	;;
	#COMMAND:INFREQ
	preparebsd)
		load.module conf pkg pgsql
		echo Prepareing BSD...
		mail.aliases.check
		System.fs.dir.create ${ACMBSDPATH}/.ssh
		echo -n Check for keys...
		if [ ! -f "${ACMBSDPATH}/.ssh/id_rsa" -o ! -f "${ACMBSDPATH}/.ssh/id_rsa.pub" ]; then
			ssh-keygen -q -N "" -f ${ACMBSDPATH}/.ssh/id_rsa -t rsa
			out.status green CREATED
		else
			out.status green FOUND
		fi
		## Keeps SSH connection
		base.file.checkLine /etc/ssh/sshd_config '^ClientAliveInterval*' 'ClientAliveInterval 60'
		base.file.checkLine /etc/ssh/sshd_config '^ClientAliveCountMax*' 'ClientAliveCountMax 10'
		##
		sys.grp.chk $SCRIPTNAME
		sys.usr.chk $SCRIPTNAME && sys.usr.setHome $SCRIPTNAME $ACMBSDPATH


		base.file.checkLine /etc/rc.conf sshd_enable=\"YES\"
		base.file.checkLine /etc/rc.conf fsck_y_enable=\"YES\"
		base.file.checkLine /etc/rc.conf named_enable=\"YES\"
		base.file.checkLine /etc/rc.conf ntpdate_enable=\"YES\"
		base.file.checkLine /etc/rc.conf ntpdate_flags 'ntpdate_flags="-b pool.ntp.org europe.pool.ntp.org time.euro.apple.com"'

		# conf.install profile.sh /etc/profile
		# conf.install inputrc /etc/inputrc
		# conf.install login.conf /etc/login.conf
		# cap_mkdb /etc/login.conf

		pkg.install cvs- devel/cvs
		pkg.install bash shells/bash
		pkg.install screen sysutils/screen
		conf.install screenrc /usr/local/etc/screenrc

		pkg.install sudo security/sudo
		conf.install sudoers /usr/local/etc/sudoers
		chown root:wheel /usr/local/etc/sudoers
		chmod 0440 /usr/local/etc/sudoers

		pkg.install nano editors/nano
		conf.install nanorc /usr/local/etc/nanorc

		BATCH="YES" POSTFIX_DEFAULT_MTA="YES" pkg.install postfix mail/postfix
		mail.check
		pkg.install metamail mail/metamail

		pgsql.check
		csync.check

		pkg.install curl ftp/curl
		pkg.install rsync net/rsync
		pkg.install rlwrap devel/rlwrap
		pkg.install elinks www/elinks

		pkg.install xtail misc/xtail
		pkg.install xmlstarlet textproc/xmlstarlet
		pkg.install ncdu sysutils/ncdu
		pkg.install tinc security/tinc
		pkg.install mtr-nox11 net/mtr-nox11
		pkg.install ack textproc/ack
		pkg.install smartmontools sysutils/smartmontools
		pkg.install cpuflags devel/cpuflags
		pkg.install ipcalc net-mgmt/ipcalc
		pkg.install trafshow net/trafshow

		#TODO: there is no use for them yet, check these ports
		pkg.install host-setup sysutils/host-setup
		pkg.install sysrc sysutils/sysrc

		pkg.install openjdk openjdk8

		pkg.install bind910 dns/bind910

		out.info "Fresh system? Reboot your OS!"
		echo
	;;
	#COMMAND:SYSTEM
	service)
		/etc/rc.d/ntpdate start
		Watchdog.restart
		${0} autoreport
		if ! echo $OPTIONS | fgrep -w nobackup > /dev/null 2>&1 ; then
			${0} autobackup
		fi
		#${0} autoupdate
		mail.send "$(top -bItaSC)" "top status" "plain"
		${0} restart all > /tmp/acmbsd.restart.tmp 2> /tmp/acmbsd.restart.tmp
		${0} autoreport
		if [ -f /tmp/acmbsd.service.log ]; then
			mail.send "$(cat /tmp/acmbsd.service.log)" "service log" "plain"
			rm -rdf /tmp/acmbsd.service.log
		fi
	;;
	#COMMAND:SYSTEM
	autoreport)
		mail.send "$(Report.getFullReport)" "status report" "html"
	;;
	#COMMAND:SYSTEM
	autoupdate)
		${0} update all -auto
	;;
	#COMMAND:SYSTEM
	autobackup)
		STARTTIME=`date +%s`
		GROUPNAME=live
		echo -n "Check for '$GROUPNAME' group..."
		if echo $GROUPS | fgrep -qw $GROUPNAME; then
			out.status green FOUND
		else
			out.status red "NOT FOUND"
			exit 1
		fi
		Group.getData
		System.fs.dir.create $WEB
		SITES=`ls -U $WEB`
		if [ -z "$SITES" ]; then
			out.error "group 'live' do not have any domains!"
			exit 1
		fi
		for ITEM in $SITES; do
			$0 backup -domain=$ITEM
		done
		NOW=`date +%s`
		TIME=$((NOW-STARTTIME))
		UPTIME=`getuptime $TIME`
		out.info "Backup of all 'live' group domains has completed! Backup time: $UPTIME"
		echo $UPTIME > /tmp/lastacmbackup.time
		echo
	;;
	#COMMAND:INFREQ
	backup)
		#TODO: check one line params
		Syntax.backup(){
			out.syntax "backup -domain=value [-group=( live | test | devel )] [-nodb] [-name=com.domain] [-path=~/mybackups]"
			echo "Produce .tar.gz archive that contains DB or domain files and can be restored with 'acmbsd restore' command."
			[ $1 ] && exit 1
		}
		DOMAIN=`Console.getSettingValue domain`
		[ "$DOMAIN" ] || Syntax.backup exit
		STARTTIME=`date +%s`
		out.info "Backup of '$DOMAIN' has started!"
		for ITEM in $SETTINGS; do
			KEY=`echo $ITEM | cut -d= -f1`
			if echo $KEY | fgrep -qw group; then
				VALUE=`echo $ITEM | cut -d= -f2`
				if echo $GROUPS | fgrep -qw $VALUE; then
					BACKUPGROUPS="$BACKUPGROUPS$VALUE "
				fi
			fi
		done
		[ "$BACKUPGROUPS" ] || BACKUPGROUPS=$GROUPS
		DATE=`date +%Y%m%d-%H%M`
		BACKUPNAME=$DOMAIN.$DATE
		#TODO: strange check style!
		if Console.isSettingExist path; then
			#TODO: check if path exist and writable
			BACKUPDIRPATH=`getSettingValue path`
			if Console.isSettingExist name; then
				BACKUPNAME=`getSettingValue name`
			fi
		else
			BACKUPDIRPATH=$BACKUPPATH/$DOMAIN
			CHANGEPERM=1
		fi
		System.fs.dir.create $BACKUPDIRPATH
		BACKUPTMPPATH="$BACKUPDIRPATH/.tmp.backup.$DATE"
		System.fs.dir.create $BACKUPTMPPATH
		if ! echo $OPTIONS | fgrep -q nodb; then
			echo -n Dumping database...
			#TODO: check if db exist
			if /usr/local/bin/pg_dump -f $BACKUPTMPPATH/db.backup -O -Z 4 -Fc -U pgsql $DOMAIN; then
				out.status green DONE
			else
				out.status red FAILED
				rm -rdf $BACKUPTMPPATH
				out.info "maybe you enter not valid domain name?"
				exit 1
			fi
		fi
		for ITEM in $BACKUPGROUPS; do
			GROUPNAME=$ITEM
			Group.getData
			if [ ! -d "$GROUPPATH/protected/web/$DOMAIN" ]; then
				continue
			fi
			echo -n "Coping domain files from '$ITEM' group..."
			cp -R $GROUPPATH/protected/web/$DOMAIN $BACKUPTMPPATH
			mv $BACKUPTMPPATH/$DOMAIN $BACKUPTMPPATH/$GROUPNAME
			out.status green DONE
		done
		CHECKBACKUPTMP=`ls -U $BACKUPTMPPATH | wc -w`
		if [ $CHECKBACKUPTMP -eq 0 ]; then
			rm -rdf $BACKUPTMPPATH
			out.error "Nothing to backup!"
			exit 1
		fi
		echo -n Archiveing backup folder...
		cd $BACKUPTMPPATH
		CONTENTS=`ls -U`
		/usr/bin/tar -czf $BACKUPDIRPATH/$BACKUPNAME.tar.gz $CONTENTS > /dev/null 2>&1
		#DONE: change owner of backup file after backup
		[ "$CHANGEPERM" = 1 ] && chown acmbsd:acmbsd $BACKUPDIRPATH/$BACKUPNAME.tar.gz
		out.status green DONE
		System.fs.dir.remove() {
			echo -n $1...
			if [ -d $1 ]; then
				if [ `echo $1 | wc -c` -gt 3 ]; then
					rm -rdf $1
					out.status green REMOVED
				else
					out.status red "NOT VALID"
				fi
			else
				out.status yellow "NOT FOUND"
			fi
		}
		System.fs.dir.remove $BACKUPTMPPATH
		if ! Console.isSettingExist path; then
			BACKUPS=`ls -U $BACKUPDIRPATH | grep $DOMAIN`
			COUNT=`echo $BACKUPS | wc -w`
			if [ $COUNT -gt $BACKUPLIMIT ]; then
				echo -n Removeing old backups...
				for ITEM in $BACKUPS; do
					rm -f $BACKUPDIRPATH/$ITEM
					COUNT=$((COUNT - 1))
					if [ $COUNT -le $BACKUPLIMIT ]; then
						break
					fi
				done
				out.status green DONE
			fi
		fi
		echo "Backup path: $BACKUPDIRPATH/$BACKUPNAME.tar.gz"
		echo "Backup contents: "$CONTENTS
		echo "Backup size: `du -h $BACKUPDIRPATH/$BACKUPNAME.tar.gz | cut -f1`"
		NOW=`date +%s`
		TIME=$((NOW-STARTTIME))
		UPTIME=`getuptime $TIME`
		out.info "Backup of '$DOMAIN' has completed! Backup time: $UPTIME"
		echo
	;;
	#COMMAND:INFREQ
	restore)
		if Console.isSettingExist domain && Console.isSettingExist path; then
			STARTTIME=`date +%s`
			BACKUPFILE=`getSettingValue path`
			if [ "$BACKUPFILE" -a ! -f $BACKUPFILE ]; then
				out.error "can not find backup with path '$BACKUPFILE'"
				exit 1
			fi
			DOMAIN=`getSettingValue domain`
			BACKUPGROUPS=`getSettingValue group`
			if [ -z "$BACKUPGROUPS" -a -z `echo $OPTIONS | fgrep -w db` ]; then
				out.error "set what to restore with setting '-group={groupname}' or '-db' !"
				exit 1
			fi
			if [ "$BACKUPGROUPS" ]; then
				#TODO: use mktemp
				BACKUPTMPPATH=$BACKUPPATH/.tmp.restore.$STARTTIME
				System.fs.dir.create $BACKUPTMPPATH
				echo -n Extracting backup folder...
				tar -xzf $BACKUPFILE -C $BACKUPTMPPATH > /dev/null 2>&1
				out.status green DONE
			fi
			for ITEM in $BACKUPGROUPS; do
				if [ ! -d $BACKUPTMPPATH/$ITEM ]; then
					out.error "no '$ITEM' group in backup!"
				fi
				GROUPNAME=$ITEM
				Group.getData
				System.fs.dir.create $GROUPPATH/protected/web/$DOMAIN
				echo -n "Sync domain files with '$ITEM' group..."
				rsync -qa --delete $BACKUPTMPPATH/$ITEM/ $GROUPPATH/protected/web/$DOMAIN
				System.changeRights $GROUPPATH/protected/web/$DOMAIN $GROUPNAME ${GROUPNAME}1
				out.status green DONE
			done
			if Console.isOptionExist db; then
#				if [ -e "$BACKUPTMPPATH/db.backup" ]; then
					#HINT: data base activity check
					DISABLEPROCESSED=''
					if ! Database.check $DOMAIN; then
						Database.create $DOMAIN
					else
						ID=$DOMAIN
						for GROUPNAME in $ACTIVATEDGROUPS; do
							Group.getData $GROUPNAME
							zone.isDisabled $DOMAIN
							case $? in
								1)
									DISABLEPROCESSED="$DISABLEPROCESSED $GROUPNAME"
									zone.disable $DOMAIN
								;;
							esac
						done
						for GROUPNAME in $DISABLEPROCESSED; do
							$0 restart $GROUPNAME
						done
					fi
					Group.getData live
					dbuserscheck $DOMAIN
					out.message 'Restore database...'
					tar xf $BACKUPFILE -O --totals db.backup | /usr/local/bin/pg_restore -d $DOMAIN -Oc -U pgsql
#pg_restore -d $DOMAIN -Ovc -U pgsql $BACKUPTMPPATH/db.backup
					Database.counters.correct $DOMAIN
					if [ "$ID" ]; then
						for GROUPNAME in $DISABLEPROCESSED; do
							Group.getData $GROUPNAME
							zone.isDisabled $DOMAIN
							case $? in
								0)
									zone.enable $DOMAIN
								;;
							esac
						done
						for GROUPNAME in $DISABLEPROCESSED; do
							$0 restart $GROUPNAME
							#TODO: uncomment
							#-reset=all
						done
					fi
#				else
#					out.error 'no database in backup!'
#				fi
			fi
			rm -rdf $BACKUPTMPPATH
			NOW=`date +%s`
			TIME=$((NOW-STARTTIME))
			UPTIME=`getuptime $TIME`
			out.info "Restoration of '$DOMAIN' has been completed! Restoration time: $UPTIME"
		else
			#TODO: if no domain setted, then list domain that have backups and last backup date
			if [ -d $BACKUPPATH ]; then
				echo Backups list:
				if Console.isSettingExist domain; then
					DOMAIN=`Console.getSettingValue domain`
					BACKUPS=`ls $BACKUPPATH/$DOMAIN | grep tar.gz`
					for ITEM in $BACKUPS; do
						printf "\t${txtbld}$BACKUPPATH/$ITEM${txtrst}\n"
					done
				else
					echo `ls $BACKUPPATH`
				fi
			fi
			out.syntax
			printf "\t1.List all backups and prints this help\n"
			printf "\t\tacmbsd restore\n"
			printf "\t2.List domain backups and prints this help\n"
			printf "\t\tacmbsd restore -domain={domain}\n"
			printf "\t3.Restore backup with group files or/and database\n"
			printf "\t\tacmbsd restore -domain={domain} -path=/path/to/backup.tar.gz [-db] [-group={groupname}]\n"
		fi
		echo
	;;
	#COMMAND:DEVEL
	reset)
		data.setTo INSTANCE LOGFILENAME
		GROUPNAME=$(echo $INSTANCE | tr -d '[0-9]')
		Group.create $GROUPNAME || exit 1
		if [ "$GROUPNAME" = "$INSTANCE" ]; then
				out.error 'give me instance name'
				exit 1
		fi
		if Instance.create $INSTANCE && $INSTANCE.isExist && ! $INSTANCE.isActive; then
			$INSTANCE.reset -reset=all
		else
			out.error 'bad instance name or not exists or active'
			exit 1
		fi
	;;
	#COMMAND:DEVEL
	readlog)
		data.setTo INSTANCE LOGFILENAME
		GROUPNAME=$(echo ${INSTANCE} | tr -d "[0-9]")
		Group.getData ${GROUPNAME} || exit 1
		if [ "${GROUPNAME}" = "${INSTANCE}" ]; then
			INSTANCE=$(echo ${ACTIVEINSTANCES} | cut -d" " -f1)
			if [ -z "${INSTANCE}" ]; then
				out.error "Active instances not found!"
				exit 1
			fi
		fi
		if Instance.isExist ${INSTANCE} && Instance.getData && test "${LOGFILENAME}"; then
			if [ "${LOGFILENAME}" = "log" -o "${LOGFILENAME}" = "stdout" -o "${LOGFILENAME}" = "out" ]; then
				LOGFILE="${ACMOUT}"
			else
				LOGFILENAMES=$(ls -U ${LOGS})
				LOGITEMFILTERED=$(echo "${LOGFILENAMES}" | fgrep -w ${LOGFILENAME} | tail -n 1)
				echo ${LOGITEMFILTERED}
				if [ -z "${LOGITEMFILTERED}" ]; then
					echo "nothing found"
					exit 1
				fi
				LOGFILES=$(ls -U ${LOGS}/${LOGITEMFILTERED} | tail -n 2)
				for ITEM in ${LOGFILES}; do
					LOGFILEINFO=$(du ${LOGS}/${LOGITEMFILTERED}/${ITEM})
					LOGFILESIZE=$(echo ${LOGFILEINFO} | cut -f1 -d" ")
					if [ "${LOGFILESIZE}" != "0" ]; then
						LOGFILE=${LOGS}/${LOGITEMFILTERED}/${ITEM}
					fi
				done
			fi
			if [ "${LOGFILE}" -a -f "${LOGFILE}" ]; then
				less -cSwM +G --follow-name -- ${LOGFILE}
			else
				out.error "can not find log file!"
			fi
		else
			out.syntax "readlog ( {group} | {instance} ) {log}"
			echo "Examples:"
			printf "\tfixed instance - ${0} readlog live1 stdout\n"
			printf "\tactive instance - ${0} readlog live stdout\n"
			echo
			exit 1
		fi
	;;
	#COMMAND:DEVEL
	watchlog)
		#Command.depend.activeGroup
		data.setTo GROUPNAME LOGLIST +
		if [ -z "${GROUPNAME}" ]; then
			Syntax.watchlog
			exit 1
		fi
		if ! Group.isExist "${GROUPNAME}" passAll; then
			Syntax.watchlog
			exit 1
		fi
		if [ "${GROUPNAME}" = "all" ]; then
			GROUPNAME=${ACTIVATEDGROUPS}
		fi
		LOGFILES=""
		for GROUPITEM in ${GROUPNAME}; do
			Group.getData ${GROUPITEM}
			INSTANCE=$(echo ${ACTIVEINSTANCES} | cut -d" " -f1)
			Instance.getData
			if [ "${LOGS}" ]; then
				LOGFILENAMES=$(ls -U ${LOGS})
				if [ -z "${LOGLIST}" ]; then
					LOGLIST="log stdout default"
				fi
				for LOGITEM in ${LOGLIST}; do
					LOGSITEMFILTERED=$(echo "${LOGFILENAMES}" | fgrep -w ${LOGITEM} | fgrep -v ".prev")
					if [ -z "${LOGSITEMFILTERED}" ]; then
						continue
					fi
					for LOGITEMFILTERED in ${LOGSITEMFILTERED}; do
						LOGFILES="${LOGFILES}${LOGS}/${LOGITEMFILTERED} "
					done
				done
			fi
		done
		out.info "to quit from xtail press 'Ctrl+\\\'"
		out.info "tail starting..."
		echo "Files: "${LOGFILES}
		xtail ${LOGFILES}
	;;
	#COMMAND:DEVEL
	mixlog)
		data.setTo GROUPNAME YEAR MONTH DAY HOUR MINUTE SECOND
		if [ -z "${GROUPNAME}" -o -z "${YEAR}" -o -z "${MONTH}" -o -z "${DAY}" -o -z "${HOUR}" ]; then
			Syntax.mixlog
			exit 1
		fi
		if ! Group.isExist "${GROUPNAME}" passAll; then
			Syntax.mixlog
			exit 1
		fi
		if [ "${GROUPNAME}" = "all" ]; then
			GROUPNAME=${ACTIVATEDGROUPS}
		fi
		if [ -z "${MINUTE}" ]; then
			MINUTE="[0-9]{2}"
		fi
		if [ -z "${SECOND}" ]; then
			SECOND="[0-9]{2}"
			AUTOSECOND=true
		fi
		echo "" > /tmp/mixlog
		for GROUPITEM in ${GROUPNAME}; do
			Group.getData ${GROUPITEM}
			INSTANCE=$(echo ${ACTIVEINSTANCES} | cut -d" " -f1)
			Instance.getData
			if [ "${LOGS}" ]; then
				LOGLIST=$(ls -U ${LOGS})
				if [ "${AUTOSECOND}" ]; then
					LOGLIST=$(echo "${LOGLIST}" | fgrep -v sql)
				fi
				for LOGITEM in ${LOGLIST}; do
					LOGFILENAMES=$(ls -U ${LOGS}/${LOGITEM} | fgrep ${YEAR}${MONTH}${DAY})
					for LOGFILE in ${LOGFILENAMES}; do
						cat ${LOGS}/${LOGITEM}/${LOGFILE} | fgrep -E "${YEAR}-${MONTH}-${DAY}\ (${HOUR})\:(${MINUTE})\:(${SECOND})" >> /tmp/mixlog
					done
				done
			fi
		done
		sort /tmp/mixlog
	;;
	#COMMAND:DEVEL
	dig)
		Syntax.dig() {
			out.syntax "dump ( snitch | start | stop ) {groupname}"
			if [ "${GROUPS}" ]; then
				Group.groups.getStatus
			else
				out.error "no groups exist!"
			fi
			exit 1
		}
		data.setTo MOD GROUPNAME
		GROUPNAME=$(echo ${GROUPS} | tr " " "\n" | grep -w "${GROUPNAME}")
		if [ -z "${GROUPNAME}" ]; then
			Syntax.dig
		fi
		case ${MOD} in
			snitch)
				${0} dump -group=${GROUPNAME} -mail
				out.info "Watching to logs..."
				WATCHDOGPIDFILE=/var/run/watchdogtolog.pid
				/usr/sbin/daemon -p ${WATCHDOGPIDFILE} ${0} watchlog ${GROUPNAME} > /tmp/acmbsd.watchlog.log 2>&1
				sleep 60
				killbylockfile ${WATCHDOGPIDFILE}
				mail.send "$(cat /tmp/acmbsd.watchlog.log)" "ACM.CM dig" "plain"
				${0} dump -group=${GROUPNAME} -mail
			;;
			start)
				${0} config ${GROUPNAME} -ea=enable
				${0} config ${GROUPNAME} -ru.myx.ae3.properties.log.level=DEVEL
				${0} restart ${GROUPNAME}
			;;
			stop)
				${0} config ${GROUPNAME} -ea=disable
				${0} config ${GROUPNAME} -ru.myx.ae3.properties.log.level=$(Group.default.loglevel ${GROUPNAME})
				${0} restart ${GROUPNAME}
			;;
			*)
				Syntax.dig
			;;
		esac
		echo
	;;
	#COMMAND:DEVEL
	dump)
		data.setTo GROUPNAME
		if Group.getData $GROUPNAME && Group.isActive $GROUPNAME; then
			INSTANCE=`echo $ACTIVEINSTANCES | cut -d' ' -f1`
			Instance.getData
			if ! System.daemon.isExist $DAEMONPID; then
				out.error 'daemon not started!'
				exit 1
			fi
			if [ ! -e $ACMOUT ]; then
				out.error 'can not find log file!'
				exit 1
			fi
			TAILPIDFILE=/var/run/dumptail.pid
			DUMPFILE=/tmp/acmbsd.dump.$INSTANCE.log
			/usr/sbin/daemon -p $TAILPIDFILE tail -n 0 -f $ACMOUT > $DUMPFILE 2>&1
			sleep 1
			if kill -3 $DAEMONPID ; then
				out.info 'Please, do not break this process, script use daemon to cut dump from log file. Time limit is ten seconds!'
				echo -n 'Waiting for dump...'
				COUNT=0
				while true
				do
					sleep 1
					if cat $DUMPFILE | grep 'JNI global references' > /dev/null 2>&1 ; then
						out.status green DONE
						sleep 1
						killbylockfile $TAILPIDFILE > /dev/null 2>&1
						if ! echo $OPTIONS | grep read > /dev/null 2>&1 ; then
							mail.send "`cat $DUMPFILE`" 'ACM.CM dump' 'plain'
						fi
						echo
						if ! echo $OPTIONS | grep mail > /dev/null 2>&1 ; then
							less -cSwM +G $DUMPFILE
						fi
						break
					fi
					if [ "$COUNT" = 10 ]; then
						out.status red FAILED
						killbylockfile $TAILPIDFILE > /dev/null 2>&1
						break
					fi
					COUNT=$((COUNT + 1))
					echo -n .
				done
			else
				out.error 'can not do dump!'
			fi
			exit 0
		fi
		out.syntax 'dump {groupname} [-mail] [-read]'
		out.info '-mail and -read default to true, you can choose one if need!'
		exit 1
	;;
	#COMMAND:DEVEL
	seqcorrect)
		#TODO: use Console
		if [ "$MODS" ]; then
			Database.counters.correct $MODS
		else
			echo "acmbsd seqcorrect {dbname}"
		fi
	;;
	#COMMAND:NOTREADY
	checksites)
		data.setTo GROUPNAME
		GROUPNAME=`echo $GROUPS | tr ' ' '\n' | grep -w "$GROUPNAME"`
		[ -z "$GROUPNAME" ] && Syntax.checksites && exit 1
		Group.getData $GROUPNAME
		domainschecker
	;;
	#COMMAND:DEVEL
	dirs)
		#TODO: more dirs, get list from 'status' command syntax
		for GROUPNAME in $GROUPS; do
			Group.getData $GROUPNAME
			echo $GROUPPATH
		done
	;;
	#COMMAND:DEVEL
	createdb)
		echo -n Create database...
		if [ "$2" ] ; then
			if Database.create $2; then
				out.status green DONE
			else
				out.status red FAILED
				out.error 'database is already exist!'
			fi
		else
			out.syntax 'createdb {dbName}'
		fi
	;;
	#COMMAND:DEVEL
	fixfs)
		System.changeRights $ACMBSDPATH acmbsd acmbsd 'a=rX,ug+w' -recursive=false
		System.changeRights $DEFAULTGROUPPATH acmbsd acmbsd 'a=rX,ug+w' -recursive=false
		System.changeRights $ACMBSDPATH/scripts acmbsd acmbsd
		System.changeRights $SHAREDPATH shared acmbsd
		System.changeRights $ACMCM5PATH acmbsd acmbsd 'a=rX,ug+w'
		System.changeRights $ACMBSDPATH/db-template acmbsd acmbsd 'a=rX,ug+w'
		System.changeRights $ACMBSDPATH/data.conf acmbsd acmbsd
		System.changeRights $ACMBSDPATH/watchdog.log acmbsd acmbsd
		chmod 700 ${ACMBSDPATH}/.ssh && chmod 400 ${ACMBSDPATH}/.ssh/id_rsa && chmod 440 ${ACMBSDPATH}/.ssh/id_rsa.pub
		[ -f ${ACMBSDPATH}/.ssh/authorized_keys ] && chown acmbsd:acmbsd ${ACMBSDPATH}/.ssh/authorized_keys && chmod 640 ${ACMBSDPATH}/.ssh/authorized_keys
		for GROUPNAME in $GROUPS; do
			if Group.create $GROUPNAME instances && $GROUPNAME.isExist; then
				$GROUPNAME.setHierarchy
				for INSTANCE in `$GROUPNAME.getInstanceList`; do
					$INSTANCE.setHierarchy
				done
			fi
		done
	;;
	#COMMAND:DEVEL
	dnsreload)
		data.setTo GROUPNAME
		[ "$GROUPNAME" ] && Group.create $GROUPNAME || Syntax.checksites exit
		GROUPZONEDIR="`$GROUPNAME.getField PROTECTED`/export/dns"
		Named.reload
	;;
	#COMMAND:DEVEL
	dmesg)
		data.setTo PARAM1
		[ "$PARAM1" ] && Group.create ${PARAM1} && ${PARAM1}.isActive > /dev/null && PARAM1=$(${PARAM1}.getInstanceActive | cut -d' ' -f1)
		if Instance.create ${PARAM1} && ${PARAM1}.isExist && ${PARAM1}.isActive; then
			telnet $(${PARAM1}.getField INTIP) 14024
		else
			Syntax.telnet && exit 1
		fi
	;;
	#COMMAND:DEVEL
	ssh)
		data.setTo PARAM1
		[ "$PARAM1" ] && Group.create ${PARAM1} && ${PARAM1}.isActive > /dev/null && PARAM1=$(${PARAM1}.getInstanceActive | cut -d' ' -f1)
		if Instance.create ${PARAM1} && ${PARAM1}.isExist && ${PARAM1}.isActive; then
			ssh -p 14022 $(${PARAM1}.getField INTIP)
		else
			Syntax.telnet && exit 1
		fi
	;;
	#COMMAND:DEVEL
	telnet)
		data.setTo PARAM1
		[ "$PARAM1" ] && Group.create ${PARAM1} && ${PARAM1}.isActive > /dev/null && PARAM1=$(${PARAM1}.getInstanceActive | cut -d" " -f1)
		if Instance.create ${PARAM1} && ${PARAM1}.isExist && ${PARAM1}.isActive; then
			telnet $(${PARAM1}.getField INTIP) 14023
		else
			Syntax.telnet && exit 1
		fi
	;;
	#COMMAND:DEVEL
	vacuum)
		DBLIST="`/usr/local/bin/psql -tA -F' ' -U pgsql template1 -c 'SELECT datname FROM pg_database WHERE datistemplate = false;'`"
		for ITEM in $DBLIST; do
			echo "$ITEM..."
			echo 'VACUUM ANALYSE;' | /usr/local/bin/psql -U pgsql "$ITEM"
		done
	;;
	#COMMAND:DEVEL
	tools)
		Syntax.tools() {
			[ $2 ] && Group.create $GROUPNAME && $GROUPNAME.isExist && PUBLIC=`$GROUPNAME.getField PUBLIC` && echo 'Tools: '`ls $PUBLIC/tools | sed -l 's/.class//'`
			echo "Syntax: $0 tools {groupname} classname [args]"
			echo "Example:"
			printf "\t List of tools - $0 tools live"
			printf "\t Execute tool - $0 tools live CreateGuid"
			[ $1 ] && exit 1
		}
		data.setTo GROUPNAME CLASS P_ARGS +
		[ "$GROUPNAME" -a -z "$CLASS" ] && Syntax.tools exit info
		[ "$GROUPNAME" -a "$CLASS" ] && Group.create $GROUPNAME && $GROUPNAME.isExist || Syntax.tools exit
		PUBLIC=`$GROUPNAME.getField PUBLIC`
		CLASSPATH=`Java.classpath $PUBLIC/axiom`
		if [ -f "$PUBLIC/tools/$CLASS.class" ]; then
			/usr/local/bin/java -server -classpath $CLASSPATH:$PUBLIC/tools $CLASS $P_ARGS
			exit 0
		fi
		if [ -f "$PUBLIC/tools/$CLASS.jar" ]; then
			/usr/local/bin/java -server -classpath $CLASSPATH -jar "$PUBLIC/tools/$CLASS.jar" $P_ARGS
			exit 0
		fi
		echo "Not found: $CLASS (in $PUBLIC/tools/)"
		exit 1
	;;
	#COMMAND:NOTREADY
	cluster)
		case ${MODS} in
			activate)
				base.file.checkLine /etc/inetd.conf "^csync2*" "csync2 stream tcp nowait root /usr/local/sbin/csync2 csync2 -i -l"
				base.file.checkLine /etc/rc.conf inetd_enable=\"YES\"
				base.file.checkLine /etc/services "^csync2*" "csync2		30865/tcp"
				/etc/rc.d/inetd stop
				/etc/rc.d/inetd start
				cfg.setValue cluster true
			;;
			cron)
				ENABLE=`getSettingValue enable`
				test -z "$ENABLE" && Syntax.cluster && exit 1
				if [ "$ENABLE" = true -o "$ENABLE" = yes ]; then
					base.file.checkLine /etc/crontab csync "`csync.crontab`"
					/etc/rc.d/cron restart
				fi
				if [ "$ENABLE" = false -o "$ENABLE" = no ]; then
					cat /etc/crontab | sed -l "/csync2/d" > /tmp/crontab.tmp
					mv /tmp/crontab.tmp /etc/crontab
					/etc/rc.d/cron restart
				fi
			;;
			addto)
				HOST=`getSettingValue host`
				#IP=`getSettingValue ip`
				test -z "$HOST" && Syntax.cluster && exit 1
				if ssh -t $HOST "sudo acmbsd cluster localadd -host=$HOSTNAME -ip=$IP"; then
					ssh -t $HOST 'sudo cat /usr/local/etc/csync2.cfg' > /usr/local/etc/csync2.cfg
					chown root:wheel /usr/local/etc/csync2.cfg
					chmod 400 /usr/local/etc/csync2.cfg
					ssh -t $HOST 'sudo cat /etc/serverfarm.key' | tr -d '\015' > /etc/serverfarm.key
					chown root:wheel /etc/serverfarm.key
					chmod 400 /etc/serverfarm.key
					ssh -t $HOST "sudo acmbsd cluster csyncinit -host=$HOSTNAME"
					out.message 'Server ID: ' waitstatus && farm.getId && farm.init
				else
					out.error 'something wrong!'
				fi
			;;
			vpninit)
				out.message 'Server ID: ' waitstatus && farm.getId && farm.init
			;;
			connect)
				farm.connect
			;;
			sync)
				csync.sync
			;;
			forget)
				HOST=`getSettingValue host`
				test -z "$HOST" && Syntax.cluster && exit 1
				cluster_forget_query() {
					cat <<-EOF
						SELECT a.* FROM dirty AS a WHERE peername='$HOST';
						DELETE FROM dirty WHERE peername='$HOST';
						SELECT a.* FROM x509_cert AS a WHERE peername='$HOST';
						DELETE FROM x509_cert WHERE peername='$HOST';
					EOF
				}
				# echo "`cluster_forget_query`"
				sqlite3 /var/db/csync2/$HOSTNAME.db3 "`cluster_forget_query`"
			;;
			localadd)
				HOST=`getSettingValue host`
				test -z "$HOST" && Syntax.cluster && exit 1
				farm.listCheck $HOST
				out.message "Adding '$HOST' to csync2 config..." waitstatus
				if cat /usr/local/etc/csync2.cfg | fgrep -qw $HOST; then
					out.status green FOUND
				else
					cat /usr/local/etc/csync2.cfg | sed "s/#HOST_END/\\`echo -e '\t'`host $HOST;\\`echo -e '\n\r'`#HOST_END/g" > /tmp/csync2.cfg.tmp
					mv /tmp/csync2.cfg.tmp /usr/local/etc/csync2.cfg
					chown root:wheel /usr/local/etc/csync2.cfg
					chmod 400 /usr/local/etc/csync2.cfg
					out.status green ADDED
				fi
				#cat /etc/hosts | sed "s/#CLUSTER_END/$IP\\`echo -e '\t'`$HOST\\`echo -e '\n\r'`#CLUSTER_END/g" > /tmp/hosts.tmp
			;;
			csyncinit)
				HOST=`getSettingValue host`
				test -z "$HOST" && Syntax.cluster && exit 1
				csync.syncinit $HOST
			;;
			meetold)
#				if System.requirePermission ; then
#				fi
				if [ ! -f "${ACMBSDPATH}/.ssh/id_rsa" -o ! -f "${ACMBSDPATH}/.ssh/id_rsa.pub" ]; then
					su - acmbsd -c "ssh-keygen -q -N '' -f ${ACMBSDPATH}/.ssh/id_rsa -t rsa"
				fi
				cat ${ACMBSDPATH}/.ssh/id_rsa.pub
				#| ssh $(Console.getSettingValue user)@$(Console.getSettingValue host) "cat - >> ${ACMBSDPATH}/.ssh/authorized_keys"
			;;
			*)
				Syntax.cluster
			;;
		esac
	;;
	#COMMAND:DEVEL
	systemcheck)
		GROUPNAME=$2
		[ -z "$GROUPNAME" ] && out.error 'can not find group' && exit 1
		Group.create $GROUPNAME instances
		$GROUPNAME.debug
#		exit 1
#		GROUPNAME=temp
		echo && echo && echo Creating group...
		Group.create $GROUPNAME
		echo && echo && echo Adding instance...
		$GROUPNAME.add
		echo && echo && echo Starting instance
		$GROUPNAME.start
		echo && echo && echo 0
		$GROUPNAME.config -type=extended
		echo && echo && echo 1
		$GROUPNAME.config -type=extended
		echo && echo && echo 2
		$GROUPNAME.config -type=standard
		echo && echo && echo 3
		$GROUPNAME.config -extip=127.0.0.1
		echo && echo && echo 4
		$GROUPNAME.config -extip=188.93.48.6
		echo && echo && echo 5
		$GROUPNAME.debug
		$GROUPNAME.update -force -noalert && echo UPDATED || echo NOTHING
		$GROUPNAME.stop
		$GROUPNAME.remove
#		GROUPNAME=test
		$GROUPNAME.stop
		$GROUPNAME.update && echo UPDATED || echo NOTHING
		$GROUPNAME.update -force -noalert && echo UPDATED || echo NOTHING
		$GROUPNAME.start
		$GROUPNAME.restart -fast
		$GROUPNAME.restart -skipwarmup
		$GROUPNAME.restart
		$GROUPNAME.stop
	;;
	#COMMAND:DEVEL
	checkweb)
		data.setTo GROUPNAME
		Group.create $GROUPNAME
		$GROUPNAME.checkWeb
	;;
	#COMMAND:DEVEL
	csynchandler)
		# setPermission after csync
		data.setTo GROUPNAME FILES +
		Group.create $GROUPNAME
		echo "CHOWN ${GROUPNAME}1:$GROUPNAME" > /tmp/csynchandler.log
		chown -v ${GROUPNAME}1:$GROUPNAME ${FILES} >> /tmp/csynchandler.log
		echo "CHMOD 770" >> /tmp/csynchandler.log
		chmod -v 770 ${FILES} >> /tmp/csynchandler.log
		echo $FILES | grep sudoers > /dev/null 2> /dev/null && chmod 0440 /usr/local/etc/sudoers
		#mail.sendfile "/tmp/csynchandler.log" "Cluster '$GROUPNAME' synchandler log" "${FILES}"
	;;
	#COMMAND:DEVEL
	keep)
		System.waiting 60
	;;
	#COMMAND:DEVEL
	zonelist)
		Group.getData test
		zone.list
	;;
	#COMMAND:DEVEL
	zonelistdetail)
		Group.getData test
		zone.listdetail
	;;
	#COMMAND:DEVEL
	zonestatus)
		data.setTo GROUPNAME
		ID=`getSettingValue id`
		if [ -z "$GROUPNAME" -o -z "$ID" ]; then
			Syntax.zoneenable
		else
			Group.getData $GROUPNAME
			zone.isDisabled $ID
			case $? in
				0)
					echo DISABLED
					exit 0
				;;
				1)
					echo ENABLED
					exit 0
				;;
				10)
					echo NOT FOUND
					exit 0
				;;
			esac
		fi
	;;
	#COMMAND:DEVEL
	zoneenable)
		data.setTo GROUPNAME
		ID=`getSettingValue id`
		if [ -z "$GROUPNAME" -o -z "$ID" ]; then
			Syntax.zoneenable
		else
			Group.getData $GROUPNAME
			zone.enable $ID
		fi
	;;
	#COMMAND:DEVEL
	zonedisable)
		Group.getData test
		zone.disable com.vlapan
	;;
	#COMMAND:DEVEL
	devzone)
		Named.zonefile
	;;
	#COMMAND:DEVEL
	access)
		USERS='acmbsd'
		ADMIN=`cfg.getValue adminusers`
		[ "$ADMIN" ] && USERS="$USERS,$ADMIN"
		sys.usr.chk "$USERS"
		sys.grp.chk 'acmbsd shared'
		pw usermod acmbsd -d /usr/local/acmbsd
		pw groupmod acmbsd -M "$USERS"
		pw groupmod shared -M "$USERS"
		for GROUPNAME in $GROUPS; do
			Group.create $GROUPNAME && $GROUPNAME.isExist || continue
			sys.grp.chk $GROUPNAME
			pw groupmod $GROUPNAME -M $USERS
			for INSTANCE in `$GROUPNAME.getInstanceList`; do
				Instance.create $INSTANCE || continue
				sys.usr.chk $INSTANCE
				pw usermod $INSTANCE -d `$GROUPNAME.getField HOME`
				pw groupmod $GROUPNAME -m $INSTANCE
				pw groupmod shared -m $INSTANCE
				pw usershow $INSTANCE
			done
			pw groupshow $GROUPNAME
		done
		cat <<-EOF
			`pw groupshow acmbsd`
			`pw usershow acmbsd`
			`pw groupshow shared`
		EOF
		cat <<-EOF
			Users
				acmbsd: `id -Gn acmbsd | tr ' ' ','`
				live1: `id -Gn live1 | tr ' ' ','`
			Groups
				acmbsd: `pw groupshow acmbsd | cut -d: -f4`
				shared: `pw groupshow shared | cut -d: -f4`
				live: `pw groupshow live | cut -d: -f4`
		EOF
	;;
	*)
		Syntax.help
	;;
esac
exit 0
