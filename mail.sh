#!/bin/sh -e

mail.aliases.refresh() {
	echo -n Refreshing aliases...
	# rm -f /etc/aliases.db
	newaliases
	postalias /etc/aliases
	out.status green DONE
}

mail.aliases.check() {
	echo -n "Check for /etc/mail/aliases..."
	ADMINMAIL=$(cfg.getValue "adminmail")
	if [ -z "${ADMINMAIL}" ]; then
		out.status yellow "NO EMAIL"
		return 1
	fi
	if ! cat /etc/mail/aliases | fgrep -w root: | fgrep -vw "# root:" > /dev/null 2>&1; then
		echo "root: ${ADMINMAIL}" >> /etc/mail/aliases
		out.status green ADDED
		mail.aliases.refresh
	else
		if ! cat /etc/mail/aliases | grep "${ADMINMAIL}" > /dev/null 2>&1; then
			cat /etc/mail/aliases | sed "/root:/d" > /tmp/aliases && mv /tmp/aliases /etc/mail/
			echo "root: ${ADMINMAIL}" >> /etc/mail/aliases
			out.status green REFRESHED
			mail.aliases.refresh
		else
			out.status green OK
		fi
	fi
}

#TODO: mktemp
mail.send() {
	OPTS=$@
	ADMINMAIL=`Function.getSettingValue email "$OPTS" || cfg.getValue adminmail`
	[ $ADMINMAIL ] || return 1
	for EMAIL in $ADMINMAIL; do
		printf "To: $EMAIL\n" > /tmp/msg.html
		printf "Subject: ACMBSD on `uname -n`: $2\n" >> /tmp/msg.html
		printf "Content-Type: text/$3; charset=\"us-ascii\"\n\n" >> /tmp/msg.html
		echo "$1" >> /tmp/msg.html
		echo -n "Sending email to '$EMAIL'..."
		if /usr/sbin/sendmail -f acmbsd $EMAIL < /tmp/msg.html; then
			out.status green DONE
		else
			out.status red FAILED
		fi
	done
}

mail.sendfile() {
	ADMINMAIL=$(cfg.getValue adminmail)
	[ $ADMINMAIL ] || return 1
	SUBJECT="ACMBSD on `uname -n`: $2"
	echo $3 > /tmp/msgbody
	for MAILTO in $ADMINMAIL; do
		metasend -b -s "$SUBJECT" -S 99999999 -f /tmp/msgbody -m text/plain -e none -n -f $1 -m text/plain -e base64 -t $MAILTO
	done
}

mail.check() {
	mail.aliases.refresh
	myx.common setup/postfixMailer
}

#out.message 'mail: module loaded'
