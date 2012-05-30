#!/bin/sh
# azet@azet.org
# MIT License (http://www.opensource.org/licenses/mit-license.php)
#
# checks fail2ban logs and mails admin/abuse@ 
# hacked this in 30 mins, not a nice code, i know.. but it works.
#################################################################
#debug:
set -vx

#config:
fail2ban_serve_notice_addr="fail2ban_serve_notice@tartaros.azet.org"
replyto_addr="abuse@azet.org"

cleanup() {
	echo ">> cleaning up TMP logfile"
	[ -f /tmp/fail2ban_serve_notice.log ] && rm -f /tmp/fail2ban_serve_notice.log
	exit 0
}
trap 'cleanup' 1 2 9 11 15

echo ">> current fail2ban log (uniq & sorted output):\n\n"
cat /var/log/fail2ban.log | sort -n | uniq

echo -e "\n>> proceeding with whois of banned IPs: "
for banned_ip in `sudo egrep '(Ban|WARNING)' /var/log/fail2ban.log | tr -d 'Ban' | tr -d 'Unban' | awk '{ print $6 }' | uniq | sort -n -u`; do
	echo "IP: $banned_ip" >> /tmp/fail2ban_serve_notice.log
	whois $banned_ip | grep abuse@
	whois -raA $banned_ip | grep e-mail | awk '{ print $2 }'
	echo -n '.' 1>&2
done | grep -Eiorh '(mailto:|)([[:alnum:]_.-]+@[[:alnum:]_.-]+?\.[[:alpha:].]{2,6})' | sort | uniq >> /tmp/fail2ban_serve_notice.log

bannedips=`grep 'IP:' /tmp/fail2ban_serve_notice.log | uniq`
echo -e '\n\n'; for mail in `grep '@' /tmp/fail2ban_serve_notice.log | uniq`; do
	echo ">> sending mail to $mail"
	cat << EOM | /usr/sbin/sendmail -t
To: ${mail}
From: ${fail2ban_serve_notice_addr}
Reply-To: ${replyto_addr}
Subject: [ABUSE] Network Attack from your IP-Range detected!
Body:

Hi fellow Engineer/Admin/SysOp!

Please be aware that fail2ban banned one or more of your IPs due to Denial of Service or Break-In attempts!
You are obliged to fix this issue immediately (http://en.wikipedia.org/wiki/Denial-of-service_attack#Legality)

This might be an distributed attack, all currently banned IPs:
${bannedips}

Thank You!
.
EOM
done
cleanup
#EOF
