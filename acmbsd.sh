#!/bin/sh
txtblk='\33[0;30m' # Black - Regular
txtred='\33[0;31m' # Red
txtgrn='\33[0;32m' # Green
txtylw='\33[0;33m' # Yellow
txtblu='\33[0;34m' # Blue
txtpur='\33[0;35m' # Purple
txtcyn='\33[0;36m' # Cyan
txtwht='\33[0;37m' # White
bldblk='\33[1;30m' # Black - Bold
bldred='\33[1;31m' # Red
bldgrn='\33[1;32m' # Green
bldylw='\33[1;33m' # Yellow
bldblu='\33[1;34m' # Blue
bldpur='\33[1;35m' # Purple
bldcyn='\33[1;36m' # Cyan
bldwht='\33[1;37m' # White
undblk='\33[4;30m' # Black - Underline
undred='\33[4;31m' # Red
undgrn='\33[4;32m' # Green
undylw='\33[4;33m' # Yellow
undblu='\33[4;34m' # Blue
undpur='\33[4;35m' # Purple
undcyn='\33[4;36m' # Cyan
undwht='\33[4;37m' # White
bakblk='\33[40m'   # Black - Background
bakred='\33[41m'   # Red
bakgrn='\33[42m'   # Green
bakylw='\33[43m'   # Yellow
bakblu='\33[44m'   # Blue
bakpur='\33[45m'   # Purple
bakcyn='\33[46m'   # Cyan
bakwht='\33[47m'   # White
txtrst='\33[0m'    # Text Reset

