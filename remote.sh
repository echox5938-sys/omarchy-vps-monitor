# Runs on the VPS (piped to `sh -s` over SSH). Prints key=value lines.
# Read-only: it only reads system state and changes nothing.
# shortcut: Debian/Ubuntu only (ufw, apt), add other distros if the VPS changes.

echo "uptime=$(cut -d. -f1 /proc/uptime)"
echo "load=$(cut -d' ' -f1 /proc/loadavg)"
echo "cpus=$(nproc)"
awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{printf "mem=%d\n", (t-a)*100/t}' /proc/meminfo
echo "disk=$(df -P / | awk 'NR==2{sub("%","",$5); print $5}')"
echo "failed_units=$(systemctl --failed --no-legend --plain 2>/dev/null | wc -l)"

# One line per bad attempt: unknown user, wrong password, or rejected key.
echo "ssh_fails=$(journalctl -u ssh -u sshd --since '24 hours ago' -q --no-pager 2>/dev/null |
  grep -cE 'Invalid user|Failed password for [^i]|Connection closed by authenticating user')"
echo "firewall=$(ufw status 2>/dev/null | awk 'NR==1{print $2}')"
# sshd -T shows only the global value, so also flag any Match block that turns passwords
# back on (conservative: counts it even if no user matches). Empty output reads as "on".
pw=$(sshd -T 2>/dev/null | awk '/^passwordauthentication /{print $2}')
match_pw=$(cat /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null |
  awk 'tolower($1)=="match"{m=1} m && tolower($1)=="passwordauthentication" && tolower($2)=="yes"{print "yes"; exit}')
[ "$pw" = no ] && [ "$match_pw" = yes ] && pw=match
echo "password_login=$pw"
if command -v fail2ban-client >/dev/null 2>&1; then
  echo "fail2ban=$(systemctl is-active fail2ban 2>/dev/null)"
else
  echo "fail2ban=missing"
fi

# -s only simulates. Counts come from the package lists the VPS last downloaded.
pending=$(apt-get -s upgrade 2>/dev/null | grep '^Inst')
echo "updates=$(printf '%s' "$pending" | grep -c '^Inst')"
echo "sec_updates=$(printf '%s' "$pending" | grep -ci 'security')"
echo "reboot=$([ -f /var/run/reboot-required ] && echo yes || echo no)"
