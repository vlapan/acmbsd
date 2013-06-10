umask 002
export EDITOR=nano
export VISUAL=nano
export HISTSIZE=5000
export HISTFILESIZE=20000
export HISTCONTROL=erasedups
export PROMPT_COMMAND='history -a; cp \$HISTFILE /tmp/hist_\$USER; awk -f $ACMBSDPATH/scripts/awk/reverse.awk /tmp/hist_\$USER | awk -f $ACMBSDPATH/scripts/awk/uniq.awk | awk -f $ACMBSDPATH/scripts/awk/reverse.awk > \$HISTFILE; rm /tmp/hist_\$USER; history -c; history -r;'
# ignore some common commands when searching history
export HISTIGNORE="dir:la:exit:jobs"
export CLICOLOR=YES
export LSCOLORS=ExGxFxdxCxDxDxhbadExEx
export GREP_OPTIONS='--binary-files=without-match --color=auto'
export GREP_COLOR='00;38;5;157'
export INPUTRC=/etc/inputrc
#[ "\${BASH-no}" != no -a -r /usr/local/etc/bashprofile ] && . /usr/local/etc/bashprofile
[ -x /usr/local/bin/screen ] && [ "\$TERM" != screen ] && (
	export PS1='\[\e[0;32m\]\u@\h\[\e[m\]:\[\e[0;34m\]\w\[\e[m\]\[\e[0;32m\]\$\[\e[m\] \[\e[0m\]'
	/usr/local/bin/screen -s /usr/local/bin/bash -q -O -U -D -R
	echo 'this is your main shell, you should type "exit" and reconnect to get you "screen" session created.'
)