System.print.error() {
	printf "\33[1;31mError:\33[0m $@\n" && return 0
}
System.print.info() {
	printf "\33[1mInfo:\33[0m $@\n" && return 0
}
System.print.syntax() {
	printf "\33[1mSyntax:\33[0m"
	System.print.str "$@"
	return 0
}
System.print.example() {
	printf "\33[1mExample: $@\33[0m\n" && return 0
}
System.print.str() {
	printf "\t$SCRIPTNAME $@\n" && return 0
}
System.nextrelease() {
	System.print.error "feature not available, maybe next release!" && exit 1
}
System.setShutdown() {
	RCACM=$1
}
System.isShutdown() {
	[ "$RCACM" = true ] && return 0 || return 1
}
System.print.message.valuechange() {
	if [ "$4" ]; then
		echo -n "Changing value of '$1' setting for '$2' from '$4' to '$3'..."
	else
		echo -n "Changing value of '$1' setting for '$2' to '$3'..."
	fi
}
System.print.status() {
	if [ "$(echo $OPTIONS | fgrep -w verbose)" -o -z "$SIMPLEOUTPUT" ]; then
		case $1 in
			red) printf " [ \33[1;31m$2\33[0m ]\n";;
			green) printf " [ \33[1;32m$2\33[0m ]\n";;
			yellow) printf " [ \33[1;33m$2\33[0m ]\n";;
		esac
	else
		case $1 in
			red) printf "\33[0;31m;\33[0m";;
			green) printf "\33[0;32m:\33[0m";;
			yellow) printf "\33[0;33m|\33[0m";;
		esac
	fi
	return 0
}
System.message() {
	if [ "$(echo $OPTIONS | fgrep -w verbose)" -o -z "$SIMPLEOUTPUT" ]; then
		if [ waitstatus = "$2" ]; then
			echo -n $1
		else
			echo $1
		fi
	else
		if [ "$3" ]; then
			echo -n $3
		fi
	fi
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
		echo -n " }"
	fi
}
System.fs.dir.create() {
	System.message $1... waitstatus
	if [ -d $1 ]; then
		System.print.status green FOUND
	else
		if mkdir -p $1; then
			System.print.status green CREATED
		else
			System.print.status red ERROR && return 1
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
Ports.toUpdateList() {
	pkg_version -vIL= | fgrep -v diablo-j | fgrep -v postgresql
}
Ports.update() {
	echo -n Reciving and updateing ports tree...
	if [ -z "$AUTO" ]; then
		/usr/sbin/portsnap fetch > $PORTSUPDLOGFILE
	else
		/usr/sbin/portsnap cron > $PORTSUPDLOGFILE
	fi
	/usr/sbin/portsnap update >> $PORTSUPDLOGFILE
	System.print.status green DONE
	echo -n Check for new ports versions...
	NEW=`Ports.toUpdateList`
	if [ "$NEW" ]; then
		System.print.status green FOUND
		printf "\n$NEW\n\n" >> $PORTSUPDLOGFILE
		echo -n Updating ports...
		/usr/local/sbin/portupgrade -aRry --batch -x diablo-j* -x postgresql* >> $PORTSUPDLOGFILE 2> /dev/null
		System.print.status green DONE
		NEW=`Ports.toUpdateList`
		printf "\n\n$NEW\n" >> $PORTSUPDLOGFILE
		Network.message.send "`cat $PORTSUPDLOGFILE`" "ports updated" plain
	else
		System.print.status green "NO UPDATES"
	fi
}
System.update() {
	echo -n Reciving updates for your system version...
	if [ -z "$AUTO" ]; then
		/usr/sbin/freebsd-update fetch > $OSUPDLOGFILE
	else
		/usr/sbin/freebsd-update cron > $OSUPDLOGFILE
	fi
	if /usr/sbin/freebsd-update install >> $OSUPDLOGFILE; then
		System.print.status green INSTALLED
		System.print.info "restart your system!"
		Network.message.send "`cat $OSUPDLOGFILE`" "freebsd updates awaiting os restart" plain
	else
		System.print.status green "NO UPDATES"
	fi
}
System.updateAll() {
	if [ -n "$1" ]; then
		AUTO=$1
	fi
	Ports.update
	Java.pkg.install
	System.update
}
cfg.login.conf() {
	cat <<-EOF
		# Remember to rebuild the database after each change to this file:
		#       cap_mkdb /etc/login.conf
		default:\
						:passwd_format=md5:\
						:copyright=/etc/COPYRIGHT:\
						:welcome=/etc/motd:\
						:setenv=MAIL=/var/mail/$,BLOCKSIZE=K,FTP_PASSIVE_MODE=YES:\
						:path=/sbin /bin /usr/sbin /usr/bin /usr/games /usr/local/sbin /usr/local/bin ~/bin:\
						:nologin=/var/run/nologin:\
						:cputime=unlimited:\
						:datasize=unlimited:\
						:stacksize=unlimited:\
						:memorylocked=unlimited:\
						:memoryuse=unlimited:\
						:filesize=unlimited:\
						:coredumpsize=unlimited:\
						:openfiles=unlimited:\
						:maxproc=unlimited:\
						:sbsize=unlimited:\
						:vmemoryuse=unlimited:\
						:priority=0:\
						:ignoretime@:\
						:umask=002:\
						:charset=UTF-8:\
						:lang=en_US.UTF-8:
		#
		# A collection of common class names - forward them all to 'default'
		# (login would normally do this anyway, but having a class name
		#  here suppresses the diagnostic)
		#
		standard:\
						:tc=default:
		xuser:\
						:tc=default:
		staff:\
						:tc=default:
		daemon:\
						:tc=default:
		news:\
						:tc=default:
		dialer:\
						:tc=default:
		#
		# Root can always login
		#
		# N.B.  login_getpwclass(3) will use this entry for the root account,
		#       in preference to 'default'.
		root:\
						:ignorenologin:\
						:tc=default:
	EOF
}
cfg.screenrc() {
	cat <<-EOF
		altscreen on
		startup_message off
	EOF
}
cfg.nanorc() {
	cat <<-EOF
		set historylog
		set nowrap
		set smooth
		set suspend
		set tabsize 4
		# set softwrap
		include "/usr/local/share/nano/nanorc.nanorc"
		include "/usr/local/share/nano/css.nanorc"
		include "/usr/local/share/nano/html.nanorc"
		include "/usr/local/share/nano/patch.nanorc"
		include "/usr/local/share/nano/man.nanorc"
		include "/usr/local/share/nano/java.nanorc"
		include "/usr/local/share/nano/awk.nanorc"
		include "/usr/local/share/nano/sh.nanorc"
		include "/usr/local/share/nano/xml.nanorc"
		include "/usr/local/share/nano/makefile.nanorc"
	EOF
}
cfg.profile() {
	cat <<-EOF
		umask 002
		export HISTCONTROL=ignoreboth
		export CLICOLOR="YES"
		export LSCOLORS="ExGxFxdxCxDxDxhbadExEx"
		export GREP_OPTIONS='--color=auto'
		export GREP_COLOR='00;38;5;157'
		export INPUTRC=/etc/inputrc
		[ -x /usr/local/bin/screen ] && [ "\$TERM" != screen ] && (
			export PS1='\[\e[0;32m\]\u@\h\[\e[m\]:\[\e[0;34m\]\w\[\e[m\]\[\e[0;32m\]\$\[\e[m\] \[\e[0m\]'
			/usr/local/bin/screen -s /usr/local/bin/bash -q -O -U -D -R
		)
	EOF
}
cfg.inputrc() {
	cat <<-EOF
		set mark-symlinked-directories on
	EOF
}
Database.h2.backupAll() {
	System.nextrelease
	for ITEM in `ls $DBDIR | cut -d. -f1-2 | uniq`; do
		Database.h2.backup $ITEM
	done
}
Database.h2.backup() {
	System.nextrelease
	java -cp $PUBLIC/axiom/h2-*.jar org.h2.tools.Script -url jdbc:h2:$DBDIR/$ITEM -user sa -script $BACKUPDIR/$ITEM/$ITEM.zip -options compression zip;
}
Database.h2.restore() {
	System.nextrelease
	java -cp $PUBLIC/axiom/h2-*.jar org.h2.tools.RunScript -url jdbc:h2:$DBDIR/$ITEM -user sa -script $BACKUPDIR/$ITEM/$ITEM.zip -options compression zip;
}
Database.check() {
	echo '\q' | psql $1 pgsql > /dev/null 2>&1 && return 0 || return 1
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
	psql -tA -c "select pg_size_pretty(pg_database_size('$1'))" postgres pgsql | tr -d ' ' | tr -d 'B' | tr 'k' 'K'
}
Database.counter.set() {
	TABLE=`echo $2 | cut -d_ -f1`
	FIELD=`echo $2 | cut -d_ -f2`
	psql -tA -c "select setval('${2}_seq', (select max($FIELD) from $TABLE))" $1 pgsql
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
	System.print.status green OK
}
Database.template.update() {
	System.message "Fetching db-template..." waitstatus
	if Network.cvs.fetch /var/ae3 db-template ae3/distribution/acm.cm5/bsd/db-template > /dev/null 2>&1 ; then
		System.print.status green DONE
	else
		System.print.status red FAILED
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
	cvs -d :pserver:guest:guest@cvs.myx.ru:$1 -fq -z 6 checkout -d $2 $3 && return 0 || return 1
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
	local BUSYIP="$(Config.setting.getValue extip)"
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
	System.message "Check for '$3' IP-address on '$2' interface..." waitstatus
	if /sbin/ifconfig | fgrep -qw $3; then
		if [ "$1" = bind ]; then
			System.print.status yellow FOUND
		else
			/sbin/ifconfig $2 inet $3 -alias > /dev/null 2>&1
			System.print.status green UNALIASED
		fi
	else
		if [ "$1" = bind ]; then
			/sbin/ifconfig $2 inet $3 netmask $NETMASK alias > /dev/null 2>&1
			System.print.status green ALIASED
		else
			System.print.status yellow "NOT FOUND"
		fi
	fi
	return 0
}
paramcheck() {
	[ ! -f "$1" ] && touch $1
	System.message "Check for '$2' in '$1'..." waitstatus
	if cat $1 | grep -q "$2"; then
		System.print.status green FOUND
	else
		if [ "$3" ]; then
			echo $3 >> $1
		else
			echo $2 >> $1
		fi
		System.print.status green ADDED
	fi
}
killbylockfile() {
	#TODO: print.warning
	[ ! -e "$1" ] && System.print.info "Unable to find lock file ($1)" && return 1
	local PID=`cat $1`
	if [ -z "$2" ]; then
		System.message "Removing lock file ($1)..." waitstatus
		rm $1 > /dev/null 2>&1 && System.print.status green DONE || System.print.status red FAILED
	fi
	System.message "Trying to kill gracefully ($PID)..." waitstatus
	kill $PID > /dev/null 2>&1
	System.print.status green DONE
	System.message "Waiting for instance to die" waitstatus
	local COUNT=0
	while true; do
		if [ $COUNT = 60 ]; then
			System.print.status yellow "STILL ALIVE"
			System.message "Trying to kill(9) ($PID)..." waitstatus
			kill -9 $PID > /dev/null 2>&1
			System.print.status red KILLED
			break;
		fi
		sleep 1
		if ! System.daemon.isExist $PID; then
			System.print.status green DIED
			break;
		fi
		COUNT=$((COUNT + 1))
		echo -n .
	done
}
scriptlink() {
	[ -e "$2" ] || return 1
	System.message "Link '$2' to '$1'..." waitstatus
	ln -f $2 $1
	System.print.status green DONE
	System.message "Change rights for '$1'..." waitstatus
	chown acmbsd:acmbsd $1 && chmod 0774 $1
	System.print.status green DONE
	return 0
}
pkgcheck() {
	[ "$PKGINFO" ] || PKGINFO=`pkg_info`
	System.message "Check for $1..." waitstatus
	if echo "$PKGINFO" | fgrep -Lq $1; then
		System.print.status green FOUND
	else
		System.print.status yellow "NOT FOUND"
		System.message "Installing $1..."
		cd /usr/ports/$2 && make clean && make install clean
		System.message "Check for $1..." waitstatus
		PKGINFO=`pkg_info`
		if echo "$PKGINFO" | fgrep -Lq $1; then
			System.print.status green FOUND
		else
			System.print.status red ERROR
			exit 1
		fi
	fi
}
System.changeRights() {
	OPTS="$@"
	local RSTR=`Function.getSettingValue recursive "$OPTS"`
	local REQURSIVE=`([ "$RSTR" ] && [ "$RSTR" = false -o "$RSTR" = no -o "$RSTR" = 0 ]) || echo '-R'`
	[ ! -d "$1" -o -z "$2" ] && return 1
	if ! pw usershow $3 > /dev/null 2>&1; then
		System.print.error "no user '$3'!"
		return 1
	fi
	if ! pw groupshow $2 > /dev/null 2>&1; then
		System.print.error "no group '$2'!"
		return 1
	fi
	[ "$4" ] && RIGHTS=$4 || RIGHTS='ug=rwX,o='
	System.message "Modifying FS rights (dir:$1,user:$3,group:$2,rights:$RIGHTS,o:$REQURSIVE)..." waitstatus
	#TODO: change to find
	chown $REQURSIVE $3:$2 $1 && chmod $REQURSIVE $RIGHTS $1
	System.print.status green DONE && return 0
}
cvsacmcm() {
	ONLYCHECK=$3
	System.fs.dir.create $ACMCM5PATH > /dev/null 2>&1
	cd $ACMCM5PATH
	System.message "Fetching ACM.CM5 (sys-$1) version..." waitstatus
	if Network.cvs.fetch /var/share tmp export/sys-$1/version/version > /dev/null 2>&1 ; then
		System.print.status green DONE
	else
		System.print.status red FAILED
		RETVAL=1
	fi
	if [ -f tmp/version ]; then
		CVSVERSION=`cat tmp/version`
		if [ "${CVSVERSION}" ]; then
			if [ "$(echo ${OPTIONS} | fgrep -w force)" -o -z "${ONLYCHECK}" -a ${2} != ${CVSVERSION} ]; then
				System.message "ACM.CM5 (sys-${1}) version: Latest - '${CVSVERSION}', Local - '${2}'"
				System.message "Fetching latest ACM.CM5 (sys-${1})..."
				if Network.cvs.fetch /var/share ${1} export/sys-${1} ; then
					System.message "Finish..." waitstatus
					System.print.status green "OK"
				else
					System.message "Finish..." waitstatus
					System.print.status red "ERROR"
					RETVAL=1
				fi
			else
				System.message "ACM.CM5 (sys-${1}) version already updated to ${CVSVERSION}"
			fi
		fi
	fi
	rm -rdf tmp
}
Config.reload() {
	if [ -f $DATAFILE ]; then
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
Config.setting.remove() {
	[ $1 ] && DATA=`echo "$DATA" | sed -l "/$1/d"` && echo "$DATA" > $DATAFILE && return 0 || return 1
}
Config.setting.setValue() {
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
Config.setting.getValue() {
	[ $1 ] && TMPDATA=`echo -n "$DATA" | fgrep -w $1` || return 1
	echo -n "$TMPDATA" | cut -d= -f2 && return 0 || return 1
}
Console.isSettingExist() {
	echo "$SETTINGS" | fgrep -qw $1 && return 0 || return 1
}
Console.getSettingValue() {
	FILTEREDSETTINGS=`echo "$SETTINGS" | fgrep -w $1`
	for ITEM in $FILTEREDSETTINGS; do
		echo $ITEM | cut -d= -f2 && return 0
	done
	return 1
}
Console.isOptionExist() {
	echo $OPTIONS | fgrep -qw $1 && return 0 || return 1
}
Function.getSettingValue() {
	FILTEREDSETTINGS=$(echo "$2" | fgrep -w $1)
	for ITEM in $FILTEREDSETTINGS; do
		if echo $ITEM | fgrep -q =; then
			if [ "$(echo $ITEM | cut -d= -f1)" = "-$1" ]; then
				echo $ITEM | cut -d= -f2 && return 0
			fi
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
Group.create() {
	#Options:	1 - Group name
	local THIS=$1
	[ "$THIS" ] && Group.isGroup $THIS || return 1
	Function.isExist $THIS.isObject && return 0
	local EVAL="`sed s/THIS/$THIS/g $ACMBSDPATH/scripts/group.sh`"
	Object.create $THIS group "$EVAL"
	[ "$2" ] && $THIS.createInstances
	return 0
}
Instance.create() {
	#Options:	1 - Instance name
	local THIS=$1
	#TODO: check isInstance
	[ "$THIS" ] || return 1
	local GROUPNAME=`echo $THIS | tr -d '[0-9]'`
	Group.isGroup $GROUPNAME || return 1
	Function.isExist $GROUPNAME.isObject || Group.create $GROUPNAME
	Function.isExist $THIS.isObject && return 0
	local EVAL="`sed s/THIS/$THIS/g $ACMBSDPATH/scripts/instance.sh`"
	Object.create $THIS instance "$EVAL"
	return 0
}
getClusterId() {
	#TODO: check
	[ -z $CLUSTERIDCOUNT ] && CLUSTERIDCOUNT=0
	case ${1} in
		*)
			echo $((100+$CLUSTERIDCOUNT))
		;;
	esac
}
System.cooldown() {
	System.message 'Cooldown...' waitstatus
	local COUNT=0
	while true
	do
		COUNT=$((COUNT + 1))
		if [ ${COUNT} = 10 ]; then
			System.print.status green DONE
			break;
		fi
		sleep 1
		echo -n .
	done
}
Group.static() {
	Group.updateAll() {
		for GROUPNAME in $GROUPS; do
			Group.create $GROUPNAME && $GROUPNAME.isExist && $GROUPNAME.update
		done
	}
	Group.startAll() {
		for GROUPNAME in $1; do
			Group.create $GROUPNAME && $GROUPNAME.isExist && $GROUPNAME.start
		done
		Watchdog.check
	}
	Group.stopAll() {
		for GROUPNAME in $1; do
			Group.create $GROUPNAME && $GROUPNAME.isExist && $GROUPNAME.stop
		done
		Watchdog.check
	}
	Group.getData() {
		if [ "$1" ]; then
			GROUPNAME=$1
		fi
		if Group.isGroup $GROUPNAME && Group.isExist $GROUPNAME ; then
			GROUPID="$(Group.default.id ${GROUPNAME})"
			GROUPPATH=${DEFAULTGROUPPATH}/${GROUPNAME}
			PUBLIC=${GROUPPATH}/public
			PUBLICBACKUP=${GROUPPATH}/public-backup
			PROTECTED=${GROUPPATH}/protected
			LOGS=${GROUPPATH}/logs
			SERVERSCONF=${PROTECTED}/conf/servers.xml
			WEB=${PROTECTED}/web
			if [ -f ${GROUPPATH}/public/version/version ]; then
				ACMVERSION=$(cat ${GROUPPATH}/public/version/version)
			else
				ACMVERSION=0
			fi
			MEMORY=$(Config.setting.getValue "${GROUPNAME}-memory")
			EXTIP=$(Config.setting.getValue "${GROUPNAME}-extip")
			TYPE=$(Config.setting.getValue "${GROUPNAME}-type")
			BRANCH=$(Config.setting.getValue "${GROUPNAME}-branch")
			INSTANCELIST=$(ls $GROUPPATH | fgrep -w private | cut -d- -f1)
			Group.instances.getActive
			INSTANCESCOUNT=$(echo ${INSTANCELIST} | wc -w | tr -d ' ')
			return 0
		fi
		return 1
	}
	Group.groups.getActive() {
		[ -z "$ACTIVATEDGROUPS" -o "$1" ] && ACTIVATEDGROUPS=`echo "$DATA" | grep -w activated | cut -d- -f1`
		echo $ACTIVATEDGROUPS
	}
	Group.groups.getStatus() {
		printf "Groups list: available (\33[1m${GROUPS}\33[0m), active (\33[1m${ACTIVATEDGROUPS}\33[0m)\n"
	}
	Group.instances.getActive() {
		ACTIVEINSTANCES=""
		local ITEM
		for ITEM in ${INSTANCELIST}; do
			local ITEMPRIVATE=${GROUPPATH}/${ITEM}-private
			local ITEMDAEMONFLAG=${ITEMPRIVATE}/daemon.flag
			if [ -f ${ITEMDAEMONFLAG} ]; then
			 	if [ -z "${ACTIVEINSTANCES}" ]; then
					ACTIVEINSTANCES="${ITEM}"
			 	else
			 		ACTIVEINSTANCES="${ACTIVEINSTANCES} ${ITEM}"
			 	fi
			fi
		done
	}
	Group.default.id() {
		case $1 in
			live)
				echo 20
			;;
			test)
				echo 40
			;;
			devel)
				echo 60
			;;
			temp)
				echo 80
			;;
			*)
				echo 100
		esac
	}
	Group.default.loglevel() {
		case $1 in
			live)
				echo NORMAL
			;;
			test)
				echo DEBUG
			;;
			devel)
				echo DEVEL
			;;
			*)
				echo DEBUG
		esac
	}
	Group.default.ea() {
		echo $1 | fgrep -qw live && echo disable || echo enable
	}
	Group.default.branch(){
		echo $1 | fgrep -qw live && echo stable || echo release
	}
	Group.reset() {
		rm -rdf $PROTECTED/boot.properties
		for INSTANCE in $INSTANCELIST; do
			$INSTANCE.reset
		done
	}
	Group.isDigit() {
		echo 1 2 3 4 5 6 7 8 9 | fgrep -qw $1 && return 0 || return 1
	}
	Group.isGroup() {
		[ "$1" ] && echo $GROUPSNAME | fgrep -qw $1 && return 0 || return 1
	}
	Group.isBranch() {
		echo stable release current | fgrep -qw $1 && return 0 || return 1
	}
	Group.isLogLevel() {
		echo NORMAL DEBUG DEVEL MINIMAL | fgrep -qw $1 && return 0 || return 1
	}
	Group.isType() {
		echo minimal standard extended parallel | fgrep -qw $1 && return 0 || return 1
	}
	Group.isEA() {
		echo enable disable | fgrep -qw $1 && return 0 || return 1
	}
	Group.isMemory() {
		echo $1 | fgrep -qoE "\b([0-9]*?)m\b" && return 0 || return 1
	}
	Group.isExist() {
		[ "$2" = passAll -a "$1" = all ] && return 0
		[ -z "$1" -o -z "`echo $GROUPS | fgrep -w $1`" ] || return 0
		System.print.error "given group '$1' is not exist!"
		return 1
	}
	Group.isActive() {
		[ "$2" = passAll -a "$1" = all ] && return 0
		echo `Group.groups.getActive` | fgrep -qw $1 && return 0
		System.print.error "given group '$1' is not active!"
		return 1
	}
	Group.isPassive() {
		echo `Group.groups.getActive` | fgrep -qw $1 || return 0
		System.print.error "given group '$1' is active!"
		return 1
	}
	return 0
}
Instance.static() {
	Instance.getData() {
		if [ "${1}" ]; then
			INSTANCE=${1}
		fi
		PRIVATE=${GROUPPATH}/${INSTANCE}-private
		ACMOUT=${LOGS}/stdout-${INSTANCE}
		ACMOUTLAST=${LOGS}/stdout-${INSTANCE}.prev
		RESTARTFILE=${PRIVATE}/control/restart
		DAEMONFLAG=${PRIVATE}/daemon.flag
		if [ -f ${DAEMONFLAG} ]; then
			DAEMONPID=$(cat ${DAEMONFLAG})
		fi
		INSTANCENUMBER=$(echo ${INSTANCE} | tr -d "[a-z]")
		INTIP="172.16.0.$((${GROUPID}+${INSTANCENUMBER}-1))"
	}
	Instance.isExist() {
		[ "$2" = "passAll" -a "$1" = "all" ] && return 0
		[ -z "$1" -o -z "`echo $INSTANCELIST | fgrep -w $1`" ] || return 0
		System.print.error "given instance '$1' do not exist!"
		return 1
	}
	return 0
}
Watchdog.start(){
	System.message "Starting watchdog process..." waitstatus
	/usr/sbin/daemon -p $WATCHDOGFLAG $0 watchdog > $ACMBSDPATH/watchdog.log 2>&1
	System.print.status green DONE
}
Watchdog.check() {
	if [ -e "$WATCHDOGFLAG" ]; then
		System.message "Check for watchdog process..." waitstatus
		if ! System.daemon.isExist `cat $WATCHDOGFLAG`; then
			System.print.status yellow "NOT FOUND"
			rm $WATCHDOGFLAG
			Watchdog.start
		else
			System.print.status green FOUND
		fi
	else
		Watchdog.start
	fi
}
Watchdog.restart() {
	if [ -e "$WATCHDOGFLAG" ]; then
		System.message "Check for watchdog process..." waitstatus
		if ! System.daemon.isExist `cat $WATCHDOGFLAG`; then
			System.print.status yellow "NOT FOUND"
			rm $WATCHDOGFLAG
			Watchdog.start
		else
			System.print.status green FOUND
			System.message "Killing watchdog process..." waitstatus
			kill `cat $WATCHDOGFLAG`
			rm $WATCHDOGFLAG
			System.print.status green DONE
			Watchdog.start
		fi
	else
		Watchdog.start
	fi
}
Watchdog.command() {
	while true; do
		sleep 3
		if [ ! -f $WATCHDOGFLAG ]; then
			exit 1
		fi
		Config.reload
		ACTIVATEDGROUPS=`Group.groups.getActive fresh`
		for GROUPNAME in $ACTIVATEDGROUPS; do
			Group.create $GROUPNAME
			$GROUPNAME.cluster.dataCheck
			GROUPZONEDIR=`$GROUPNAME.getField PROTECTED`/export/dns
			NAMEDRELOADCKSUM=`eval echo '$NAMEDRELOADCKSUM'$GROUPNAME`
			[ -z "$NAMEDRELOADCKSUM" ] && NAMEDRELOADCKSUM=`Config.setting.getValue $GROUPNAME-dnsreloadcksum`
			NAMEDRELOADFILE=$GROUPZONEDIR/.reload
			local CKSUM=`ls -lT $NAMEDRELOADFILE | md5 -q`
			if [ "$NAMEDRELOADCKSUM" != "$CKSUM" ]; then
				date > $NAMEDRELOADFILE
				chown :$GROUPNAME $NAMEDRELOADFILE
				Named.reload
				CKSUM=`ls -lT $NAMEDRELOADFILE | md5 -q`
				eval "NAMEDRELOADCKSUM$GROUPNAME='$CKSUM'"
				Config.setting.setValue $GROUPNAME-dnsreloadcksum "$CKSUM"
			fi
			echo
			echo "Active instances: "`$GROUPNAME.getInstanceActive`
			for INSTANCE in `$GROUPNAME.getInstanceActive`; do
				Instance.create $INSTANCE
				echo -n "Check for '$INSTANCE'..."
				if System.daemon.isExist `$INSTANCE.getPID`; then
					System.print.status green ONLINE
				else
					System.print.status yellow OFFLINE
					if [ -f `$INSTANCE.getField RESTARTFILE` ]; then
						System.print.info "instance crash detected!"
						FAILS=`Config.setting.getValue $GROUPNAME-fails`
						LASTFAIL=`Config.setting.getValue $GROUPNAME-lastfail`
						test "$FAILS" && FAILS=$(($FAILS+1)) || FAILS=1
						Config.setting.setValue $GROUPNAME-fails "$FAILS" && Config.setting.setValue $GROUPNAME-lastfail `date +%s`
						if [ "$LASTFAIL" ]; then
							local TIME = $(($(date +%s)-${LASTFAIL}))
							echo $TIME
						fi
						Network.message.send2 "`$GROUPNAME.getField LOGS`/stdout-$INSTANCE" "daemon '$GROUPNAME' instance crash detected" "global fail count: $FAILS, last fail $TIME seconds ago"
					fi
					$INSTANCE.startDaemon
				fi
			done
		done
		SERVICETIME=`Config.setting.getValue autotime`
		LASTSERVICETIME=`Config.setting.getValue lastautotime`
		DAY=`date +%d`
		if [ "$DAY" != "$LASTSERVICETIME" -a "`date +%H:%M`" = "$SERVICETIME" ]; then
			Config.setting.setValue lastautotime $DAY
			$0 service > /tmp/acmbsd.service.log &
		fi
	done
}
Network.message.send() {
	OPTS=$@
	ADMINMAIL=`Function.getSettingValue email "$OPTS" || Config.setting.getValue adminmail`
	[ $ADMINMAIL ] || return 1
	for EMAIL in $ADMINMAIL; do
		printf "To: $EMAIL\n" > /tmp/msg.html
		printf "Subject: ACMBSD on `uname -n`: $2\n" >> /tmp/msg.html
		printf "Content-Type: text/$3; charset=\"us-ascii\"\n\n" >> /tmp/msg.html
		echo "$1" >> /tmp/msg.html
		echo -n "Sending email to '$EMAIL'..."
		if /usr/sbin/sendmail -f acmbsd $EMAIL < /tmp/msg.html; then
			System.print.status green DONE
		else
			System.print.status red FAILED
		fi
	done
}
Network.message.send2() {
	ADMINMAIL=$(Config.setting.getValue adminmail)
	[ $ADMINMAIL ] || return 1
	SUBJECT="ACMBSD on `uname -n`: $2"
	echo $3 > /tmp/msgbody
	for MAILTO in $ADMINMAIL; do
		metasend -b -s "$SUBJECT" -f /tmp/msgbody -m text/plain -e none -n -f $1 -m text/plain -e base64 -t $MAILTO
	done
}
Script.update.check() {
	cd $ACMBSDPATH
	rm -rdf tmp
	mkdir -p tmp
	System.message "Fetching ACMBSD version from CVS..." waitstatus
	if Network.cvs.fetch /var/ae3 tmp acm-install-freebsd/scripts/version > /dev/null 2>&1 ; then
		System.print.status green DONE
		CVSVERSION=`cat tmp/version`
		rm -rdf tmp
	else
		System.print.status red FAILED
	fi
	if [ "$CVSVERSION" ]; then
		System.message "ACMBSD version: Latest - '$CVSVERSION', Local - '$VERSION'"
		if [ ! -e "$ACMBSDPATH/scripts/acmbsd.sh" -o $CVSVERSION -gt $VERSION -o "$(echo $OPTIONS | fgrep -w now)" ]; then
			return 0
		fi
	fi
	return 1
}
Script.update.fetch () {
	System.message "Fetching ACMBSD..." waitstatus
	if Network.cvs.fetch /var/ae3 scripts acm-install-freebsd/scripts > /dev/null 2>&1 ; then
		System.print.status green DONE
		chmod 775 $ACMBSDPATH/scripts/acmbsd.sh
		System.message "Running 'acmbsd install -noupdate'..." waitstatus
		if $ACMBSDPATH/scripts/acmbsd.sh install -noupdate > /dev/null 2>&1 ; then
			System.print.status green DONE
			Network.message.send "<html><p>acmbsd script updated from '<b>$VERSION</b>' to '<b>$CVSVERSION</b>' version</p></html>" "acmbsd script updated" html
		else
			System.print.status red FAILED
		fi
	else
		System.print.status red FAILED
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
			System.print.status green OK
		else
			if pw groupadd -n $ITEM > /dev/null 2>&1; then
				System.print.status green ADDED
			else
				System.print.status red ERROR && return 1
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
			System.print.status green OK
		else
			if pw useradd -n $ITEM -h - > /dev/null 2>&1; then
				System.print.status green ADDED
			else
				System.print.status red ERROR && return 1
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
getacmversions() {
	ACMCURRENTVERSION=$(System.fs.file.get ${ACMCURRENTVERSIONFILE} 0)
	ACMRELEASEVERSION=$(System.fs.file.get ${ACMRELEASEVERSIONFILE} 0)
	ACMSTABLEVERSION=$(System.fs.file.get ${ACMSTABLEVERSIONFILE} 0)
	ACMCURRENTDATE=$(getfiledate ${ACMCURRENTVERSIONFILE})
	ACMRELEASEDATE=$(getfiledate ${ACMRELEASEVERSIONFILE})
	ACMSTABLEDATE=$(getfiledate ${ACMSTABLEVERSIONFILE})
}
getSettingValue() {
	FILTEREDSETTINGS=`echo "$SETTINGS" | fgrep -w $1`
	RETVAL=1
	for ITEM in $FILTEREDSETTINGS; do
		echo $ITEM | cut -d= -f2 && RETVAL=0
		[ $2 ] && break
	done
	return $RETVAL
}
parseOpts() {
	for ITEM in $@; do
		if [ $ITEM = $COMMAND ]; then
			continue
		fi
		if echo $ITEM | fgrep -q -; then
			if echo $ITEM | fgrep -q =; then
				if [ "$SETTINGS" ]; then
					SETTINGS="$SETTINGS"`printf "\n$ITEM"`
				else
					SETTINGS=$ITEM
				fi
			else
				if [ "$OPTIONS" ]; then
					OPTIONS="$OPTIONS $ITEM"
				else
					OPTIONS=$ITEM
				fi
			fi
			continue
		fi
		if [ "$MODS" ]; then
			MODS="$MODS $ITEM"
		else
			MODS=$ITEM
		fi
	done
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
Java.pkg.update() {
	DEPENDS=$(pkg_info -r /usr/ports/distfiles/$FILENAME | grep Dependency | cut -d' ' -f2 | cut -d- -f1)
	echo -n "Installing depends ("$DEPENDS")..."
	for ITEM in $DEPENDS; do
		portinstall $ITEM > /dev/null 2>&1
	done
	System.print.status green DONE
	
	if [ -z "$1" ]; then
		echo -n "Check for 'diablo java' installed package..."
		PKGNAME=$(pkg_info | grep diablo-j | cut -d' ' -f1)
		if [ "$PKGNAME" ]; then
			System.print.status green FOUND
			echo -n "Delete installed java package..."
			pkg_delete $PKGNAME > /dev/null 2>&1
			System.print.status green DONE
		else
			System.print.status yellow "NOT FOUND"
		fi
	fi
	echo -n Install new java package...
	printf "yes\n\n" | pkg_add /usr/ports/distfiles/$FILENAME > /dev/null
	System.print.status green DONE
}
Java.pkg.fetch() {
	URI=http://www.freebsdfoundation.org/cgi-bin/download
	CODE=`curl $URI?download=$FILENAME 2> /dev/null | fgrep clickthroughcode | cut -d= -f4 | cut -d\" -f2`
	echo "Getting java package '$FILENAME'..."
	curl -d clickthroughcode=$CODE -d iagree=1 -d download=$FILENAME $URI/$FILENAME > /usr/ports/distfiles/$FILENAME
	SHAHASH=$(/sbin/sha256 -q /usr/ports/distfiles/$FILENAME)
	if ! echo "$CHECKSUMPAGE" | fgrep -q $SHAHASH; then
		return 1
	fi
}
Java.pkg.install() {
	echo -n "Getting checksum page from 'www.freebsdfoundation.org'..."
	CHECKSUMPAGE=`curl -s http://www.freebsdfoundation.org/downloads/checksum.shtml`
	System.print.status green DONE
	if [ $OSMAJORVERSION = 8 ]; then
		OSVERSION=7
		echo "[/usr/local/diablo-jre1.6.0/]" > /etc/libmap.conf
		echo "libz.so.4	libz.so.5" >> /etc/libmap.conf
	else
		OSVERSION=$OSMAJORVERSION
	fi
	FILENAME=$(echo "$CHECKSUMPAGE" | fgrep jre-freebsd$OSVERSION.$ARCH | cut -d'>' -f2 | cut -d'<' -f1)
	if [ -z "$CHECKSUMPAGE" -o -z "$FILENAME" ]; then
		System.print.info "Filename: "$FILENAME
		System.print.error "faild to parse filename, maybe there is no java for your arch or it can be network error"
		exit 1
	fi
	echo -n "Check for diablo JRE file..."
	if [ -f "/usr/ports/distfiles/$FILENAME" ]; then
		System.print.status green FOUND
		SHAHASH=$(/sbin/sha256 -q /usr/ports/distfiles/$FILENAME)
		echo -n "Check diablo JDK file against SHA256 hash..."
		if echo "$CHECKSUMPAGE" | fgrep -q $SHAHASH; then
			System.print.status green CORRECT
			echo -n "Check for 'diablo-jre' installed package..."
			PKGNAME=$(pkg_info | fgrep diablo-jre | cut -d' ' -f1)
			if [ -z "$PKGNAME" ]; then
				System.print.status yellow "NOT FOUND"
				Java.pkg.update nopkgcheck
			else
				System.print.status green FOUND
			fi
		else
			System.print.status red BROKEN
			Java.pkg.fetch && Java.pkg.update
		fi
	else
		System.print.status yellow "NOT FOUND"
		Java.pkg.fetch && Java.pkg.update
	fi
}
domainchecker() {
	echo -n "Try to resolve hostname '$1'..."
	IPADDR=`host $1 | head -n 1 | cut -d' ' -f4`
	if [ "$IPADDR" = "found:" ]; then
		System.print.status red ERROR
		return 1
	else
		if [ "$IPADDR" = alias ]; then
			IPADDR=`host $1 | awk 'NR==2{print $0}' | cut -d' ' -f4`
		fi
		if echo $EXTIP | fgrep -q $IPADDR; then
			System.print.status green $IPADDR
		else
			System.print.status red $IPADDR
			return 1
		fi
	fi
	echo -n "Try to get request from http server on '$1'..."
	RESPONSECODE=`curl -I $1 2> /dev/null | head -n 1 | cut -d' ' -f2`
	if [ "$RESPONSECODE" ]; then
		if [ $RESPONSECODE = 401 ]; then
				System.print.status red $RESPONSECODE
			else
				System.print.status green $RESPONSECODE
			fi
	else
		System.print.status red FAIL
	fi
	return 0
}
domainschecker() {
	DOMAINSDATA=$(cat ${SERVERSCONF} | fgrep -w server)
	if echo "${DOMAINSDATA}" | fgrep -v " />" | fgrep -v " -->" > /dev/null 2>&1 ; then
		System.print.error "broken servers.xml in '${GROUPNAME}' group"
		continue
	fi
	for ITEM in ${DOMAINSDATA}; do
		if [ "$(echo ${ITEM} | fgrep =)" ]; then
			case "$(echo ${ITEM} | cut -d '=' -f 1)" in
				id)
					VALUE=$(echo ${ITEM} | cut -d "=" -f 2 | tr -d "'" | tr -d '"')
					echo
					echo -n "${VALUE}"
					DOMAINDATA=$(echo "${DOMAINSDATA}" | fgrep -w ${VALUE})
					if [ "$(echo ${DOMAINDATA} | grep '\!--')" ]; then
						echo -n " disabled"
						ENABLE=false
					else
						echo -n " enabled"
						ENABLE=true
					fi
					echo " domain."
				;;
				entrance)
					VALUE=$(echo ${ITEM} | cut -d "=" -f 2 | tr -d "'" | tr -d '"')
					if [ "${VALUE}" ]; then
						echo "Found entrance '${VALUE#http://}'."
						domainchecker ${VALUE#http://}
					fi
				;;
				aliases)
					VALUE=$(echo ${ITEM} | cut -d "=" -f 2 | tr -d "'" | tr -d '"')
					if [ "${VALUE}" ]; then
						for ALIAS in $(echo ${VALUE} | tr ";" " "); do
							if echo ${ALIAS#*.} | fgrep . > /dev/null 2>&1 ; then
								if ! echo ${ALIAS#*.} | fgrep .test > /dev/null 2>&1 ; then
									echo "Found alias '${ALIAS#*.}'."
									domainchecker ${ALIAS#*.}
								fi
							fi
						done
					fi
				;;
			esac
		fi
	done
}
domainrebuilder() {
	CONST="id url user password"
	Group.getData ${GROUPNAME}
	DOMAINSDATA=$(cat ${SERVERSCONF} | fgrep -w server)
	if echo "${DOMAINSDATA}" | fgrep -v " />" | fgrep -v " -->" > /dev/null 2>&1 ; then
		System.print.error "broken servers.xml in '${GROUPNAME}' group"
		continue
	fi
	DOMAINDATA=$(echo "${DOMAINSDATA}" | fgrep -w "${ID}'")
	echo -n "Check for '${ID}' in servers.xml of '${GROUPNAME}' group..."
	if [ -z "${DOMAINDATA}" ];then
		System.print.status yellow "NOT FOUND"
	else
		System.print.status green "FOUND"
		DOMAINSDATA=$(echo "${DOMAINSDATA}" | fgrep -v -w "${ID}'")
		echo -n "'${ID}' status in servers.xml..."
		if [ "$(echo ${DOMAINDATA} | grep '\!--')" ]; then
			System.print.status yellow "DISABLED"
			case "${1}" in
				true)
					echo -n "Enabling '${ID}' in servers.xml..."
					START="<servers>\n\t<server"
					STOP=" />\n${DOMAINSDATA}\n</servers>\n"
					ENABLEPROCESSED="${ENABLEPROCESSED} ${GROUPNAME}"
					System.print.status green "ENABLED"
				;;
				*)
					START="<servers>\n\t<!-- server"
					STOP=" / -->\n${DOMAINSDATA}\n</servers>\n"
				;;
			esac
		else
			System.print.status green "ENABLED"
			case "${1}" in
				false)
					echo -n "Disabling '${ID}' in servers.xml..."
					START="<servers>\n\t<!-- server"
					STOP=" / -->\n${DOMAINSDATA}\n</servers>\n"
					DISABLEPROCESSED="${DISABLEPROCESSED} ${GROUPNAME}"
					System.print.status green "DISABLED"
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
					PASTVALUE=$(echo ${ITEM} | cut -d "=" -f 2 | tr -d "'" | tr -d '"')
					VALUE=$(getSettingValue ${KEY})
					System.print.info "Value of '${KEY}' key for '${ID}' in '${GROUPNAME}' group has changed from '${PASTVALUE}' to '${VALUE}'"
				else
					VALUE=$(echo ${ITEM} | cut -d "=" -f 2 | tr -d "'" | tr -d '"')
				fi
				if [ "${KEY}" = "user" -a "${VALUE}" != "${ID}" ] || [ "${KEY}" = "user" -a "$(echo ${OPTIONS} | fgrep -w force)" ]; then
					VALUE=${ID}
					PASSWORD=$(echo "${ID}.$HOST" | md5)
					if [ -z "$(psql -tAc "\\du \"$ID\"" postgres pgsql)" ]; then echo "CREATE USER \"${ID}\";"; fi | psql postgres pgsql -q
					{
						echo 'BEGIN;'
						if [ -z "$(psql -tAc "\\du access" "$ID" pgsql)" ]; then echo "CREATE GROUP access;"; fi
						cat <<-EOF
							ALTER USER "${ID}" ENCRYPTED PASSWORD '${PASSWORD}';
							GRANT access TO "$ID";
							GRANT ALL ON DATABASE "${ID}" TO access;
							GRANT ALL ON SCHEMA public TO access;
						EOF
						psql "$ID" pgsql -F\  -Atc '\d' | while read schema table dummy; do echo "GRANT ALL ON TABLE \"$schema\".\"$table\" TO access;"; done
						echo 'COMMIT;'
					} | psql "$ID" pgsql -q
					System.print.info "Value of '${KEY}' key for '${ID}' in '${GROUPNAME}' group has changed!"
				fi
				if [ "${PASSWORD}" -a "${KEY}" = "password" ]; then
					VALUE=${PASSWORD}
				fi
				printf " ${KEY}='${VALUE}'" >> ${SERVERSCONF}
			fi
		done
		printf "${STOP}" >> ${SERVERSCONF}
		System.print.info "Saving new servers.xml for '${GROUPNAME}' group!"
	fi
}
domainsync() {
	if [ "$(echo ${GROUPS} | fgrep -w ${FROMGROUP})" ]; then
		Group.getData ${FROMGROUP}
		FROMWEB=${WEB}
		if [ ! -d ${FROMWEB}/${ID} ]; then
			System.print.error "can not find domain with '${ID}' id on '${FROMGROUP}' group"
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
				System.print.error "'${GROUPNAME}' group not exist!"
			fi
		done
	else
		System.print.error "'${FROMGROUP}' group not exist!"
	fi
}
domainadd() {
	Group.getData ${GROUPNAME}
	DOMAINSDATA=$(cat ${SERVERSCONF} | fgrep -w server)
	DOMAINDATA=$(echo "${DOMAINSDATA}" | fgrep -w ${ID})
	echo -n "Check for '${ID}' in servers.xml of '${GROUPNAME}' group..."
	if [ "${DOMAINDATA}" ];then
		System.print.status yellow "SKIP"
		System.print.error "domain with '${ID}' id already exist"
	else
		System.print.status green "NOT FOUND"
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
		PASSWORD=$(dd if=/dev/random count=1 bs=8 | md5)
		psql -tA -c "CREATE OR REPLACE USER '${ID}' WITH PASSWORD '${PASSWORD}'" postgres pgsql
		psql -tA -c "GRANT ALL ON '${ID}' TO '${ID}'" postgres pgsql
		printf " user='${ID}'" >> ${SERVERSCONF}
		printf " password='${PASSWORD}'" >> ${SERVERSCONF}
		printf "${STOP}" >> ${SERVERSCONF}
		System.print.status green "OK"
	fi
}
setParametrsToVars() {
	COUNT=1
	for ITEM in ${VARS}; do
		KEY=$(eval echo '${'${COUNT}'}')
		if [ "${KEY}" = "" ]; then
			break
		fi
		if [ "${KEY}" = "+" ]; then
			KEY=$(eval echo '${'$((COUNT - 1))'}')
			EVAL="${KEY}='"$(eval echo '${'${KEY}'}')" ${ITEM}'"
		else
			COUNT=$((COUNT + 1))
			EVAL="${KEY}=${ITEM}"
		fi
		eval ${EVAL}
	done
}
Report.domains() {
	printf "<p>"
	printf "<b>DOMAINS:</b><br/>\n"
	printf "<table cellspacing=\"1\" cellpadding=\"3\" border=\"1\">\n"
	for GROUPNAME in ${GROUPS}; do
		HTMLGROUPS="${HTMLGROUPS}<th>${GROUPNAME}</th>"
	done
	printf "<tr><th>domain</th>${HTMLGROUPS}<th>dbsize</th><th>dbconn</th><th>owners</th></tr>\n"
	DOMAINS=""
	for GROUPNAME in ${GROUPS}; do
		Group.getData ${GROUPNAME}
		if [ ! -d ${WEB} ]; then
			continue
		fi
		if [ -z "${WEBS}" ]; then
			WEBS="${WEB}"
		else
			WEBS="${WEBS} ${WEB}"
		fi
		#REGEX: zone name
		for DOMAIN in $(ls ${WEB} | grep -E '\b[a-z0-9]*\.[a-z0-9\.\-]*\b'); do
			if echo "${DOMAINLIST}" | fgrep -w ${DOMAIN} > /dev/null 2>&1 ; then
				continue
			fi
			if [ -z "${DOMAINLIST}" ]; then
				DOMAINLIST="${DOMAIN}"
			else
				DOMAINLIST="${DOMAINLIST} ${DOMAIN}"
			fi
		done
	done
	DUDATA=$(nice -n 30 du -ch -d 1 ${WEBS})
	for DOMAIN in ${DOMAINLIST}; do
		printf "<tr><td>${DOMAIN}</td>"
		for WEB in ${WEBS}; do
			DOMAINSIZE=$(echo "${DUDATA}" | fgrep -m 1 -w ${WEB}/${DOMAIN} | cut -f 1)
			if [ -z "${DOMAINSIZE}" ]; then
				DOMAINSIZE="-"
			fi
			printf "<td>${DOMAINSIZE}</td>"
		done
		DBSIZE="-"
		if Database.check ${DOMAIN} > /dev/null 2>&1 ; then
			DBSIZE=$(Database.getSize ${DOMAIN})
		fi
		DOMAINOWNER=$(psql -tA -F' ' -c "SELECT login, email FROM umUserAccounts JOIN umUserGroups USING(userId) WHERE groupId='def.supervisor'" ${DOMAIN} pgsql > /dev/null 2>&1)
		printf "<td>${DBSIZE}</td><td>$(ps -ax | fgrep -w ${DOMAIN} | fgrep -v ${DOMAIN}. | fgrep -v fgrep | wc -l | tr -d ' ')</td><td>${DOMAINOWNER}</td></tr>\n"
	done
	printf "</table></p>\n"
}	
Report.daemons(){
	printf "<p><b>DAEMONS:</b><br/>\n"
	WATCHDOG="offline"
	if [ -f "${WATCHDOGFLAG}" ]; then
		if System.daemon.isExist $(cat ${WATCHDOGFLAG}); then
			WATCHDOG="online"
		fi
	fi
	POSTGRESQL="offline"
	if /usr/local/etc/rc.d/postgresql status > /dev/null 2>&1 ; then
		POSTGRESQL="online"
	fi
	printf "<table cellspacing=\"1\" cellpadding=\"3\" border=\"1\">\n"
#WEBMIN
	#	WEBMIN="offline"
	#	if /usr/local/etc/rc.d/webmin status > /dev/null 2>&1 ; then
	#		WEBMIN="online"
	#	fi
	#	printf "<tr><th>PostgreSQL</th><th>Watchdog</th><th>Webmin</th></tr>\n"
	#	printf "<tr><td>${POSTGRESQL}</td><td>${WATCHDOG}</td><td>${WEBMIN}</td></tr>\n"
	printf "<tr><th>PostgreSQL</th><th>Watchdog</th></tr>\n"
	printf "<tr><td>${POSTGRESQL}</td><td>${WATCHDOG}</td></tr>\n"
	printf "</table></p>\n"
}
Report.ipnat() {
	printf "<p><b>IPNAT:</b><br/>\n"
	printf "<table cellspacing=\"1\" cellpadding=\"3\" border=\"1\">\n"
	printf "<tr><th>External IP</th><th>Group</th><th>IPNAT redirects</th></tr>\n"
	IPNATDATA=$(/sbin/ipnat -l | fgrep -w RDR)
	for GROUPNAME in ${GROUPS}; do
		EXTIP=$(Config.setting.getValue ${GROUPNAME}-extip)
		for IP in ${EXTIP}; do
			COUNT=$(echo "${IPNATDATA}" | fgrep -w ${IP} | wc -l | tr -d " ")
			printf "<tr><td>${IP}</td><td>${GROUPNAME}</td><td>${COUNT}</td></tr>\n"
		done
	done
	IPNATCONN=$(echo "${IPNATDATA}" | grep RDR | wc -l | tr -d ' ')
	printf "<tr><td>*</td><td>*</td><td>${IPNATCONN}</td></tr>\n"
	printf "</table></p>\n"
}
System.status.getLoadAvg(){
	echo $(sysctl -n vm.loadavg | tr -d "{}")
}
Report.system() {
	OSUPTIME=$(/usr/bin/uptime | cut -d',' -f1 | sed 's/  / /g' | tr ' ' ',' | cut -d',' -f4-5 | tr ',' ' ')
	OSLOAD=$(System.status.getLoadAvg)
	JAVAVERSION=$(/usr/sbin/pkg_info | grep diablo-j | cut -d' ' -f1)
	POSTGRESQLVERSION=$(/usr/sbin/pkg_info | grep postgresql-server | cut -d'-' -f3 | cut -d' ' -f1)
	printf "<p>"
	printf "FreeBSD <b>${OSVERSION}</b> on <b>${ARCH}</b> platform with <b>${OSUPTIME}</b> uptime and <b>${OSLOAD}</b> load averages<br/>\n"
	printf "ACMBSD: <b>${VERSION}</b><br/>\n"
	printf "JAVA: <b>${JAVAVERSION}</b><br/>\n"
	printf "PostgreSQL: <b>${POSTGRESQLVERSION}</b><br/>\n"
	printf "Locally stored ACM.CM5:<br/>\n"
	printf "&nbsp;&nbsp;&nbsp;&nbsp;stable : <b>${ACMSTABLEVERSION}</b> (${ACMSTABLEDATE})<br/>\n"
	printf "&nbsp;&nbsp;&nbsp;&nbsp;release: <b>${ACMRELEASEVERSION}</b> (${ACMRELEASEDATE})<br/>\n"
	printf "&nbsp;&nbsp;&nbsp;&nbsp;current: <b>${ACMCURRENTVERSION}</b> (${ACMCURRENTDATE})<br/>"
	printf "</p>\n"
	printf "<p><b>GLOBAL SETTINGS:</b><br/>\n"
	printf "<table cellspacing=\"1\" cellpadding=\"3\" border=\"1\">\n"
	printf "<tr><th>Groups folder path</th><th>Administrator's e-mail</th><th>Maintenance time</th><th>Backup folder path</th><th>Backups limit</th></tr>\n"
	printf "<tr><td>${DEFAULTGROUPPATH}</td><td>$(Config.setting.getValue adminmail)</td><td>$(Config.setting.getValue autotime)</td><td>$BACKUPPATH</td><td>$(Config.setting.getValue backuplimit)</td></tr>\n"
	printf "</table></p>\n"
}
Report.connections() {
	printf "<p><b>CONNECTIONS:</b><br/>\n"
	SOCKSTATDATA=$(sockstat | fgrep java)
	DBCONN=$(echo "${SOCKSTATDATA}" | fgrep 5432 | wc -l | tr -d ' ')
	DBMAXCONN=$(cat ${PGDATAPATH}/postgresql.conf | grep 'max_connections =' | tr '\t' ' ' | cut -d ' ' -f 3)
	ACMINCONN=$(echo "${SOCKSTATDATA}" | fgrep -v 5432 | fgrep -v '*' | fgrep 172.16.0 | wc -l | tr -d ' ')
	ACMOUTCONN=$(echo "${SOCKSTATDATA}" | fgrep -v 5432 | fgrep -v '*' | fgrep -v 172.16.0 | fgrep -v 127.0.0 | fgrep tcp4 | wc -l | tr -d ' ')
	printf "<table cellspacing=\"1\" cellpadding=\"3\" border=\"1\">\n"
	printf "<tr><th>PostgreSQL</th><th>ACM.CM in</th><th>ACM.CM out</th></tr>\n"
	printf "<tr><td>${DBCONN}/${DBMAXCONN}</td><td>${ACMINCONN}</td><td>${ACMOUTCONN}</td></tr>\n"
	printf "</table></p>\n"
}
Report.diskusage() {
	printf "<p><b>DISK USAGE:</b><br/>\n"
	DUDATA=$(nice -n 30 du -ch -d 0 $ACMBSDPATH $DEFAULTGROUPPATH $BACKUPPATH $PGDATAPATH)
	TOTALSIZE=$(echo "$DUDATA" | fgrep -w total | cut -f 1)
	SYSTEMSIZE=$(echo "$DUDATA" | fgrep -w $ACMBSDPATH | cut -f 1)
	GROUPSIZE=$(echo "$DUDATA" | fgrep -w $DEFAULTGROUPPATH | cut -f 1)
	BACKUPSIZE=$(echo "$DUDATA" | fgrep -w $BACKUPPATH | cut -f 1)
	PGSIZE=$(echo "$DUDATA" | fgrep -w $PGDATAPATH | cut -f 1)
	printf "<table cellspacing=\"1\" cellpadding=\"3\" border=\"1\">\n"
	printf "<tr><th>Total</th><th>System</th><th>Groups</th><th>Backups</th><th>PostgreSQL</th></tr>\n"
	printf "<tr><td>$TOTALSIZE</td><td>$SYSTEMSIZE</td><td>$GROUPSIZE</td><td>$BACKUPSIZE</td><td>$PGSIZE</td></tr>\n"
	printf "</table></p>\n"
}	
Report.groups() {
	printf "<p><b>GROUPS:</b><br/>\n"
	DUDATA=$(nice -n 30 du -ch -d 3 ${DEFAULTGROUPPATH})
	for GROUPNAME in ${GROUPS} ; do
		Group.getData ${GROUPNAME}
		printf "<p>"
		printf "<b>$(echo ${GROUPNAME} | tr '[a-z]' '[A-Z]')</b><br/>\n"
		ACMBACKUPVERSION="-"
		if [ -e "${GROUPPATH}/public-backup/version/version" ]; then
			ACMBACKUPVERSION=$(cat ${GROUPPATH}/public-backup/version/version)
		fi
		if [ "${ACTIVEINSTANCES}" ]; then
			ACTIVATED=true
		else
			ACTIVATED=false
		fi
		DBCONN=$(echo "${SOCKSTATDATA}" | fgrep 5432 | fgrep ${GROUPNAME} | wc -l | tr -d ' ')
		ACMCONN=$(echo "${SOCKSTATDATA}" | fgrep -v 5432 | fgrep -v '*' | fgrep '172.16.0' | fgrep ${GROUPNAME} | wc -l | tr -d ' ')
		printf "<table cellspacing=\"1\" cellpadding=\"3\" border=\"1\">\n"
		printf "<tr><th>acmversion</th><th>acmbackupversion</th><th>active</th><th>memory</th><th>extip</th><th>branch</th><th>type</th><th>dbconn</th><th>acmconn</th></tr>\n"
		printf "<tr><td>${ACMVERSION}</td><td>${ACMBACKUPVERSION}</td><td>${ACTIVATED}</td><td>${MEMORY}</td><td>${EXTIP}</td><td>${BRANCH}</td><td>${TYPE}</td><td>${DBCONN}</td><td>${ACMCONN}</td></tr>\n"
		printf "</table>\n"
	
		printf "<table cellspacing=\"1\" cellpadding=\"3\" border=\"1\">\n"
		printf "<tr><th>instance</th><th>intip</th><th>status</th><th>cachesize</th><th>datasize</th><th>uptime</th><th>dbconn</th><th>acmconn</th></tr>\n"
		for INSTANCE in ${INSTANCELIST} ; do
			Instance.getData
			INSTANCECACHESIZE=$(echo "${DUDATA}" | fgrep -w ${PRIVATE}/cache | cut -f 1)
			if [ -z ${INSTANCECACHESIZE} ]; then
				INSTANCECACHESIZE=" 0B"
			fi
			INSTANCEDATASIZE=$(echo "${DUDATA}" | fgrep -w ${PRIVATE}/data | cut -f 1)
			if [ -z ${INSTANCEDATASIZE} ]; then
				INSTANCEDATASIZE=" 0B"
			fi
			UPTIME="-"
			if [ -e "${DAEMONFLAG}" ]; then
				PID=$(cat ${DAEMONFLAG})
				if System.daemon.isExist ${PID}; then
					ONLINE=online
					Instance.create ${INSTANCE} > /dev/null 2>&1
					STARTTIME=$(${INSTANCE}.getStartTime)
					if [ "${STARTTIME}" ]; then
						NOW=$(date "+%s")
						TIME=$((NOW-STARTTIME))
						UPTIME=$(getuptime ${TIME})
					fi
				else
					ONLINE=offline
				fi
			else
				ONLINE=offline
			fi
			if [ "${ONLINE}" = "offline" -a -f "${PRIVATE}/lastuptime" ]; then
				UPTIME=$(cat ${PRIVATE}/lastuptime)
			fi
			DBCONN=$(echo "${SOCKSTATDATA}" | fgrep 5432 | fgrep ${INSTANCE} | wc -l | tr -d ' ')
			ACMCONN=$(echo "${SOCKSTATDATA}" | fgrep -v 5432 | fgrep -v '*' | fgrep '172.16.0' | fgrep ${INSTANCE} | wc -l | tr -d ' ')
			printf "<tr><td>${INSTANCE}</td><td>${INTIP}</td><td>${ONLINE}</td><td>${INSTANCECACHESIZE}</td><td>${INSTANCEDATASIZE}</td><td>${UPTIME}</td><td>${DBCONN}</td><td>${ACMCONN}</td></tr>\n"
		done
		printf "</table>"
		printf "</p>\n"
	done
}
Report.getFullReport() {
	printf "<html>\n"
	Report.system
	Report.ipnat
	Report.domains
	Report.daemons
	Report.connections
	Report.diskusage
	Report.groups
	printf "</html>\n"
}
System.checkPermisson() {
	#TODO: use '|| System.isSystemGroup'
	System.isRoot && return 0
	echo $GROUPSNAME | fgrep -qw `echo $USER | tr -d '[0-9]'` && return 0 || return 1
}
System.fileWriteAccess() {
	[ -w $1 ] && return 0 || return 1
}
System.isRoot() {
	[ `whoami` = root ] && return 0 || return 1
}
System.isSystemGroup() {
	echo `groups` | fgrep -qw acmbsd && return 0 || return 1
}
System.runAsUser() {
	echo "Enter the password of '$1' user if prompted..."
	su - $1 -c "$2"
}
System.vars.groups() {
	echo "devel test live"
}
Command.depend.activeGroup() {
	if [ -z "$(Group.groups.getActive)" ]; then
		System.print.error "no active groups, this command need at least one active group!"
		exit 1
	fi
	return 0
}
System.waiting() {
	while true; do echo -n . && sleep $1; done
}
Named.transform(){
	local FILE=$1
	while [ 1 ]; do
		read LINE || break
		if [ "$(echo ${LINE} | fgrep var_)" ]; then
			local GROUPNAME=""
			for GROUPNAME in ${GROUPS}; do
				if [ "$(echo ${LINE} | fgrep var_${GROUPNAME})" ]; then
					Group.create ${GROUPNAME}
					local PUBLICIP="$(${GROUPNAME}.getPublicIP)"
					if [ "${PUBLICIP}" ]; then
						echo -n "${LINE}" | sed "s/var_${GROUPNAME}/${PUBLICIP}/"
					else
						local IPLIST=$(Config.setting.getValue "${GROUPNAME}-extip" | sed "s/;/ /")
						for ADDRESS in ${IPLIST}; do
							echo -n "${LINE}" | sed "s/var_${GROUPNAME}/${ADDRESS}/"
						done
					fi
				fi
			done
		else
			echo "${LINE}"
		fi
	done < $FILE
}
Named.zonefile() {
	cat <<-EOF
		@		IN	SOA `hostname`.	acmbsd.`hostname`. (
						_SERIAL	; serial number
						900			; refresh
						600			; retry
						86400		; expire
						3600	)	; default TTL
		@		NS	ns1.`hostname`.
		@		NS	ns2.`hostname`.
		@		TXT	"v=spf1 a ptr ~all"
	EOF
	Named.zonefile.groups
	[ $1 ] && Named.zonefile.gmail
}
Named.zonefile.groups() {
	for ITEM in $GROUPS;do
		if [ $ITEM = live ];then
			echo "*		A	_$ITEM"
			echo "@		A	_$ITEM"
		else
			echo "$ITEM		A	_$ITEM"
			echo "*.$ITEM		A	_$ITEM"
		fi
	done
	echo 'local		A	127.0.0.1'
	echo '*.local		A	127.0.0.1'
}
Named.zonefile.gmail() {
	cat <<-EOF
		@		2419200	MX	10	ASPMX.L.GOOGLE.COM.
		@		2419200	MX	20	ALT1.ASPMX.L.GOOGLE.COM.
		@		2419200	MX	20	ALT2.ASPMX.L.GOOGLE.COM.
		@		2419200	MX	30	ASPMX2.GOOGLEMAIL.COM.
		@		2419200	MX	30	ASPMX3.GOOGLEMAIL.COM.
		@		2419200	MX	30	ASPMX4.GOOGLEMAIL.COM.
		@		2419200	MX	30	ASPMX5.GOOGLEMAIL.COM.
		mail	2419200	CNAME	ghs.google.com.
	EOF
}
Named.conf.options() {
	cat <<-EOF
		options {
			directory "/etc/namedb";
			pid-file "/var/run/named/pid";
			allow-transfer {$NAMEDTRANSFER};
			dump-file "/var/dump/named_dump.db";
			statistics-file "/var/stats/named.stats";
			listen-on {127.0.0.1;$EXTIPS};
		};"
	EOF
}
Named.conf.zone() {
	#PARAM: $1 - zone name
	#PARAM: $2 - zone file path
	cat <<-EOF
		zone "$1" {
			type master;
			file "$2";
		};"
	EOF
}
Named.reload() {
	ZONEDIR=/etc/namedb/master/$GROUPNAME
	echo "ZONEDIR:$ZONEDIR,GROUPZONEDIR:$GROUPZONEDIR"
	System.fs.dir.create $ZONEDIR
	System.fs.dir.create $GROUPZONEDIR
	ZONES=`ls $GROUPZONEDIR | grep .dns`
	NAMEDCONF=""
	if ! cat $NAMEDCONFFILE | fgrep -q mainoptions; then
		EXTIPS=`Config.setting.getValue extip | tr '\n' ' ' | sed 's/,/;/' | sed 's/ /;/'` && [ "$EXTIPS" ] && EXTIPS="$EXTIPS;" || EXTIPS=''
		#TODO: transfers auto lookup
		NAMEDTRANSFER=`Config.setting.getValue namedtransfer && echo -n ';' || echo '"none";'`
		#TODO:echo '82.179.192.192;82.179.193.193'
		NAMEDCONF="options {directory \"/etc/namedb\";pid-file \"/var/run/named/pid\";allow-transfer {$NAMEDTRANSFER};dump-file \"/var/dump/named_dump.db\";statistics-file \"/var/stats/named.stats\";listen-on {127.0.0.1;$EXTIPS};}; //acm generatedoptions\n"
	fi
	rm -f $ZONEDIR/*
	for ITEM in $ZONES; do
		Named.transform $GROUPZONEDIR/$ITEM > $ZONEDIR/$ITEM
		echo -n $ITEM
		ZONE=${ITEM%%.dns}
		NAMEDCONF="${NAMEDCONF}zone \"$ZONE\" {type master;file \"$ZONEDIR/$ITEM\";}; //acm group=$GROUPNAME\n"
	done
	#TODO: TEST BIND RIGHTS
	chown -R root $ZONEDIR
	#TODO: use 'mktemp'
	cat $NAMEDCONFFILE | fgrep '//acm' | sed "/group=$GROUPNAME/d" | sed '/generatedoptions/d' > /tmp/named.conf && mv /tmp/named.conf /etc/namedb/
	chown -R root /etc/namedb/ && chmod -R 755 /etc/namedb/ && chown -R bind /etc/namedb/dynamic && chown -R bind /etc/namedb/slave
	printf "$NAMEDCONF" >> $NAMEDCONFFILE
	echo
	if ! /etc/rc.d/named reload; then
		/etc/rc.d/named restart
	fi
}
refreshmailaliases() {
	echo -n Refreshing aliases...
	rm -f /etc/aliases.db
	newaliases
	System.print.status green DONE
}
checkmailaliases(){
	echo -n "Check for /etc/mail/aliases..."
	ADMINMAIL=$(Config.setting.getValue "adminmail")
	if [ -z "${ADMINMAIL}" ]; then
		System.print.status yellow "NO EMAIL"
		return 1
	fi
	if ! cat /etc/mail/aliases | fgrep -w root: | fgrep -vw "# root:" > /dev/null 2>&1; then
		echo "root: ${ADMINMAIL}" >> /etc/mail/aliases
		System.print.status green ADDED
		refreshmailaliases
	else
		if ! cat /etc/mail/aliases | grep "${ADMINMAIL}" > /dev/null 2>&1; then
			cat /etc/mail/aliases | sed "/root:/d" > /tmp/aliases && mv /tmp/aliases /etc/mail/
			echo "root: ${ADMINMAIL}" >> /etc/mail/aliases
			System.print.status green REFRESHED
			refreshmailaliases
		else
			System.print.status green OK
		fi
	fi
}
Syntax.getStatus() {
	[ "$GROUPS" ] && Group.groups.getStatus || System.print.error 'no groups exist!'
}
Syntax.checksites() {
	Syntax.getStatus
	System.print.syntax 'dnsreload ( all | {groupname} )'
	[ $1 ] && exit 1
}
Syntax.start() {
	Syntax.getStatus
	System.print.syntax 'start ( all | {groupname} )'
}
Syntax.restart() {
	Syntax.getStatus
	System.print.syntax "restart ( all | {groupname} ) [-fast] [-skipwarmup] [-reset=(all | settings | cache | data )]"
}
Syntax.stop() {
	Syntax.getStatus
	System.print.syntax "stop ( all | {groupname} )"
}
Syntax.telnet() {
	System.print.syntax "telnet ( {group} | {instance} )"
	echo "Example: ${0} telnet live"
	echo
}
Syntax.mixlog(){
	CMDNAME="mixlog"
	System.print.syntax "${CMDNAME} ( all | {groupname} ) year month day hour [minute] [second]"
	System.print.example
	System.print.str "${CMDNAME} live 2010 01 08 21 [0-9]{2} [0-9]{2}"
	echo
}
Syntax.watchlog() {
	CMDNAME="watchlog"
	printf "Active groups: \33[1m$(echo ${ACTIVATEDGROUPS})\33[0m\n"
	echo "Logs:"
	for GROUPNAME in ${ACTIVATEDGROUPS}; do
		Group.getData ${GROUPNAME}
		INSTANCE=$(echo ${ACTIVEINSTANCES} | cut -d " " -f 1)
		Instance.getData
		if [ -d "${LOGS}" ]; then 
			LOGSNAMES=$(ls ${LOGS} | sed "/log.prev/d")
			printf "\t\33[1m${GROUPNAME}\33[0m\t$(echo ${LOGSNAMES})\n"
		fi
	done
	echo
	System.print.syntax "${CMDNAME} ( all | {groupname} ) [logname]"
	System.print.example
	System.print.str "${CMDNAME} all"
	System.print.str "${CMDNAME} test log default stdout"
	echo
}
Syntax.domain() {
	CMDNAME="domain"
	System.print.syntax "${CMDNAME} (add | remove | config | push | sync | *aliasadd)"
	System.print.example
	System.print.str "${CMDNAME} \33[1madd\33[0m -id={domain} [-group={groupname}] [-domain=value] [-entrance=value] [-aliases=value] [-exclude=value] [-class=value]"
	System.print.str "${CMDNAME} \33[1mremove\33[0m -id={domain} [-group={groupname}]"
	System.print.str "${CMDNAME} \33[1mconfig\33[0m -id={domain} [-group={groupname}] [-enable=( true | false )] [-domain=value] [-entrance=value] [-aliases=value] [-exclude=value] [-class=value]"
	System.print.str "${CMDNAME} \33[1maliasadd\33[0m -id={domain} -name={aliasname} [-nodns]"
	System.print.str "${CMDNAME} \33[1msync\33[0m -id={domain} -from={groupname} -to={groupname} [-to={groupname}]"
	System.print.str "${CMDNAME} \33[1mpush\33[0m -id={domain} -group=( devel | test )"
}
Syntax.cluster() {
	CMDNAME="cluster"
	System.print.syntax "${CMDNAME} (meet | syncto | syncfrom | syncbidi)"
	System.print.example
	System.print.str "${CMDNAME} \33[1mmeet\33[0m -host=server1.cluster.net -group=live"
	System.print.str "${CMDNAME} \33[1msyncto\33[0m -host=server1.cluster.net -group=live"
	System.print.str "${CMDNAME} \33[1msyncfrom\33[0m -host=server1.cluster.net -group=live"
	System.print.str "${CMDNAME} \33[1msyncbidi\33[0m -host=server1.cluster.net -group=live"
}
Syntax.help() {
	filtercommand(){
		echo "$COMMENTEDCOMMANDS" | fgrep -A1 -w $1 | fgrep -oE '\b[a-z]*\)?\b' | tr '\n' ' '
	}
	[ -d $ACMBSDPATH ] || $0 install notips
	printf "ACMBSD Script $VERSION\n"
	printf 'Commands:\n'
	printf "\tEveryday - $(filtercommand EVERYDAY)\n"
	printf "\tInfrequent - $(filtercommand INFREQ)\n"
	printf "\tDevel - $(filtercommand DEVEL)\n"
	printf "\t*Not ready - $(filtercommand NOTREADY)\n"
	printf "\t*System - $(filtercommand SYSTEM)\n"
	System.print.syntax '{command} [args]'
	System.print.info "type '$SCRIPTNAME {command}' for more detail help"
	[ $1 ] && exit 1
}

SCRIPTNAME=acmbsd
GROUPSNAME='devel test live temp'
RUNSTR="$0 $@"
COMMAND=$1
VERSION=136

COMMENTEDCOMMANDS=`cat $0 | fgrep -A1 '#COMMAND:' | fgrep -v fgrep`
COMMANDS=`echo "$COMMENTEDCOMMANDS" | fgrep -oE '\b[a-z]*\)?\b'`
[ "$COMMAND" ] && echo "$COMMANDS" | fgrep -qw $COMMAND || Syntax.help exit
Group.static && Instance.static

VARS=`eval echo '${@#'$COMMAND'}'`
parseOpts $VARS
[ "$COMMAND" != updatebsd -a "$COMMAND" != preparebsd ] && umask 002
System.checkPermisson || { System.runAsUser root "$RUNSTR"; exit 1; }

#-varSet
ARCH=`uname -p`
OSVERSION="`uname -r` (`uname -v | sed 's/  / /g' | cut -d' ' -f5-6`)"
OSMAJORVERSION=`uname -r | cut -d. -f1`
CVSREPO=cvs.myx.ru

ACMBSDPATH=/usr/local/$SCRIPTNAME
ACMCM5PATH=$ACMBSDPATH/acm.cm5
ACMCURRENTVERSIONFILE=$ACMCM5PATH/current/version/version
ACMRELEASEVERSIONFILE=$ACMCM5PATH/release/version/version
ACMSTABLEVERSIONFILE=$ACMCM5PATH/stable/version/version
DBTEMPLATEFILE=$ACMBSDPATH/db-template/acmbsd.backup
WATCHDOGFLAG=/var/run/acmbsd-watchdog.pid
NAMEDCONFFILE=/etc/namedb/named.conf
PGDATAPATH=/usr/local/pgsql/data
ACMBSDCOMPFILE=/tmp/acmbsd.cli.completion.list
PORTSUPDLOGFILE=/tmp/acmbsd.updports.log
OSUPDLOGFILE=/tmp/acmbsd.updbsd.log

DATAFILE=$ACMBSDPATH/data.conf
if [ ! -f $DATAFILE ]; then
	System.fs.dir.create $ACMBSDPATH > /dev/null
	touch $DATAFILE
fi
Config.reload

DEFAULTGROUPPATH=`Config.setting.getValue groupspath`
if [ -z "$DEFAULTGROUPPATH" ]; then
	Config.setting.setValue groupspath /usr/local/acmgroups
	DEFAULTGROUPPATH=/usr/local/acmgroups
fi

SHAREDPATH=`Config.setting.getValue sharedpath`
if [ -z "$SHAREDPATH" ]; then
	Config.setting.setValue sharedpath /usr/local/acmshared
	SHAREDPATH=/usr/local/acmshared
fi
BACKUPPATH=$SHAREDPATH/backup

BACKUPLIMIT=`Config.setting.getValue backuplimit`
if [ -z "$BACKUPLIMIT" ]; then
	Config.setting.setValue backuplimit 7
	BACKUPLIMIT=7
fi

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

getacmversions

case $COMMAND in
	#COMMAND:EVERYDAY
	cli)
		if echo $OPTIONS | fgrep -qw rlwrap; then
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
		setParametrsToVars GROUPNAME
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
				Group.startAll "$ACTIVATEDGROUPS"
				Network.message.send "`/sbin/dmesg -a`" "server started" "plain"
			;;
			*)
				Syntax.start
			;;
		esac
	;;
	#COMMAND:DEVEL
	profile)
		setParametrsToVars GROUPNAME
		if Group.getData $GROUPNAME && Group.isPassive $GROUPNAME; then
			Instance.getData ${GROUPNAME}1
#			PRIVATE=$HOME/acmprofile
			System.fs.dir.create $PRIVATE > /dev/null 2>&1
#			LOGS=$PRIVATE/logs
			System.fs.dir.create $LOGS > /dev/null 2>&1
			cd $PUBLIC
			ADMINMAIL=$(Config.setting.getValue adminmail)
			PROGEXEC="java -server"
			ACMEA=$(Config.setting.getValue $GROUPNAME-ea)
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
		System.print.syntax "profile {GROUPNAME}"
		exit 1
	;;
	#COMMAND:SYSTEM
	watchdog)
		Watchdog.command
	;;
	#COMMAND:EVERYDAY
	stop)
		setParametrsToVars GROUPNAME
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
				System.print.info "next start: $ACTIVATEDGROUPS"
				Group.stopAll "$ACTIVATEDGROUPS"
				Network.message.send "`Report.getFullReport`" "server shutdown" "html"
			;;
			*)
				Syntax.stop
			;;
		esac
	;;
	#COMMAND:EVERYDAY
	restart)
		setParametrsToVars GROUPNAME
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
		setParametrsToVars GROUPNAME
		if Group.isGroup $GROUPNAME; then
			if ! Group.create $GROUPNAME && $GROUPNAME.isExist;then
				System.print.error "can't find group"
				echo && exit 1
			fi
			if Console.isOptionExist rollback; then
				System.message 'Check for public backup and his version...' waitstatus
#					echo -n 'Check for public backup and his version...'
				if [ -f "$PUBLICBACKUP/version/version" ]; then
					System.print.status green "`cat $PUBLICBACKUP/version/version`"
					System.message "Rollback in the previous version..." waitstatus
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
					System.message "Set update status to 'freeze'..." waitstatus
#						echo -n "Set update status to 'freeze'..."
					System.print.status green DONE
## TODO: freeze update
				else
					System.print.status red "NOT FOUND"
					echo
					exit 1
				fi
				echo
				exit 0
			fi
			System.message "Command '$COMMAND' running" no "[$COMMAND]"
			case "`$GROUPNAME.getBranch`" in
				current)
					cvsacmcm current $ACMCURRENTVERSION
				;;
				release)
					cvsacmcm release $ACMRELEASEVERSION
				;;
				stable)
					cvsacmcm stable $ACMSTABLEVERSION
				;;
				*)
					System.print.syntax "branch must be: 'current', 'release' or 'stable'."
					echo
					exit 1
				;;
			esac
			Group.create $GROUPNAME && $GROUPNAME.update
			echo
			exit $RETVAL
		fi
		case $MODS in
			all)
				System.message "Command '$COMMAND' running" no "[$COMMAND]"
				Script.update
				cvsacmcm current $ACMCURRENTVERSION
				cvsacmcm release $ACMRELEASEVERSION
				cvsacmcm stable $ACMSTABLEVERSION
				Group.updateAll
			;;
			system)
				System.message "Command '$COMMAND' running" no "[$COMMAND]"
				Script.update
			;;
			check)
				System.message "Command '$COMMAND' running" no "[$COMMAND]"
				Script.update.check
				cvsacmcm current $ACMCURRENTVERSION onlycheck
				cvsacmcm release $ACMRELEASEVERSION onlycheck
				cvsacmcm stable $ACMSTABLEVERSION onlycheck
			;;
			*)
				System.print.syntax "update ( all | system | check | {groupname} ) [-rollback] [-force]"
				echo "Options:"
				printf "\trollback - rollback in the previous version and set 'frozen' status\n"
				printf "\trelease - removes the frozen status of the group\n"
				printf "\tfreeze - establishes a frozen status of the group\n"
				printf "\tforce - update group(s) without check\n"
				if [ "$GROUPS" ]; then
					Group.groups.getStatus
				else
					System.print.error 'no groups exist!'
				fi
				echo
				exit 1
			;;
		esac
		echo
		exit ${RETVAL}
	;;
	#COMMAND:INFREQ
	add)
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
			System.print.status red "ALL IN USE"
			System.print.info "All groups are already added!"
			exit 1
		else
			System.print.status green FOUND
		fi
		setParametrsToVars GROUPNAME
		if Group.create $GROUPNAME && ! $GROUPNAME.isExist; then
			if ! echo $SETTINGS | fgrep extip && [ "`Network.getFreeIPList`" ]; then
				for ITEM in `Network.getFreeIPList`; do
					$GROUPNAME.add -extip=$ITEM
					break
				done
			else
				$GROUPNAME.add
			fi
			System.print.info "group '$GROUPNAME' is added, you can change group setting by '$SCRIPTNAME config $GROUPNAME'!"
		else
			printf "Settings info:\n"
			printf "\t-extip=192.168.1.1 - IP-address that not used by acm.cm already\n"
			printf "\t-memory=256m - memory for each one instance in group, default '512m'\n"
			printf "\t-branch=( stable | release | current ) - branch of acm.cm5, default to live group is 'stable' for test and devel groups is 'release'\n"
			printf "\t-type=( minimal | standard | extended | parallel ) - type of group, default 'standard'\n"
			cat <<-EOF
				Group type information:
					minimal		- 1 instance always, hard restart
					standard	- 1 instance running of 2 instances, soft restart
					extended	- 2 instances running, but traffic pass only to one, soft restart
					parallel	- 2 or more instances running, soft restart
			EOF
			echo
			printf "Free groups: \33[1m$FREEGROUPS\33[0m\n"
			printf "Free IP-addresses: \33[1m`Network.getFreeIPList`\33[0m\n"
			echo
			printf "Example: $SCRIPTNAME $COMMAND {groupname} -extip=192.168.1.1 [-branch=release] [-memory=512m] [-type=standard]\n"
		fi
		return 0
	;;
	#COMMAND:EVERYDAY
	status)
		case "${MODS}" in
			fullreport)
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
				System.print.info "paths: acmbsd - $ACMBSDPATH, groups - $DEFAULTGROUPPATH, shared - $SHAREDPATH"
				System.print.syntax "status (system | ipnat | domains | daemons | connections | diskusage | groups | fullreport)"
				exit 1
			;;
		esac
	;;
	#COMMAND:INFREQ
	remove)
		setParametrsToVars GROUPNAME
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
			System.print.info "You can use 'acmbsd remove {groupname}'"
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
				ENABLEARG=$(getSettingValue enable)
				for GROUPNAME in ${GROUPSPROCESS}; do
					if [ "$(echo ${GROUPS} | fgrep -w ${GROUPNAME})" ]; then
						domainrebuilder "${ENABLEARG}"
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
				for GROUPNAME in ${GROUPSPROCESS}; do
					if [ "$(echo ${GROUPS} | fgrep -w ${GROUPNAME})" ]; then
						domainadd
					fi
				done
				echo "Create database with '${ID}' name..."
				if Database.create ${ID} > /dev/null 2>&1; then
					System.print.status green DONE
				else
					System.print.status yellow FAILED
				fi
			;;
			remove)
				for GROUPNAME in ${GROUPS}; do
					Group.getData ${GROUPNAME}
					DOMAINSDATA=$(cat ${SERVERSCONF} | fgrep -w server)
					DOMAINDATA=$(echo "${DOMAINSDATA}" | fgrep -w ${ID})
					echo -n "Check for '${ID}' in servers.xml of '${GROUPNAME}' group..."
					if [ -z "${DOMAINDATA}" ];then
						System.print.status yellow "NOT FOUND"
					else
						System.print.status green "FOUND"
						echo -n "Remove entry '${ID}' from '${GROUPNAME}' group..."
						DOMAINSDATA=$(echo "${DOMAINSDATA}" | fgrep -v -w ${ID})
						printf "<servers>\n${DOMAINSDATA}\n</servers>\n" > ${SERVERSCONF}
						System.print.status green "OK"
						echo -n "Remove '${WEB}/${ID}'..."
						rm -rdf ${WEB}/${ID}
						System.print.status green "OK"
					fi
				done
			;;
			push)
				GROUPNAME=$(getSettingValue group)
				if [ -z "${GROUPNAME}" ]; then
					System.print.syntax "domain push -id={domain} -group=( devel | test )\n\n"
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
			aliasadd)
				System.nextrelease
				GROUPSARG=$(getSettingValue group)
				if [ "${GROUPSARG}" ]; then
					GROUPSPROCESS=${GROUPSARG}
				else
					GROUPSPROCESS=${GROUPS}
				fi
				ENABLEARG=$(getSettingValue enable)
				for GROUPNAME in ${GROUPSPROCESS}; do
					if [ "$(echo ${GROUPS} | fgrep -w ${GROUPNAME})" ]; then
						domainrebuilder "${ENABLEARG}"
					fi
				done
			;;
			sync)
				FROMGROUP=$(getSettingValue from)
				TOGROUPS=$(getSettingValue to)
				if [ -z "${FROMGROUP}" -o -z "${TOGROUPS}" ]; then
					System.print.syntax "domain sync -id={domain} -from={groupname} -to={groupname} [-to={groupname}]\n\n"
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
		if [ "$MODS" ] && echo $GROUPS | fgrep -q $MODS; then
			Group.create $MODS
			if [ -z "$SETTINGS" ]; then
				$MODS.getSettings
				System.print.syntax "$COMMAND {groupname} [-branch=release] [-memory=256m] [-extip=10.1.1.1] [-publicip=10.1.1.2] [-type=standard] [-instances={1,9}] [-namedtransfer=10.1.0.1]\n"
				exit 1
			fi
			$MODS.config && exit 0
		fi
		case "$MODS" in
			system)
				ADMIN=`Config.setting.getValue adminusers`
				ADMINMAIL=`Config.setting.getValue adminmail`
				AUTOTIME=`Config.setting.getValue autotime`
				SHAREDPATH=`Config.setting.getValue sharedpath`
				BACKUPLIMIT=`Config.setting.getValue backuplimit`
				NAMEDTRANSFER=`Config.setting.getValue namedtransfer || echo none`
				RELAYHOST=`Config.setting.getValue relayhost`
				if [ -z "$SETTINGS" ]; then
					printf "Settings info and thier values:\n"
					printf "\t-path=$DEFAULTGROUPPATH - default store path for new groups\n"
					printf "\t-admin=$ADMIN - user that control system, list allowed with ',' as separator\n"
					printf "\t-email=$ADMINMAIL - administrator's email for errors and others\n"
					printf "\t-autotime=$AUTOTIME - time when service daemon starts, value can be 'off'\n"
					printf "\t-shared=$SHAREDPATH - shared dir for backup store and etc\n"
					printf "\t-relay=$RELAYHOST - SMTP relay host\n"
					printf "\t-namedtransfer=$NAMEDTRANSFER - to set global 'allow-transfer' option in named.conf, list allowed with ',' as separator\n"
					printf "\t-backuplimit=$BACKUPLIMIT - how many auto backups need to store (1-16), default is '7'\n"
					echo
					printf "Example: acmbsd config system -email=someone@domain.org,anotherone@domain.org -autotime=04:00 -path=/usr/local/acmgroups\n"
				fi
				for ITEM in $SETTINGS; do
					KEY=`echo $ITEM | cut -d= -f1`
					VALUE=`echo $ITEM | cut -d= -f2`
					if [ -z "$VALUE" ]; then
						System.print.error "bad value on '$KEY' key!"
						exit 1
					fi
					case $KEY in
						-path)
							PASTVALUE=$DEFAULTGROUPPATH
							[ "$PASTVALUE" = $VALUE ] && System.print.info "Same here" && exit 1
							Config.setting.setValue groupspath $VALUE
							System.print.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-admin)
							PASTVALUE=$ADMIN
							[ "$PASTVALUE" = $VALUE ] && System.print.info "Same here" && exit 1
							Config.setting.setValue adminusers $VALUE
							$0 access
							System.print.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-relay)
							PASTVALUE=$RELAYHOST
							[ "$PASTVALUE" = $VALUE ] && System.print.info "Same here" && exit 1
							Config.setting.setValue relayhost $VALUE
							MAINCF=`cat /usr/local/etc/postfix/main.cf | sed -l '/^relayhost/d'`
							echo "$MAINCF" > /usr/local/etc/postfix/main.cf
							echo "relayhost = $VALUE" >> /usr/local/etc/postfix/main.cf
							/usr/local/etc/rc.d/postfix stop
							/usr/local/etc/rc.d/postfix start
							System.print.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-email)
							PASTVALUE=$ADMINMAIL
							[ "$PASTVALUE" = $VALUE ] && System.print.info "Same here" && exit 1
							Config.setting.setValue adminmail $VALUE
							Network.message.send "PASTVALUE:'$PASTVALUE' VALUE:'$VALUE'" "administrator's email changed" plain -email=$PASTVALUE,$VALUE
							System.print.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
							checkmailaliases
						;;
						-autotime)
							PASTVALUE=$AUTOTIME
							[ "$PASTVALUE" = $VALUE ] && System.print.info "Same here" && exit 1
							Config.setting.setValue autotime $VALUE
							System.print.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-shared)
							PASTVALUE=$SHAREDPATH
							[ "$PASTVALUE" = $VALUE ] && System.print.info "Same here" && exit 1
							Config.setting.setValue sharedpath $VALUE
							System.print.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-backuplimit)
							echo $VALUE | fgrep -wqoE "[0-9]{1,2}" && System.print.error "setting '$KEY' has bad value!" && continue
							PASTVALUE=$BACKUPLIMIT
							[ "$PASTVALUE" = $VALUE ] && System.print.info "Same here" && exit 1
							Config.setting.setValue backuplimit $VALUE
							System.print.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
						-namedtransfer)
							PASTVALUE=$NAMEDTRANSFER
							[ "$PASTVALUE" = $VALUE ] && System.print.info "Same here" && exit 1
							Config.setting.setValue namedtransfer $VALUE
							System.print.info "Value of '$KEY' setting has changed from '$PASTVALUE' to '$VALUE'"
						;;
					esac
				done
			;;
			*)
				System.print.syntax "config ( system | {groupname} ) {settings}"
				if [ "$GROUPS" ]; then
					printf "Groups list: \33[1m`echo $GROUPS`\33[0m\n"
				else
					System.print.error "no groups exist!"
				fi
			;;
		esac
		echo
	;;
	#COMMAND:INFREQ
	install)
		System.message "Command '$COMMAND' running" no "[$COMMAND]"
		System.fs.dir.create $ACMBSDPATH
		System.fs.dir.create $DEFAULTGROUPPATH
		System.changeRights $DEFAULTGROUPPATH acmbsd acmbsd 0775 -recursive=false

		MIG1_SHAREDPATH=`Config.setting.getValue sharedpath`
		if [ -z "$MIG1_SHAREDPATH" -o ! -d $MIG1_SHAREDPATH ]; then
			MIG1_BACKUPPATH=`Config.setting.getValue backuppath`
			if [ "$MIG1_BACKUPPATH" ]; then
				Config.setting.setValue sharedpath $MIG1_BACKUPPATH
				SHAREDPATH=$MIG1_BACKUPPATH
				System.fs.dir.create $SHAREDPATH
				Config.setting.remove backuppath
			fi
		else
			System.fs.dir.create $SHAREDPATH
		fi

		paramcheck /etc/rc.conf postgresql_enable=\"YES\"
		System.message "Check for '/usr/local/pgsql/data" waitstatus
		if [ -d /usr/local/pgsql/data ]; then
			System.print.status green FOUND
		else
			System.print.status yellow "NOT FOUND"
			if /usr/local/etc/rc.d/postgresql initdb; then
				/usr/local/etc/rc.d/postgresql start
			else
				System.print.error "can not initdb!"
				exit 1
			fi
		fi
		if ! echo $OPTIONS | fgrep -q noupdate; then
			echo
			System.message "Running 'acmbsd update all'..."
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
		read COMMIT
		echo $COMMIT | fgrep -w yes || exit 0
		#TODO: REDO
		/usr/local/etc/rc.d/rcacm.sh stop
		rm -rdf $ACMBSDPATH
		rm /usr/local/bin/acmbsd
		rm /usr/local/etc/rc.d/rcacm.sh
		System.print.info "untouched directories: $DEFAULTGROUPPATH $SHAREDPATH"
		System.print.info "additional packages not removed such as bash, postgresql, mpd5 and etc!"
	;;
	#COMMAND:INFREQ
	preparebsd)
		echo Prepareing BSD...
		checkmailaliases
		System.fs.dir.create ${ACMBSDPATH}/.ssh
		echo -n Check for keys...
		if [ ! -f "${ACMBSDPATH}/.ssh/id_rsa" -o ! -f "${ACMBSDPATH}/.ssh/id_rsa.pub" ]; then
			ssh-keygen -q -N "" -f ${ACMBSDPATH}/.ssh/id_rsa -t rsa
			System.print.status green CREATED
		else
			System.print.status green FOUND
		fi
		## Keeps SSH connection
		paramcheck /etc/ssh/sshd_config "^ClientAliveInterval*" "ClientAliveInterval 60"
		paramcheck /etc/ssh/sshd_config "^ClientAliveCountMax*" "ClientAliveCountMax 10"
		##
		sys.grp.chk $SCRIPTNAME
		sys.usr.chk $SCRIPTNAME && sys.usr.setHome $SCRIPTNAME $ACMBSDPATH
		echo -n "Check for ports..."
		if [ -d /usr/ports -a -e /usr/ports/Makefile ] ; then
			System.print.status green "FOUND"
		else
			System.print.status yellow "NOT FOUND"
			echo "Getting ports tree..."
			portsnap fetch
			portsnap extract
			portsnap update
		fi

		echo -n "Check for make.conf..."
		if [ ! -e /etc/make.conf ]; then
			System.print.status yellow "NOT FOUND"
			echo "CFLAGS= -O2 -pipe -funroll-loops" > /etc/make.conf
			echo "COPTFLAGS= -O2 -pipe -funroll-loops" >> /etc/make.conf
			echo "CXXFLAGS+= -fconserve-space" >> /etc/make.conf
		else
			System.print.status green "FOUND"
		fi

		pkgcheck bash shells/bash
		pkgcheck sudo security/sudo
		pkgcheck nano editors/nano
		pkgcheck curl ftp/curl
		pkgcheck xauth x11/xauth
		pkgcheck rsync net/rsync
		pkgcheck rlwrap devel/rlwrap
		pkgcheck screen sysutils/screen
		pkgcheck elinks www/elinks
		#pkgcheck mrtg net-mgmt/mrtg
		pkgcheck portupgrade ports-mgmt/portupgrade
		pkgcheck portcheck ports-mgmt/portcheck
		pkgcheck pkg_cleanup ports-mgmt/pkg_cleanup
		pkgcheck postgresql-server databases/postgresql84-server
		#pkgcheck p5-IO-Tty devel/p5-IO-Tty
		#pkgcheck p5-Authen-Libwrap security/p5-Authen-Libwrap
		#pkgcheck p5-DBI databases/p5-DBI
		#pkgcheck p5-DBD-Pg databases/p5-DBD-Pg
		pkgcheck xtail misc/xtail
		#pkgcheck mpd net/mpd5
		pkgcheck postfix mail/postfix
		pkgcheck metamail mail/metamail
		#pkgcheck lame audio/lame

		Java.pkg.install
		##	Java X11 support
		pkgcheck libXtst x11/libXtst
		pkgcheck libXi x11/libXi
		##	Java profiler
		pkgcheck tijmp devel/tijmp

		paramcheck /etc/rc.conf sshd_enable=\"YES\"
		paramcheck /etc/rc.conf fsck_y_enable=\"YES\"
		#OLD	paramcheck /etc/rc.conf webmin_enable=\"YES\"
		paramcheck /etc/rc.conf named_enable=\"YES\"
		paramcheck /etc/rc.conf ntpdate_enable=\"YES\"
		paramcheck /etc/rc.conf ntpdate_flags "ntpdate_flags=\"-b pool.ntp.org europe.pool.ntp.org time.euro.apple.com\""
		#Postfix
		refreshmailaliases

		System.fs.dir.create /etc/ipf/ > /dev/null 2>&1
		ipf.conf() {
			cat <<-EOF
				# local interface
				pass in  quick on lo0 all
				pass out quick on lo0 all
			EOF
			for IF in $@; do
				cat <<-EOF
					pass out quick on $IF all keep state
					# http
					pass in  quick on $IF proto tcp from any to any port = 80 keep state
					pass in  quick on $IF proto tcp from any to any port = 14080 keep state
					# https
					pass in  quick on $IF proto tcp from any to any port = 443 keep state
					pass in  quick on $IF proto tcp from any to any port = 14443 keep state
					# dns
					pass in  quick on $IF proto tcp from any to any port = 53 keep state
					pass in  quick on $IF proto udp from any to any port = 53 keep state
					# ssh
					pass in  quick on $IF proto tcp from any to any port = 22 keep state
					# acm.ssh
					pass in  quick on $IF proto tcp from any to any port = 14022 keep state
					# csync2
					pass in  quick on $IF proto tcp from any to any port = 30865 keep state
					# cvs server
					pass in  quick on $IF proto tcp from any to any port = 2401 keep state
					# reject auth queries that remote mail relays mat send
					block return-rst in on $IF quick proto tcp from any to any port = 113
					EOF
			done
			cat <<- EOF
				# allow ping from outside
				pass in quick proto icmp from any to any icmp-type 8 code 0 keep state
				# allow ping from inside
				pass out quick proto icmp from any to any icmp-type 8 code 0 keep state
				# block others
				block in quick from any to any
				block out quick from any to any
			EOF
		}
		ipf.conf "`/sbin/ifconfig -lu | sed 's/lo0 //' | sed 's/ lo0//'`" > /etc/ipf/ipf.conf
		if [ ! -f /etc/ipf/ipnat.conf ]; then
			touch /etc/ipf/ipnat.conf
		fi

		paramcheck /etc/rc.conf ipfilter_enable=\"YES\"
		paramcheck /etc/rc.conf ipnat_enable=\"YES\"
		paramcheck /etc/rc.conf ipmon_enable=\"YES\"
		paramcheck /etc/rc.conf ipfs_enable=\"YES\"
		paramcheck /etc/rc.conf ipfilter_rules=\"/etc/ipf/ipf.conf\"
		paramcheck /etc/rc.conf ipnat_rules=\"/etc/ipf/ipnat.conf\"

		paramcheck /etc/rc.conf sendmail_enable=\"NO\"
		paramcheck /etc/rc.conf sendmail_submit_enable=\"NO\"
		paramcheck /etc/rc.conf sendmail_outbound_enable=\"NO\"
		paramcheck /etc/rc.conf sendmail_msp_queue_enable=\"NO\"
		paramcheck /etc/rc.conf postfix_enable=\"YES\"

		IPFSTATUS=`/etc/rc.d/ipfilter status | grep Running | cut -d: -f2 | tr -d ' '`
		if [ "$IPFSTATUS" = yes ]; then
			/etc/rc.d/ipfilter reload
			/etc/rc.d/ipnat reload
		else
			/etc/rc.d/ipfilter start
			/etc/rc.d/ipnat start
		fi
		/usr/local/etc/rc.d/postfix stop
		/usr/local/etc/rc.d/postfix start
		paramcheck /boot/loader.conf kern.ipc.semmni kern.ipc.semmni=256
		paramcheck /boot/loader.conf kern.ipc.semmns kern.ipc.semmns=512
		paramcheck /boot/loader.conf kern.ipc.semmnu kern.ipc.semmnu=256

		paramcheck /etc/sysctl.conf kern.ipc.shmall kern.ipc.shmall=32768
		paramcheck /etc/sysctl.conf kern.ipc.shmmax kern.ipc.shmmax=134217728
		paramcheck /etc/sysctl.conf kern.ipc.semmap kern.ipc.semmap=256
		paramcheck /etc/sysctl.conf kern.ipc.shm_use_phys kern.ipc.shm_use_phys=1

		cfg.profile > /etc/profile
		cfg.nanorc > /usr/local/etc/nanorc
		cfg.screenrc > /usr/local/etc/screenrc
		cfg.inputrc > /etc/inputrc
		cfg.login.conf > /etc/login.conf && cap_mkdb /etc/login.conf

		chown -R pgsql:pgsql /usr/local/share/postgresql
		chown -R pgsql:pgsql /usr/local/lib/postgresql
		
		System.print.info "Installing system? Reboot your OS!"
		 echo
	;;
	#COMMAND:DEVEL
	javaupdate)
		Java.pkg.install
	;;
	#COMMAND:INFREQ
	updatebsd)
		if ! echo $OPTIONS | fgrep -w notips > /dev/null 2>&1 ; then
			System.print.info "if you want to upgrade you system to next version then use 'freebsd-update -r 7.X-RELEASE upgrade'"
		fi
		System.updateAll
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
		${0} autoupdate
		Network.message.send "$(top -bItaSC)" "top status" "plain"
		${0} restart all > /tmp/acmbsd.restart.tmp 2> /tmp/acmbsd.restart.tmp
		System.updateAll autotime
		${0} autoreport
		if [ -f /tmp/acmbsd.service.log ]; then
			Network.message.send "$(cat /tmp/acmbsd.service.log)" "service log" "plain"	
			rm -rdf /tmp/acmbsd.service.log
		fi
	;;
	#COMMAND:SYSTEM
	autoreport)
		Network.message.send "$(Report.getFullReport)" "status report" "html"
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
			System.print.status green FOUND
		else
			System.print.status red "NOT FOUND"
			exit 1
		fi
		Group.getData
		System.fs.dir.create $WEB
		SITES=`ls -U $WEB`
		if [ -z "$SITES" ]; then
			System.print.error "group 'live' do not have any domains!"
			exit 1
		fi
		for ITEM in $SITES; do
			$0 backup -domain=$ITEM
		done
		NOW=`date +%s`
		TIME=$((NOW-STARTTIME))
		UPTIME=`getuptime $TIME`
		System.print.info "Backup of all 'live' group domains has completed! Backup time: $UPTIME"
		echo $UPTIME > /tmp/lastacmbackup.time
		echo
	;;
	#COMMAND:INFREQ
	backup)
		Syntax.backup(){
			System.print.syntax "backup -domain=value [-group=( live | test | devel )] [-nodb] [-name=com.domain] [-path=~/mybackups]"
			echo "Produce .tar.gz archive that contains DB or domain files and can be restored with 'acmbsd restore' command."
			[ $1 ] && exit 1
		}
		DOMAIN=`Console.getSettingValue domain`
		[ $DOMAIN ] || Syntax.backup exit
		STARTTIME=`date +%s`
		System.print.info "Backup of '$DOMAIN' has started!"
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
		if echo $SETTINGS | fgrep -q path; then
			BACKUPDIRPATH=`getSettingValue path`
			if echo $SETTINGS | fgrep -q name; then
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
			if pg_dump -f $BACKUPTMPPATH/db.backup -O -Z 4 -Fc -U pgsql $DOMAIN > /dev/null 2>&1 ; then
				System.print.status green DONE
			else
				System.print.status red FAILED
				rm -rdf $BACKUPTMPPATH
				System.print.info "maybe you enter not valid domain name?"
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
			System.print.status green DONE
		done
		CHECKBACKUPTMP=`ls -U $BACKUPTMPPATH | wc -w`
		if [ $CHECKBACKUPTMP -eq 0 ]; then
			rm -rdf $BACKUPTMPPATH
			System.print.error "Nothing to backup!"
			exit 1
		fi
		echo -n Archiveing backup folder...
		cd $BACKUPTMPPATH
		CONTENTS=`ls -U`
		/usr/bin/tar -czf $BACKUPDIRPATH/$BACKUPNAME.tar.gz $CONTENTS > /dev/null 2>&1
		[ "$CHANGEPERM" = 1 ] && chown acmbsd:acmbsd $BACKUPDIRPATH/$BACKUPNAME.tar.gz
		System.print.status green DONE
		System.fs.dir.remove() {
			echo -n $1...
			if [ -d $1 ]; then
				if [ `echo $1 | wc -c` -gt 3 ]; then
					rm -rdf $1
					System.print.status green REMOVED
				else
					System.print.status red "NOT VALID"
				fi
			else
				System.print.status yellow "NOT FOUND"
			fi
		}
		System.fs.dir.remove $BACKUPTMPPATH
		if ! echo $SETTINGS | fgrep -q path; then
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
				System.print.status green DONE
			fi
		fi
		echo "Backup path: $BACKUPDIRPATH/$BACKUPNAME.tar.gz"
		echo "Backup contents: "$CONTENTS
		echo "Backup size: `du -h $BACKUPDIRPATH/$BACKUPNAME.tar.gz | cut -f1`"
		NOW=`date +%s`
		TIME=$((NOW-STARTTIME))
		UPTIME=`getuptime $TIME`
		System.print.info "Backup of '$DOMAIN' has completed! Backup time: $UPTIME"
		echo
	;;
	#COMMAND:INFREQ
	restore)
		if Console.isSettingExist domain && Console.isSettingExist path; then
			STARTTIME=`date +%s`
			BACKUPFILE=`getSettingValue path`
			if [ "$BACKUPFILE" -a ! -e $BACKUPFILE ]; then
				System.print.error "can not find backup with path '$BACKUPFILE'"
				exit 1
			fi
			DOMAIN=`getSettingValue domain`
			BACKUPGROUPS=`getSettingValue group`
			if [ -z "$BACKUPGROUPS" -a -z `echo $OPTIONS | fgrep -w db` ]; then
				System.print.error "set what to restore with setting '-group={groupname}' or '-db' !"
				exit 1
			fi
			DATE=`date +%s`
			BACKUPTMPPATH=$BACKUPPATH/.tmp.restore.$DATE
			System.fs.dir.create $BACKUPTMPPATH
			echo -n Extracting backup folder...
			tar -xzf $BACKUPFILE -C $BACKUPTMPPATH > /dev/null 2>&1
			System.print.status green DONE

			if echo $OPTIONS | fgrep -qw db; then
				if [ -e "$BACKUPTMPPATH/db.backup" ]; then
					if ! Database.check $DOMAIN; then
						Database.create $DOMAIN
					else
						ID=$DOMAIN
						for GROUPNAME in $ACTIVATEDGROUPS; do
							domainrebuilder false
						done
						for GROUPNAME in $DISABLEPROCESSED; do
							$0 restart $GROUPNAME
						done
					fi
					echo -n "Restore database..."
					pg_restore -d $DOMAIN -Oc -U pgsql $BACKUPTMPPATH/db.backup > /dev/null 2>&1
					System.print.status green DONE
					Database.counters.correct $DOMAIN
					if [ "$ID" ]; then
						for GROUPNAME in $DISABLEPROCESSED; do
							domainrebuilder true
						done
						for GROUPNAME in $DISABLEPROCESSED; do
							$0 restart $GROUPNAME -reset=all
						done
					fi
				else
					System.print.error "no database in backup!"
				fi
			fi
			for ITEM in $BACKUPGROUPS; do
				if [ ! -d $BACKUPTMPPATH/$ITEM ]; then
					System.print.error "no '$ITEM' group in backup!"
				fi
				GROUPNAME=$ITEM
				Group.getData
				System.fs.dir.create $GROUPPATH/protected/web/$DOMAIN
				echo -n "Sync domain files with '$ITEM' group..."
				rsync -qa --delete $BACKUPTMPPATH/$ITEM/ $GROUPPATH/protected/web/$DOMAIN
				System.print.status green DONE
			done
			rm -rdf $BACKUPTMPPATH
			NOW=`date +%s`
			TIME=$((NOW-STARTTIME))
			UPTIME=`getuptime $TIME`
			System.print.info "Restoration of '$DOMAIN' has been completed! Restoration time: $UPTIME"
		else
			#TODO: if no domain setted, then list domain that have backups and last backup date
			if [ -d $BACKUPPATH ]; then
				echo Backups list:
				if Console.isSettingExist domain; then
					DOMAIN=`Console.getSettingValue domain`
					BACKUPS=`ls $BACKUPPATH/$DOMAIN | grep tar.gz`
					for ITEM in $BACKUPS; do
						printf "\t\33[1m$BACKUPPATH/$ITEM\33[0m\n"
					done
				else
					echo `ls $BACKUPPATH`
				fi
			fi
			System.print.syntax
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
	readlog)
		setParametrsToVars INSTANCE LOGFILENAME
		GROUPNAME=$(echo ${INSTANCE} | tr -d "[0-9]")
		Group.getData ${GROUPNAME} || exit 1
		if [ "${GROUPNAME}" = "${INSTANCE}" ]; then
			INSTANCE=$(echo ${ACTIVEINSTANCES} | cut -d" " -f1)
			if [ -z "${INSTANCE}" ]; then
				System.print.error "Active instances not found!"
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
				System.print.error "can not find log file!"
			fi
		else
			System.print.syntax "readlog ( {group} | {instance} ) {log}"
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
		setParametrsToVars GROUPNAME LOGLIST +
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
		System.print.info "to quit from xtail press 'Ctrl+\\\'"
		System.print.info "tail starting..."
		echo "Files: "${LOGFILES}
		xtail ${LOGFILES}
	;;
	#COMMAND:DEVEL
	mixlog)
		setParametrsToVars GROUPNAME YEAR MONTH DAY HOUR MINUTE SECOND
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
			System.print.syntax "dump ( snitch | start | stop ) {groupname}"
			if [ "${GROUPS}" ]; then
				Group.groups.getStatus
			else
				System.print.error "no groups exist!"
			fi
			exit 1
		}
		setParametrsToVars MOD GROUPNAME
		GROUPNAME=$(echo ${GROUPS} | tr " " "\n" | grep -w "${GROUPNAME}")
		if [ -z "${GROUPNAME}" ]; then
			Syntax.dig
		fi
		case ${MOD} in
			snitch)
				${0} dump -group=${GROUPNAME} -mail
				System.print.info "Watching to logs..."
				WATCHDOGPIDFILE=/var/run/watchdogtolog.pid
				/usr/sbin/daemon -p ${WATCHDOGPIDFILE} ${0} watchlog ${GROUPNAME} > /tmp/acmbsd.watchlog.log 2>&1
				sleep 60
				killbylockfile ${WATCHDOGPIDFILE}
				Network.message.send "$(cat /tmp/acmbsd.watchlog.log)" "ACM.CM dig" "plain"
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
		setParametrsToVars GROUPNAME
		if Group.getData ${GROUPNAME} && Group.isActive ${GROUPNAME}; then
			INSTANCE=$(echo ${ACTIVEINSTANCES} | cut -d " " -f 1)
			Instance.getData
			if ! System.daemon.isExist ${DAEMONPID}; then
				System.print.error "daemon not started!"
				exit 1
			fi
			if [ ! -e ${ACMOUT} ]; then
				System.print.error "can not find log file!"
				exit 1
			fi
			TAILPIDFILE=/var/run/dumptail.pid
			DUMPFILE=/tmp/acmbsd.dump.${INSTANCE}.log
			/usr/sbin/daemon -p ${TAILPIDFILE} tail -n 0 -f ${ACMOUT} > ${DUMPFILE} 2>&1
			if kill -3 ${DAEMONPID} ; then
				System.print.info "Please, do not break this process, script use daemon to cut dump from log file. Time limit is ten seconds!"
				echo -n "Waiting for dump..."
				COUNT=0
				while true
				do
					sleep 1
					if cat ${DUMPFILE} | grep "JNI global references" > /dev/null 2>&1 ; then
						System.print.status green "DONE"
						sleep 1
						killbylockfile ${TAILPIDFILE} > /dev/null 2>&1
						if ! echo ${OPTIONS} | grep read > /dev/null 2>&1 ; then
							Network.message.send "$(cat ${DUMPFILE})" "ACM.CM dump" "plain"
						fi
						echo
						if ! echo ${OPTIONS} | grep mail > /dev/null 2>&1 ; then
							less -cSwM +G ${DUMPFILE}
						fi
						break
					fi
					if [ "$COUNT" = 10 ]; then
						System.print.status red FAILED
						killbylockfile $TAILPIDFILE > /dev/null 2>&1
						break
					fi
					COUNT=$((COUNT + 1))
					echo -n .
				done
			else
				System.print.error 'can not do dump!'
			fi
			exit 0
		fi
		System.print.syntax "dump {groupname} [-mail] [-read]"
		System.print.info "-mail and -read default to true, you can choose one if need!"
		exit 1
	;;
	#COMMAND:DEVEL
	seqcorrect)
		if [ "$MODS" ]; then
			Database.counters.correct $MODS
		else
			echo "acmbsd seqcorrect {dbname}"
		fi
	;;
	#COMMAND:NOTREADY
	checksites)
		setParametrsToVars GROUPNAME
		GROUPNAME=`echo $GROUPS | tr ' ' '\n' | grep -w "$GROUPNAME"`
		[ -z "$GROUPNAME" ] && Syntax.checksites && exit 1
		Group.getData $GROUPNAME
		domainschecker
	;;
	#COMMAND:DEVEL
	dirs)
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
				System.print.status green DONE
			else
				System.print.status red FAILED
				System.print.error 'database is already exist!'
			fi
		else
			System.print.syntax 'createdb {dbName}'
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
		setParametrsToVars GROUPNAME
		[ "$GROUPNAME" ] && Group.create $GROUPNAME || Syntax.checksites exit
		GROUPZONEDIR="`$GROUPNAME.getField PROTECTED`/export/dns"
		Named.reload
	;;
	#COMMAND:DEVEL
	dmesg)
		setParametrsToVars PARAM1
		[ "$PARAM1" ] && Group.create ${PARAM1} && ${PARAM1}.isActive > /dev/null && PARAM1=$(${PARAM1}.getInstanceActive | cut -d' ' -f1)
		if Instance.create ${PARAM1} && ${PARAM1}.isExist && ${PARAM1}.isActive; then
			telnet $(${PARAM1}.getField INTIP) 14024
		else
			Syntax.telnet && exit 1
		fi
	;;
	#COMMAND:DEVEL
	ssh)
		setParametrsToVars PARAM1
		[ "$PARAM1" ] && Group.create ${PARAM1} && ${PARAM1}.isActive > /dev/null && PARAM1=$(${PARAM1}.getInstanceActive | cut -d' ' -f1)
		if Instance.create ${PARAM1} && ${PARAM1}.isExist && ${PARAM1}.isActive; then
			ssh -p 14022 $(${PARAM1}.getField INTIP)
		else
			Syntax.telnet && exit 1
		fi
	;;
	#COMMAND:DEVEL
	telnet)
		setParametrsToVars PARAM1
		[ "$PARAM1" ] && Group.create ${PARAM1} && ${PARAM1}.isActive > /dev/null && PARAM1=$(${PARAM1}.getInstanceActive | cut -d" " -f1)
		if Instance.create ${PARAM1} && ${PARAM1}.isExist && ${PARAM1}.isActive; then
			telnet $(${PARAM1}.getField INTIP) 14023
		else
			Syntax.telnet && exit 1
		fi
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
		Java.classpath() {
			local FIRST=true
			for ITEM in $(ls $1 | fgrep -w jar); do
				test $FIRST = true && FIRST=false || echo -n :
				echo -n $1/$ITEM
			done
			echo
		}
		setParametrsToVars GROUPNAME CLASS P_ARGS +
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

netsync() {
	echo "su - ${SCRIPTNAME} -c \"rsync -avCO --perms --delete ${1}/ ${2}\""
	su - ${SCRIPTNAME} -c "rsync -avCO --perms --delete ${1}/ ${2}"
}
netsyncbidi() {
	su - ${SCRIPTNAME} -c "rsync -auzv --perms ${1}/ ${2}"
	su - ${SCRIPTNAME} -c "rsync -auzv --perms ${2}/ ${1}"
}
		HOST=$(getSettingValue host)
		GROUPNAME=$(getSettingValue group)
		if ! Group.getData ${GROUPNAME} || test -z "${HOST}"; then
			Syntax.cluster
			exit 1
		fi
		case ${MODS} in
			meet)
#				System.nextrelease
# !!!!!!!! TODO FUNCTION !!!!!!!!!
	#				if System.requirePermission ; then
	#				fi
				if [ ! -f "${ACMBSDPATH}/.ssh/id_rsa" -o ! -f "${ACMBSDPATH}/.ssh/id_rsa.pub" ]; then
					su - acmbsd -c "ssh-keygen -q -N '' -f ${ACMBSDPATH}/.ssh/id_rsa -t rsa"
				fi
				cat ${ACMBSDPATH}/.ssh/id_rsa.pub
				#| ssh $(Console.getSettingValue user)@$(Console.getSettingValue host) "cat - >> ${ACMBSDPATH}/.ssh/authorized_keys"
			;;
			syncto)
				System.nextrelease
				echo "Sync to '${SCRIPTNAME}@${HOST}:${WEB}' from '${WEB}'"
				netsync "${WEB}" "${SCRIPTNAME}@${HOST}:${WEB}"
			;;
			syncfrom)
				echo "Sync from '${SCRIPTNAME}@${HOST}:${WEB}' to '${WEB}'"
				netsync "${SCRIPTNAME}@${HOST}:${WEB}" "${WEB}"
#				rsync -avCO --delete acmbsd@${HOST}:/usr/local/acmgroups/test/protected/conf/ /usr/local/acmgroups/test/protected/conf
#				rsync -avCO --delete acmbsd@${HOST}:/usr/local/acmgroups/test/protected/export/dns /usr/local/acmgroups/test/protected/export/dns
			;;
			syncbidi)
				System.nextrelease
				echo "Sync '${SCRIPTNAME}@${HOST}:${WEB}' with '${WEB}'"
				netsyncbidi "${SCRIPTNAME}@${HOST}:${WEB}" "${WEB}"
			;;
			*)
				Syntax.cluster
			;;
		esac
	;;
	#COMMAND:DEVEL
	systemcheck)
		GROUPNAME=$2
		[ -z "$GROUPNAME" ] && System.print.error 'can not find group' && exit 1
		Group.create $GROUPNAME instances
		$GROUPNAME.debug
#		exit 1
#		GROUPNAME=temp
		echo && echo && echo 00
		Group.create $GROUPNAME
		echo && echo && echo 11
		$GROUPNAME.add
		echo && echo && echo 22
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
	csynchandler)
# setPermission after csync
		setParametrsToVars GROUPNAME FILES +
		Group.create $GROUPNAME
		$GROUPNAME.cluster.dataCheck
		echo "CHOWN ${GROUPNAME}1:$GROUPNAME" > /tmp/csynchandler.log
		chown -v ${GROUPNAME}1:$GROUPNAME ${FILES} >> /tmp/csynchandler.log
		echo "CHMOD 770" >> /tmp/csynchandler.log
		chmod -v 770 ${FILES} >> /tmp/csynchandler.log
#		Network.message.send2 "/tmp/csynchandler.log" "Cluster '$GROUPNAME' synchandler log" "${FILES}"
	;;
	#COMMAND:DEVEL
	keep)
		System.waiting 60
	;;
	#COMMAND:DEVEL
	devzone)
		Named.zonefile
		exit 1
		Group.create test
		test.cluster.connect
	;;
	#COMMAND:DEVEL
	access)
		USERS='acmbsd'
		ADMIN=`Config.setting.getValue adminusers`
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
