#!/bin/sh -e

#IMPORT
load.module cfg out

NAMEDCONFFILE=/usr/local/etc/namedb/named.conf

#TODO: transfer zones from $GROUPPATH/protected/export/dns to $SHARED/dns
Named.transform(){
	local FILE=$1
	while [ 1 ]; do
		read LINE || break
		if [ "$(echo ${LINE} | fgrep var_)" ]; then
			local GROUPNAME=""
			for GROUPNAME in ${GROUPS}; do
				if [ "$(echo ${LINE} | fgrep var_${GROUPNAME})" ]; then
					Group.create ${GROUPNAME} > /dev/null 2>&1
					local PUBLICIP="$(${GROUPNAME}.getPublicIP)"
					if [ "${PUBLICIP}" ]; then
						echo -n "${LINE}" | sed "s/var_${GROUPNAME}/${PUBLICIP}/"
					else
						local IPLIST=$(cfg.getValue "${GROUPNAME}-extip" | sed "s/;/ /")
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
		mail	2419200	CNAME	ghs.googlehosted.com.
	EOF
}

Named.conf.options() {
	cat <<-EOF
		options {
			directory "/usr/local/etc/namedb";
			version "[Secured]";
			pid-file "/var/run/named/pid";
			allow-transfer {$NAMEDTRANSFER};
			multi-master yes;
			dump-file "/var/dump/named_dump.db";
			statistics-file "/var/stats/named.stats";
			recursion no;
			listen-on {any;};
		};
		controls {
 			inet 127.0.0.1 allow {localhost;};
		};
	EOF
}

Named.conf.zone() {
	#PARAM: $1 - zone name
	#PARAM: $2 - zone file path
	cat <<-EOF
		zone "$1" {
			type master;
			file "$2";
		};
	EOF
}

Named.reload() {
	ZONEDIR=/usr/local/etc/namedb/master/$GROUPNAME
	echo "ZONEDIR:$ZONEDIR,GROUPZONEDIR:$GROUPZONEDIR"
	System.fs.dir.create $ZONEDIR
	System.fs.dir.create $GROUPZONEDIR
	ZONES=`ls $GROUPZONEDIR | grep .dns`
	local FILTEREDZONES=''
	if [ "$1" ]; then
		for ITEM in $1; do
			echo $ZONES | fgrep -qw $ITEM || continue
			[ "$FILTEREDZONES" ] && FILTEREDZONES="$FILTEREDZONES $ITEM" || FILTEREDZONES="$ITEM"
		done
	else
		FILTEREDZONES=$ZONES
	fi
	local NAMEDCONF=""
	if ! fgrep -qw mainoptions $NAMEDCONFFILE; then
		#EXTIPS=`cfg.getValue extip` && EXTIPS="`echo -n $EXTIPS | sed 's/,/;/'`;"
		#TODO: transfers auto lookup
		NAMEDTRANSFER=`cfg.getValue namedtransfer` && NAMEDTRANSFER="`echo $NAMEDTRANSFER | sed 's/,/;/g'`;" || NAMEDTRANSFER='"none";'
		#TODO:echo '82.179.192.192;82.179.193.193'
		#NAMEDCONF="options {directory \"/usr/local/etc/namedb\";version \"[Secured]\";pid-file \"/var/run/named/pid\";allow-transfer {$NAMEDTRANSFER};multi-master yes;dump-file \"/var/dump/named_dump.db\";statistics-file \"/var/stats/named.stats\";listen-on {any;};}; controls {inet 127.0.0.1 allow {localhost;};}; //acm generatedoptions\n"
		NAMEDCONF="`Named.conf.options | tr -d '\n' | tr -d '\t'` //acm generatedoptions\n"
	fi
	rm -f $ZONEDIR/*
	for ITEM in $FILTEREDZONES; do
		echo -n $ITEM:
		Named.transform $GROUPZONEDIR/$ITEM > $ZONEDIR/$ITEM
	done
	for ITEM in $ZONES; do
		ZONE=${ITEM%%.dns}
		NAMEDCONF="${NAMEDCONF}zone \"$ZONE\" {type master;file \"$ZONEDIR/$ITEM\";}; //acm group=$GROUPNAME\n"
	done
	#TODO: use 'mktemp'
	sed -i '' "/group=$GROUPNAME/d;/generatedoptions/d" /usr/local/etc/namedb/named.conf
	chown -R root:wheel /usr/local/etc/namedb/ && chmod -R 0755 /usr/local/etc/namedb/
	chown -R root:wheel /usr/local/etc/namedb/master && chmod -R 0755 /usr/local/etc/namedb/master
	chown -R bind:wheel /usr/local/etc/namedb/slave && chmod -R 0755 /usr/local/etc/namedb/slave
	chown -R bind:wheel /usr/local/etc/namedb/dynamic && chmod -R 0755 /usr/local/etc/namedb/dynamic
	chown -R bind:wheel /usr/local/etc/namedb/working && chmod -R 0755 /usr/local/etc/namedb/working
	printf "$NAMEDCONF" >> $NAMEDCONFFILE
	echo
	if ! /usr/local/etc/rc.d/named reload; then
		/usr/local/etc/rc.d/named restart
	fi
}

Named.check() {
	GROUPZONEDIR=`$GROUPNAME.getField PROTECTED`/export/dns
	NAMEDRELOADCKSUM=`cfg.getValue $GROUPNAME-dnsreloadcksum`
	NAMEDRELOADFILE=$GROUPZONEDIR/.reload
	[ ! -f "$NAMEDRELOADFILE" ] && touch $NAMEDRELOADFILE
	local CKSUM=`ls -lT $GROUPZONEDIR | md5 -q`
	if [ "$NAMEDRELOADCKSUM" != "$CKSUM" ]; then
		echo "$NAMEDRELOADCKSUM:$CKSUM"
		CKFILE=$ACMBSDPATH/$GROUPNAME.dns
		ZONEDIFF=''
		[ -f $CKFILE ] || touch $CKFILE
		ls -lT $GROUPZONEDIR > $CKFILE.tmp
		ZONEDIFF=`diff -a --changed-group-format='%>' --unchanged-group-format='' $CKFILE $CKFILE.tmp | tr ' ' '\n' | fgrep .dns`
		mv $CKFILE.tmp $CKFILE
		echo "ZONEDIFF:$ZONEDIFF:"
		Named.reload "$ZONEDIFF"
		cfg.setValue $GROUPNAME-dnsreloadcksum "$CKSUM"
	fi
}

#out.message 'named: module loaded'
