#!/bin/sh -e

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
txtbld='\33[1m'    # Bold
txtrst='\33[0m'    # Text Reset

out.error() {
	printf "${bldred}Error:$txtrst $@\n" && return 0
}
out.info() {
	printf "${txtbld}Info:$txtrst $@\n" && return 0
}
out.syntax() {
	printf "${txtbld}Syntax:$txtrst"
	out.str "$@"
	return 0
}
out.example() {
	printf "${txtbld}Example: $@$txtrst\n" && return 0
}
out.str() {
	printf "\t$SCRIPTNAME $@\n" && return 0
}
out.nextrelease() {
	out.error 'feature not available, maybe next release!' && exit 1
}
out.valuechange() {
	if [ "$4" ]; then
		echo -n "Changing value of '$1' setting for '$2' from '$4' to '$3'... "
	else
		echo -n "Changing value of '$1' setting for '$2' to '$3'... "
	fi
}
out.status() {
	if [ "$(echo $OPTIONS | fgrep -w verbose)" -o -z "$SIMPLEOUTPUT" ]; then
		case $1 in
			red) printf "[ $bldred$2$txtrst ]\n";;
			green) printf "[ $bldgrn$2$txtrst ]\n";;
			yellow) printf "[ $bldylw$2$txtrst ]\n";;
		esac
	else
		case $1 in
			red) printf "$txtred;$txtrst";;
			green) printf "$txtgrn:$txtrst";;
			yellow) printf "$txtylw|$txtrst";;
		esac
	fi
	return 0
}
out.message() {
	if [ "$(echo $OPTIONS | fgrep -w verbose)" -o -z "$SIMPLEOUTPUT" ]; then
		[ waitstatus = "$2" ] && echo -n "$1 " || echo $1
	else
		[ "$3" ] && echo -n $3
	fi
}
