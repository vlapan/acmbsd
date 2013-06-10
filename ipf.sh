#!/bin/sh -e

ipf.conf() {
	cat <<-EOF
		# local interface
		pass in  quick on lo0 all
		pass out quick on lo0 all

		# tap interface
		pass in  quick on tap0 all
		pass out quick on tap0 all

		# local addrs
		pass in  quick from 10.0.0.0/8 to any
		pass out quick from 10.0.0.0/8 to 10.0.0.0/8

		pass in  quick from 192.168.0.0/16 to any
		pass out quick from 192.168.0.0/16 to 192.168.0.0/16

		pass in  quick from 172.16.0.0/12 to any
		pass out quick from 172.16.0.0/12 to 172.16.0.0/12
	EOF
	for IF in $@; do
		cat <<-EOF
			# block out multicast
			block out quick on $IF from 224.0.0.0/3
			# allow other out
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
			# mosh
			pass in  quick on $IF proto udp from any to any port = 60000 keep state
			# acm.ssh
			pass in  quick on $IF proto tcp from any to any port = 14022 keep state
			# vpn
			pass in  quick on $IF proto tcp from any to any port = 655 keep state
			pass in  quick on $IF proto udp from any to any port = 655 keep state
			pass in  quick on $IF proto tcp from any to any port = 14723 keep state
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

#OLD: base.file.checkLine /etc/ipfw.rules "add 00100 allow tcp from any to any 22,53,80,443,2401,10000 in"
ipf.check() {
	System.fs.dir.create /etc/ipf/ > /dev/null 2>&1

	#TODO: option to select trusted interfaces other than lo0
	IF_TRUSTED='lo0 tap0'
	IF_FIREWALLED=`/sbin/ifconfig -lu | sed 's/lo0 //g' | sed 's/ lo0//g' | sed 's/tap0 //g' | sed 's/ tap0//g'`

	out.info "Trusted interfaces: $IF_TRUSTED"
	out.info "Firewalled interfaces: $IF_FIREWALLED"

	ipf.conf "$IF_FIREWALLED" > /etc/ipf/ipf.conf

	if [ ! -f /etc/ipf/ipnat.conf ]; then
		touch /etc/ipf/ipnat.conf
	fi

	base.file.checkLine /etc/rc.conf ipfilter_enable=\"YES\"
	base.file.checkLine /etc/rc.conf ipnat_enable=\"YES\"
	base.file.checkLine /etc/rc.conf ipmon_enable=\"YES\"
	base.file.checkLine /etc/rc.conf ipfs_enable=\"YES\"
	base.file.checkLine /etc/rc.conf ipfilter_rules=\"/etc/ipf/ipf.conf\"
	base.file.checkLine /etc/rc.conf ipnat_rules=\"/etc/ipf/ipnat.conf\"

	IPFSTATUS=`/etc/rc.d/ipfilter status | grep Running | cut -d: -f2 | tr -d ' '`
	if [ "$IPFSTATUS" = yes ]; then
		/etc/rc.d/ipfilter reload
		/etc/rc.d/ipnat reload
	else
		/etc/rc.d/ipfilter start
		/etc/rc.d/ipnat start
	fi
}