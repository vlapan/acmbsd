#!/bin/sh
# acmbsd lib: Group type
THIS.init() {
	echo "Group 'THIS' object init..."
	export THIS_ID=`Group.default.id THIS`
	export THIS_HOME=$DEFAULTGROUPPATH/THIS
	export THIS_PUBLIC=$THIS_HOME/public
	export THIS_PUBLICBACKUP=$THIS_HOME/public-backup
	export THIS_PROTECTED=$THIS_HOME/protected
	export THIS_LOGS=$THIS_HOME/logs
	export THIS_CONF=$THIS_PROTECTED/conf
	export THIS_SERVERSCONF=$THIS_CONF/servers.xml
	export THIS_WEB=$THIS_PROTECTED/web
	export THIS_VERSIONFILE=$THIS_PUBLIC/version/version
	export THIS_CLUSTERDATAFILE=$THIS_PROTECTED/export/serverlist
	export THIS_CLUSTERCONNECTEDFILE=$THIS_HOME/clusterconnectedlist
}
THIS.debug() {
	echo
	echo "TYPE=`THIS.getType`"
	echo "NAME=THIS"
	echo "ID=`THIS.getField ID`"
	echo "HOME=`THIS.getField HOME`"
	echo "PUBLIC=`THIS.getField PUBLIC`"
	echo "PUBLICBACKUP=`THIS.getField PUBLICBACKUP`"
	echo "PROTECTED=`THIS.getField PROTECTED`"
	echo "LOGS=`THIS.getField LOGS`"
	echo "CONF=`THIS.getField CONF`"
	echo "SERVERSCONF=`THIS.getField SERVERSCONF`"
	echo "WEB=`THIS.getField WEB`"
	echo "VERSIONFILE=`THIS.getField VERSIONFILE`"
	echo -n 'ISEXIST='
	if THIS.isExist; then
		echo "VERSION=`THIS.getVersion`"
		echo "INSTANCELIST=`THIS.getInstanceList`"
		echo "INSTANCECOUNT=`THIS.getInstanceCount`"
		echo "INSTANCEACTIVE=`THIS.getInstanceActive`"
		echo "MEMORY=`THIS.getMemory`"
		echo "EXTIP=`THIS.getExtIP`"
		echo "GROUPTYPE=`THIS.getGroupType`"
		echo "BRANCH=`THIS.getBranch`"
		echo "ISACTIVE=`THIS.isActive && echo true || echo false`"
		for INSTANCE in `THIS.getInstanceList`; do
			$INSTANCE.debug
		done
	fi
}
THIS.isExist() {
	[ -d "$THIS_PUBLIC" ] && return 0 || return 1
}
THIS.getVersion() {
	[ -f $THIS_VERSIONFILE ] && cat $THIS_VERSIONFILE || echo 0
}
THIS.getInstanceList() {
	#HINT: trim or makelist function: tr '\n' ' ' | sed 's/^ *//;s/ *$//'
	THIS.isExist && [ -d $THIS_HOME ] && ls $THIS_HOME | fgrep -w private | cut -d- -f1 | tr '\n' ' ' | sed 's/^ *//;s/ *$//' && return 0 || return 1
}
THIS.getInstanceCount() {
	THIS.getInstanceList | wc -w | tr -d ' '
}
THIS.getInstanceActive() {
	local FIRST=true
	for ITEM in `THIS.getInstanceList`; do
		#TODO: REDO
		local ITEMPRIVATE=$THIS_HOME/$ITEM-private
		local ITEMDAEMONFLAG=$ITEMPRIVATE/daemon.flag
		if [ -f "$ITEMDAEMONFLAG" ]; then
			[ $FIRST = true ] && FIRST=false || echo -n ' '
			echo -n "$ITEM"
		fi
	done
	echo
}
THIS.isSingleActive() {
	[ -z "`THIS.getInstanceActive`" -o "`THIS.getInstanceActive | wc -w | tr -d ' '`" = 1 ] && return 0 || return 1
}
THIS.setMemory() {
	if Group.isMemory $1 && test $1 != "`THIS.getMemory`"; then
		System.print.message.valuechange memory THIS $1 `THIS.getMemory`
		Config.setting.setValue THIS-memory $1
		System.print.status green CHANGED
	fi
}
THIS.getMemory() {
	local MEMORY=`Config.setting.getValue THIS-memory`
	[ "$MEMORY" ] && echo $MEMORY || echo 256m
}
THIS.setExtIP() {
	[ "$1" ] || return 1
	Config.setting.setValue THIS-extip "$1"
	for INSTANCE in `THIS.getInstanceActive`; do
		Instance.create $INSTANCE && $INSTANCE.openToPublic
	done
	return 0
}
THIS.getExtIP() {
	Config.setting.getValue THIS-extip
}
THIS.setPublicIP() {
	local PUBLICIP=`Config.setting.getValue THIS-publicip`
	[ "$1" != "$PUBLICIP" ] || return 1
	System.print.message.valuechange publicip THIS "$1" "$PUBLICIP"
	[ "$1" ] && Config.setting.setValue THIS-publicip "$1" || Config.setting.remove THIS-publicip
	System.print.status green CHANGED
	GROUPZONEDIR="`THIS.getField PROTECTED`/export/dns"
	GROUPNAME=THIS
	Named.reload
}
THIS.getPublicIP() {
	local PUBLICIP=`Config.setting.getValue THIS-publicip`
	[ "$PUBLICIP" ] && echo $PUBLICIP || echo `THIS.getExtIP`
}
THIS.setGroupType() {
	if Group.isType "$1" && [ $1 != "`THIS.getGroupType`" ]; then
		System.print.message.valuechange type THIS $1 `THIS.getGroupType`
		Config.setting.setValue THIS-type $1
		System.print.status green CHANGED
	fi
}
THIS.getGroupType() {
	local GROUPTYPE=`Config.setting.getValue THIS-type`
	[ "$GROUPTYPE" ] && echo $GROUPTYPE || echo standard
}
THIS.setBranch() {
	if Group.isBranch "$1" && [ $1 != "`THIS.getBranch`" ]; then
		System.print.message.valuechange branch THIS $1 `THIS.getBranch`
		Config.setting.setValue THIS-branch $1
		System.print.status green CHANGED
	fi
}
THIS.getBranch() {
	local BRANCH=`Config.setting.getValue THIS-branch`
	[ "$BRANCH" ] && echo $BRANCH || Group.default.branch THIS
}
THIS.setEA() {
	if Group.isEA "$1" && [ $1 != "`THIS.getEA`" ]; then
		System.print.message.valuechange ea THIS $1 `THIS.getEA`
		Config.setting.setValue THIS-ea $1
		System.print.status green CHANGED
	fi
}
THIS.getEA() {
	local EA=`Config.setting.getValue THIS-ea`
	[ "$EA" ] && echo $EA || Group.default.ea THIS
}
THIS.setLogLevel() {
	Group.isLogLevel "$1" && [ $1 != "`THIS.getLogLevel`" ] || return 1
	System.print.message.valuechange loglevel THIS $1 `THIS.getLogLevel`
	if Config.setting.setValue THIS-loglevel $1; then
		System.print.status green CHANGED && return 0
	else
		System.print.status red FAILED && return 1
	fi
}
THIS.getLogLevel() {
	local LOGLEVEL=`Config.setting.getValue THIS-loglevel`
	[ "$LOGLEVEL" ] && echo $LOGLEVEL || Group.default.loglevel THIS
}
THIS.setInstanceCount() {
	([ "`THIS.getInstanceCount`" = 0 ] || [ "$2" ] || [ "`THIS.getGroupType`" = extended ]) || return 1
	Group.isDigit "$1" && [ "$1" != "`THIS.getInstanceCount`" ] || return 1
	System.print.message.valuechange instances THIS $1 `THIS.getInstanceCount` && echo
	local ICOUNT=`THIS.getInstanceCount`
	if [ $ICOUNT -lt $1 ]; then
		while true; do
			ICOUNT=$(($ICOUNT+1))
			local INSTANCE="THIS$ICOUNT"
			Instance.create $INSTANCE && $INSTANCE.add
			[ $ICOUNT -ge $1 ] && return 0
		done
	else
		while true; do
			local INSTANCE="THIS$ICOUNT"
			Instance.create $INSTANCE && $INSTANCE.remove
			ICOUNT=$(($ICOUNT-1))
			[ $ICOUNT -le $1 ] && return 0
		done
	fi
	return 1
}
THIS.setActive() {
	[ "$1" = true ] && Config.setting.setValue THIS-activated true || Config.setting.remove THIS-activated
}
THIS.isActive() {
	[ "`Config.setting.getValue THIS-activated`" ] && return 0 || return 1
}
THIS.getSettings() {
	printf "Settings info:\n"
	printf "\t-extip=`THIS.getExtIP` - IP-address that not used by acm.cm already\n"
	printf "\t-publicip=`THIS.getPublicIP` - IP-address for DNS, default is the same with 'extip'\n"
	printf "\t-memory=`THIS.getMemory` - memory for each one instance in group\n"
	printf "\t-branch=`THIS.getBranch` - branch of acm.cm5, value can be 'stable', 'release' or 'current'\n"
	printf "\t-type=`THIS.getGroupType` - type of group, can be 'standard', 'primitive', 'extended' or 'parallel'\n"
	printf "\t-instances=`THIS.getInstanceCount` - instances count in group, can be changed if type 'extended', default '2'\n"
	printf "\t-loglevel=`THIS.getLogLevel` - can be 'NORMAL', 'MINIMAL', 'DEBUG' or 'DEVEL'\n"
	printf "\t-ea=`THIS.getEA` - can be 'enable' or 'disable'\n"
}
THIS.config() {
	local OPTS="`echo $@ | tr ' ' '\n'`"
	local EXTIP=`Function.getSettingValue extip "$OPTS" || Console.getSettingValue extip`
	[ "$EXTIP" ] && THIS.setExtIP "$EXTIP"
	THIS.setPublicIP `Function.getSettingValue publicip "$OPTS" || Console.getSettingValue publicip || echo`
	THIS.setGroupType `Function.getSettingValue type "$OPTS" || Console.getSettingValue type || THIS.getGroupType`
	THIS.setMemory `Function.getSettingValue memory "$OPTS" || Console.getSettingValue memory || THIS.getMemory`
	THIS.setBranch `Function.getSettingValue branch "$OPTS" || Console.getSettingValue branch || THIS.getBranch`
	THIS.setEA `Function.getSettingValue ea "$OPTS" || Console.getSettingValue ea || THIS.getEA`
	THIS.setLogLevel `Function.getSettingValue loglevel "$OPTS" || Console.getSettingValue loglevel || THIS.getLogLevel`
	THIS.setInstanceCount `Function.getSettingValue instances "$OPTS" || Console.getSettingValue instances || ([ "$(THIS.getInstanceCount)" = 0 ] && echo 2 || THIS.getInstanceCount)`
	return 0
}
THIS.isReady() {
	THIS.isExist && Group.isType $GROUPTYPE && Group.isMemory $MEMORY && Group.isBranch $BRANCH && return 0 || return 1
}
THIS.isUpdated() {
	#TODO: move this check to autoupdate
	local VERSION=`cat $ACMCM5PATH/$(THIS.getBranch)/version/version`
	echo ":1:checking for suitable update"
	if [ "`THIS.getVersion`" != "$VERSION" ]; then
		local ACMLASTMAJORVERSION=`echo $VERSION | cut -d. -f3 | cut -d/ -f1`
		local ACMMAJORVERSION=`echo $(THIS.getVersion) | cut -d. -f3 | cut -d/ -f1`
		local ACMLASTTYPEVERSION=`echo $VERSION | cut -d/ -f2 | cut -c1-1`
		local ACMTYPEVERSION=`echo $(THIS.getVersion) | cut -d/ -f2 | cut -c1-1`
		if [ "$ACMLASTMAJORVERSION" != "$ACMMAJORVERSION" -o "$ACMLASTTYPEVERSION" != "$ACMTYPEVERSION" ]; then
			echo ":2:perhaps serious update($ACMLASTMAJORVERSION-$ACMMAJORVERSION:$ACMLASTTYPEVERSION-$ACMTYPEVERSION)"
			if echo $ACMLASTTYPEVERSION | fgrep R || echo $ACMLASTTYPEVERSION | fgrep U ; then
				echo ":3.1:it is new release or update, you must have it"
				return 1
			else
				if echo $OPTIONS | fgrep -qw auto; then
					System.print.error 'major version or type is different, can not update in automatic mode'
					return 0
				else
					if echo $OPTIONS | fgrep -qw agree; then
						echo ":3.2:as you wish"
						return 1
					else
						System.print.info 'major version is different or alpha version in branch, to update run again with -agree option!'
						return 0
					fi
				fi
			fi
		else
			if echo $OPTIONS | fgrep -qw auto; then
				if echo $ACMLASTTYPEVERSION | fgrep -q R || echo $ACMLASTTYPEVERSION | fgrep -q U; then
					echo ":2:autoupdate let's go"
					return 1
				else
					echo ":2:autoupdate can't update to this version try manually!"
					return 0
				fi
			else
				echo ":2:let's go"
				return 1
			fi
		fi
	fi
	echo ":2:nothing, maybe later"
	return 0
}
THIS.update() {
	local OPTS="`echo $@ | tr ' ' '\n'`"
	echo "THIS.update"
	if Function.isOptionExist force "$OPTS" || Console.isOptionExist force || ! THIS.isUpdated; then
		THIS.sync && return 0
	fi
	return 1
}
THIS.sync() {
	local OPTS="$1"
	local VERSION=`cat $ACMCM5PATH/$(THIS.getBranch)/version/version || echo 0`
	if [ -z "$VERSION" -o "$VERSION" = 0 ]; then
		return 1
	fi
	if [ "`THIS.getVersion`" != 0 -a "$VERSION" != "`THIS.getVersion`" -a -d $THIS_PUBLIC ]; then
		echo -n Backing up ACM.CM...
		if [ -d "$THIS_PUBLICBACKUP" ]; then
			rm -rdf $THIS_PUBLICBACKUP
		fi
		cp -R $THIS_PUBLIC $THIS_PUBLICBACKUP
		System.print.status green OK
	fi
	System.message "Updating group (THIS) from '`THIS.getVersion`' to '$VERSION'..."
	if rsync -aC --delete --include='*.obj' $ACMCM5PATH/`THIS.getBranch`/ $THIS_PUBLIC; then
		System.changeRights $THIS_PUBLIC THIS THIS1
		Function.isOptionExist noalert "$OPTS" && Network.message.send "<html><p>group: THIS<br/>branch: `THIS.getBranch`<br/>installed version: `THIS.getVersion`<br/>latest version: $VERSION</p></html>" "group updated" "html"
	else
		System.print.error "something wrong!"
		return 1
	fi
	return 0
}
THIS.start() {
	#THIS.setHierarchy || return 1
	THIS.setActive true
	local TOSTART=''
	if [ "`THIS.getGroupType`" = extended ]; then
		System.message "Start type - extended"
		local FIRST=true
		local TOSTART="`THIS.getInstanceList`"
		System.message "Instances for start: $TOSTART"
		for INSTANCE in $TOSTART; do
			Function.isExist $INSTANCE.isObject || Instance.create $INSTANCE
			if [ $FIRST = true ]; then
				$INSTANCE.start
				FIRST=false
			else
				$INSTANCE.start nopublic
			fi
		done
		return 0
	fi
	if [ "`THIS.getGroupType`" = standard ]; then
		System.message "Start type - standard"
		if [ "`THIS.getInstanceActive`" ]; then
			TOSTART=`THIS.getInstanceActive`
		else
			local INSTANCELIST=`THIS.getInstanceList`
			TOSTART=`echo $INSTANCELIST | cut -d' ' -f1`
		fi
	else
		TOSTART=`THIS.getInstanceList`
	fi
	System.message "Instances for start: $TOSTART"
	for INSTANCE in $TOSTART; do
		Function.isExist $INSTANCE.isObject || Instance.create $INSTANCE
		$INSTANCE.start
	done
}
THIS.stop() {
	System.message "Instances for stop: `THIS.getInstanceActive`"
	System.isShutdown || THIS.setActive false
	for INSTANCE in `THIS.getInstanceActive`; do
		Function.isExist $INSTANCE.isObject || Instance.create $INSTANCE
		$INSTANCE.stop $ITEM
	done
}
THIS.restart() {
	#THIS.setHierarchy || return 1
	if [ "`THIS.getGroupType`" = parallel -o "`THIS.getGroupType`" = primitive ]; then
		System.message "Instances for restart: `THIS.getInstanceList`"
		for INSTANCE in `THIS.getInstanceList`; do
			Function.isExist $INSTANCE.isObject || Instance.create $INSTANCE
			$INSTANCE.restart
		done
		return 0
	fi
	if [ "`THIS.getGroupType`" = extended ]; then
		System.message "Restart type - extended"
		local INSTANCE1=`THIS.getInstanceList | cut -d' ' -f1`
		local INSTANCE2=`THIS.getInstanceList | cut -d' ' -f2`
		[ -z "$INSTANCE1" -o -z "$INSTANCE2" ] && System.print.error "can't find one of instances, check: instance1=$INSTANCE1, instance2=$INSTANCE2" && return 1
		Function.isExist $INSTANCE1.isObject || Instance.create $INSTANCE1 || return 1
		Function.isExist $INSTANCE2.isObject || Instance.create $INSTANCE2 || return 1
		$INSTANCE1.isPublic && $INSTANCE2.isPublic && System.print.info 'two instance are public!' && $INSTANCE1.closeFromPublic
		local PUBLIC=`$INSTANCE1.isPublic && echo $INSTANCE1 || echo $INSTANCE2`
		[ -z "$PUBLIC" ] && System.print.error 'no public instance' && return 1
		local RESERVED=`[ "$PUBLIC" = "$INSTANCE1" ] && echo $INSTANCE2 || echo $INSTANCE1`
		System.message "Public instance: $PUBLIC"
		System.message "Reserved instance: $RESERVED"
		System.message "Restarting reserved instance..." && $RESERVED.stop && $RESERVED.start -wait && System.message "Restarting public instance..." && $PUBLIC.stop && $PUBLIC.start nopublic && return 0 || return 1
	fi
	ACTIVEINSTANCES=`THIS.getInstanceActive`
	System.message 'Restart type - standard'
	System.message "$ACTIVEINSTANCES"
	if [ "`echo $ACTIVEINSTANCES | wc -w | tr -d ' '`" != 1 ]; then
		#TODO: print.warning
		System.print.info "two instances started but group has 'standard' mode!"
		local INSTANCE1=`THIS.getInstanceList | cut -d' ' -f1`
		local INSTANCE2=`THIS.getInstanceList | cut -d' ' -f2`
		[ -z "$INSTANCE1" -o -z "$INSTANCE2" ] && System.print.error "can't find one of instances, check: instance1=$INSTANCE1, instance2=$INSTANCE2" && return 1
		Function.isExist $INSTANCE1.isObject || Instance.create $INSTANCE1 || return 1
		Function.isExist $INSTANCE2.isObject || Instance.create $INSTANCE2 || return 1
		if $INSTANCE1.isPublic && $INSTANCE2.isPublic; then
			System.print.info 'two instance are public!' && $INSTANCE1.stop
		else
			$INSTANCE1.isPublic && $INSTANCE2.stop
			$INSTANCE2.isPublic && $INSTANCE1.stop
		fi
		ACTIVEINSTANCES=`THIS.getInstanceActive`
	fi
	if Function.isOptionExist fast "$@" || Console.isOptionExist fast ; then
		for INSTANCE in $ACTIVEINSTANCES; do
			Function.isExist $INSTANCE.isObject || Instance.create $INSTANCE
			$INSTANCE.restart
		done
		return 0
	fi
	START=`echo $(THIS.getInstanceList) | sed "s/$ACTIVEINSTANCES //" | sed "s/ $ACTIVEINSTANCES//" | sed "s/$ACTIVEINSTANCES//"`
	if [ -z "$START" ]; then
		System.print.error "Can not restart, something wrong!"
		System.print.info "Instances: $(THIS.getInstanceList)"
		System.print.info "Active instances: $ACTIVEINSTANCES"
		return 1
	fi
	Function.isExist $START.isObject || Instance.create $START
	WAIT=wait
	if Function.isOptionExist skipwarmup "$@" > /dev/null 2>&1 || Console.isOptionExist skipwarmup ; then
		WAIT=''
	else
		echo -n 'Last chance to cancel (hit CTRL+C):'
		COUNT=10
		while true
		do
			COUNT=$((COUNT - 1))
			if [ $COUNT = 0 ]; then
				System.print.status green GO
				break;
			fi
			sleep 1
			echo -n " $COUNT"
		done
	fi
	if $START.start $WAIT; then
		sleep 3
		Function.isExist $ACTIVEINSTANCES.isObject || Instance.create $ACTIVEINSTANCES
		$ACTIVEINSTANCES.stop 'cooldown'
		Network.message.send2 "`$ACTIVEINSTANCES.getField OUTPREV`" 'THIS: restarted successfully' 'Previous ACM.CMS standard output follows:'
	else
		System.print.error 'can not start second instance!'
		Network.message.send2 "`$START.getField OUT`" 'THIS: error while restarting' 'ACM.CMS out for you'
		$START.stop
	fi
}
THIS.checkUser() {
	echo -n "Check group 'THIS'..."
	if pw groupshow THIS > /dev/null 2>&1; then
		System.print.status green OK
	else
		if pw groupadd -n THIS > /dev/null 2>&1; then
			System.print.status green ADDED
		else
			System.print.status red ERROR && return 1
		fi
	fi
	echo -n "Check user '$SCRIPTNAME' is in group 'THIS'..."
	if pw groupshow THIS | fgrep -qw $SCRIPTNAME; then
		System.print.status green YES
	else
		System.print.status yellow NO
		echo -n "Adding user '$SCRIPTNAME' to group 'THIS'..."
		if pw groupmod THIS -m $SCRIPTNAME > /dev/null 2>&1; then
			System.print.status green ADDED
		else
			System.print.status red ERROR
		fi
	fi
	return 0
}
THIS.setHierarchy() {
	System.fs.dir.create $THIS_HOME || return 1
	System.fs.dir.create $THIS_PUBLIC || return 1
	System.fs.dir.create $THIS_PROTECTED || return 1
	System.fs.dir.create $THIS_LOGS || return 1
	System.fs.dir.create $THIS_CONF || return 1
	System.changeRights $THIS_PROTECTED THIS THIS1 || return 1
	System.changeRights $THIS_LOGS THIS THIS1 || return 1
	System.changeRights $THIS_PUBLIC THIS THIS1 || return 1
	System.changeRights $THIS_HOME THIS THIS1 '' -recursive=false || return 1
}
THIS.add() {
	local OPTS="`echo $@ | tr ' ' '\n'`"
	THIS.checkUser && THIS.config "$OPTS" && THIS.setHierarchy || return 1
# INITIALIZE.XML
	echo -n "Creating default 'initialize.xml'..."
	echo '<initialize><init id="ru.myx.sql.wrapper.Main" start="true"/><init id="org.postgresql.Driver" start="true"/></initialize>' > $THIS_CONF/initialize.xml
	System.print.status green DONE
	echo -n "Check for root database for instance (THIS)..."
	Database.create THIS > /dev/null 2>&1 && System.print.status green CREATED || System.print.status green FOUND
	THIS.sync
}
THIS.remove() {
	THIS.isExist || return 1
	local OPTS="`echo $@ | tr ' ' '\n'`"
	echo THIS.remove
	THIS.isActive && THIS.stop
	for INSTANCE in `THIS.getInstanceList`; do
		$INSTANCE.remove
	done
	pw groupdel THIS
	echo -n Removing group data from DB...
	Config.setting.remove THIS-
	System.print.status green DONE
	echo -n Removing public folder...
#		rm -rdf $THIS_PROTECTED > /dev/null 2>&1
	rm -rdf $THIS_PUBLIC > /dev/null 2>&1
#		rm -rdf $THIS_HOME > /dev/null 2>&1
	System.print.status green DONE
	return 0
}
THIS.cluster.dataCheck() {
	[ ! -f $THIS_CLUSTERDATAFILE ] && touch $THIS_CLUSTERDATAFILE
	if ! cat $THIS_CLUSTERDATAFILE | fgrep -qw "THIS.`hostname`"; then
		#TODO: HOSTNAME?
		HOSTNAME=`hostname`
		echo "THIS.$HOSTNAME|`THIS.getExtIP`|10.11.$THIS_ID.`getClusterId $HOSTNAME`" >> $THIS_CLUSTERDATAFILE && THIS.cluster.dataSync
	fi
}
THIS.cluster.dataSync() {
	/usr/local/sbin/csync2 -vx $THIS_CLUSTERDATAFILE
}
THIS.cluster.connect() {
	[ ! -f $THIS_CLUSTERDATAFILE ] && touch $THIS_CLUSTERDATAFILE
	for ITEM in `cat $THIS_CLUSTERDATAFILE`; do
		local HOSTNAME=`echo $ITEM | cut -d'|' -f1`
		local LOCALIP=`echo $ITEM | cut -d'|' -f3`
		ipcontrol bind lo0 $LOCALIP
		echo $HOSTNAME | fgrep -q THIS.`hostname` && continue
		[ ! -f $THIS_CLUSTERCONNECTEDFILE ] && touch $THIS_CLUSTERCONNECTEDFILE
		echo -n Connecting...
		#TODO: use PID.active
		if ps -axu | fgrep -v fgrep | fgrep -w $LOCALIP | fgrep -qw $HOSTNAME; then
			if cat $THIS_CLUSTERCONNECTEDFILE | fgrep -qw $LOCALIP; then
				System.print.status green FOUND
			else
				echo "$HOSTNAME,$LOCALIP" >> ${THIS_CLUSTERCONNECTEDFILE}
				System.print.status green CORRECTED
			fi
		else
			if su - acmbsd -c "ssh -N -f -L $LOCALIP:14027:$LOCALIP:14027 $HOSTNAME"; then
				echo `cat $THIS_CLUSTERCONNECTEDFILE | sed -l "/$LOCALIP/d"` > $THIS_CLUSTERCONNECTEDFILE
				echo "$HOSTNAME,$LOCALIP" >> $THIS_CLUSTERCONNECTEDFILE
				System.print.status green OK
			else
				System.print.status green FAILED
			fi
		fi
	done
}
THIS.createInstances() {
	THIS.isExist || return 1
	for INSTANCE in `THIS.getInstanceList`; do
		Instance.create $INSTANCE
	done
}
