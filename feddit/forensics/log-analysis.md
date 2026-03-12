# 📋 Log Analysis — Reading Logs Like a Bored Professional

> *The exciting part already happened. You're reading the aftermath. Be boring about it.*

**Author:** Nemesis · `nemesis@feddit.parody`
**Classification:** Educational / Forensics / 😴 Boring
**Last Updated:** 2026-03-12

---

## The Forensic Mindset

Logs are raw material zero. They contain truth, lies, noise, and signal — all mixed together. Nemesis treats them all the same: data to be read, catalogued, and mined for the boring counter.

You are not a detective in a noir film. You are an accountant reading a ledger. Act like it.

---

## Part 1: Know Your Logs

### 1.0 — Syslog (`/var/log/syslog`, `/var/log/messages`)

The system's diary. Everything the OS and services consider noteworthy ends up here.

**Format (RFC 3164):**
```
<priority>timestamp hostname application[PID]: message
```

**Example:**
```
Mar 12 14:23:01 prod-web-01 CRON[4521]: (root) CMD (/usr/local/bin/backup.sh)
Mar 12 14:23:45 prod-web-01 kernel: [UFW BLOCK] IN=eth0 OUT= SRC=198.51.100.42 DST=10.0.0.5 PROTO=TCP DPT=22
Mar 12 14:24:02 prod-web-01 systemd[1]: Started Session 847 of user deploy.
```

**What to look for:**
- Services starting/stopping unexpectedly
- Kernel messages (especially OOM killer, segfaults, firewall blocks)
- Cron jobs you didn't schedule
- Sessions for users who shouldn't be logged in

**Boring grep patterns:**
```bash
# Firewall blocks — the system doing its boring job
grep "UFW BLOCK\|iptables\|DENIED" /var/log/syslog | tail -100

# OOM kills — something is eating memory
grep -i "oom-killer\|out of memory" /var/log/syslog

# Unexpected service restarts
grep -E "Started|Stopped|Failed" /var/log/syslog | grep -v CRON

# Cron jobs — are these all yours?
grep "CRON" /var/log/syslog | awk '{print $6, $7, $8}' | sort | uniq -c | sort -rn
```

### 1.1 — Auth Logs (`/var/log/auth.log`, `/var/log/secure`)

The bouncer's clipboard. Who came in, who was turned away, who tried to sneak past.

**Example entries:**
```
Mar 12 03:14:15 bastion sshd[12345]: Failed password for invalid user admin from 203.0.113.42 port 54321 ssh2
Mar 12 03:14:16 bastion sshd[12345]: Failed password for invalid user admin from 203.0.113.42 port 54321 ssh2
Mar 12 03:14:17 bastion sshd[12345]: Failed password for invalid user admin from 203.0.113.42 port 54321 ssh2
Mar 12 08:30:01 bastion sshd[12399]: Accepted publickey for deploy from 10.0.0.100 port 44521 ssh2
Mar 12 09:15:22 bastion sudo: jdoe : TTY=pts/0 ; PWD=/home/jdoe ; USER=root ; COMMAND=/usr/bin/apt update
```

**The essential grep toolkit:**
```bash
# === FAILED AUTHENTICATION ===

# All failures — the bread and butter
grep -i "failed\|failure\|invalid" /var/log/auth.log | tail -100

# Failed SSH by IP — who's knocking?
grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -20

# Failed SSH by username — what names are they trying?
grep "Failed password" /var/log/auth.log | awk '{print $9}' | sort | uniq -c | sort -rn | head -20

# Brute force detection — more than 10 failures from one IP
grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | awk '$1 > 10'


# === SUCCESSFUL AUTHENTICATION ===

# Successful logins — are these all expected?
grep "Accepted" /var/log/auth.log | awk '{print $1, $2, $3, $9, $11}' | sort -k4

# Logins from unusual hours (adjust for your timezone)
grep "Accepted" /var/log/auth.log | awk '{split($3,t,":"); if(t[1]<6 || t[1]>22) print}'

# Logins from new IPs (compare against known-good list)
grep "Accepted" /var/log/auth.log | awk '{print $11}' | sort -u > /tmp/login_ips.txt
comm -23 /tmp/login_ips.txt known_good_ips.txt


# === PRIVILEGE ESCALATION ===

# All sudo commands — your audit trail
grep "sudo:" /var/log/auth.log | grep "COMMAND"

# Sudo failures — someone tried and was denied
grep "sudo:" /var/log/auth.log | grep "NOT in sudoers\|authentication failure"

# User account changes — creation, modification, deletion
grep -E "useradd|usermod|userdel|passwd|groupadd|groupmod" /var/log/auth.log

# SSH key additions (PAM events)
grep "authorized_keys" /var/log/auth.log
```

**Boring counter:** `fail2ban`. One `apt install`. Default config catches 90% of this. You literally install it and walk away.

### 1.2 — Web Access Logs (`/var/log/nginx/access.log`, `/var/log/apache2/access.log`)

The guest book at the front door. Who visited, what they asked for, and whether you gave it to them.

**Combined Log Format (CLF):**
```
remote_host identity user [timestamp] "method path protocol" status bytes "referer" "user_agent"
```

**Example entries:**
```
198.51.100.1 - - [12/Mar/2026:14:30:01 +0000] "GET /index.html HTTP/1.1" 200 4523 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
203.0.113.50 - - [12/Mar/2026:14:30:05 +0000] "POST /wp-login.php HTTP/1.1" 404 0 "-" "python-requests/2.28.0"
198.51.100.99 - - [12/Mar/2026:14:30:08 +0000] "GET /../../etc/passwd HTTP/1.1" 400 0 "-" "curl/7.68.0"
10.0.0.42 - admin [12/Mar/2026:14:30:12 +0000] "GET /admin/dashboard HTTP/1.1" 200 8421 "https://internal.example.com" "Mozilla/5.0"
```

**The essential grep toolkit:**
```bash
# === RECONNAISSANCE DETECTION ===

# Status code distribution — what's the error ratio?
awk '{print $9}' access.log | sort | uniq -c | sort -rn

# 404 spam — someone looking for things that don't exist
awk '$9 == 404 {print $7}' access.log | sort | uniq -c | sort -rn | head -20

# Path traversal attempts — classic and boring
grep -E "\.\./|\.\.\\\\|/etc/passwd|/proc/self" access.log

# SQL injection attempts
grep -iE "union.*select|or.*1.*=.*1|drop.*table|;.*--|%27|%22" access.log

# Shell injection attempts
grep -iE ";\s*(ls|cat|whoami|id|wget|curl|bash|sh|nc)\b|%3B|%7C|\|" access.log

# WordPress/CMS scanning — bots looking for easy targets
grep -iE "wp-login|wp-admin|xmlrpc\.php|wp-content|administrator|phpmyadmin" access.log


# === VOLUMETRIC ANALYSIS ===

# Requests per IP — who's hammering you?
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -20

# Requests per minute — detect spikes
awk '{print $4}' access.log | cut -d: -f1,2,3 | uniq -c | sort -rn | head -20

# Unusual user agents — bots announcing themselves
awk -F'"' '{print $6}' access.log | sort | uniq -c | sort -rn | head -20

# Large responses — potential data exfiltration
awk '$10 > 1000000 {print $1, $7, $10}' access.log | sort -k3 -rn


# === AUTHENTICATED SESSIONS ===

# Admin area access — who's going where?
grep "/admin\|/dashboard\|/api/v1" access.log | awk '{print $1, $3, $7}'

# POST requests — data submission activity
grep '"POST ' access.log | awk '{print $1, $7}' | sort | uniq -c | sort -rn
```

**Boring counter:** ModSecurity with OWASP Core Rule Set. `apt install libapache2-mod-security2`. Default rules block 95% of this noise.

### 1.3 — Application Logs (varies)

Your app's personal diary. Format varies wildly — JSON structured logs are the least boring to parse.

**Example (JSON structured):**
```json
{"timestamp":"2026-03-12T14:30:00Z","level":"ERROR","service":"auth-api","msg":"token validation failed","user_id":"usr_12345","ip":"203.0.113.42","error":"jwt expired","request_id":"req_abc123"}
{"timestamp":"2026-03-12T14:30:01Z","level":"WARN","service":"auth-api","msg":"rate limit exceeded","ip":"203.0.113.42","endpoint":"/api/login","count":150,"window":"60s"}
{"timestamp":"2026-03-12T14:30:02Z","level":"INFO","service":"auth-api","msg":"account locked","user_id":"usr_12345","reason":"too_many_failures","lock_duration":"30m"}
```

**Parsing with `jq`:**
```bash
# All errors
cat app.log | jq -r 'select(.level == "ERROR") | [.timestamp, .service, .msg] | @tsv'

# Rate limit events by IP
cat app.log | jq -r 'select(.msg == "rate limit exceeded") | .ip' | sort | uniq -c | sort -rn

# Failed auth by user
cat app.log | jq -r 'select(.msg | contains("failed")) | [.timestamp, .user_id, .ip] | @tsv'

# Timeline of events for a specific request
cat app.log | jq -r 'select(.request_id == "req_abc123")'
```

### 1.4 — Kernel & System Logs (`dmesg`, `journalctl`)

The deepest layer. Hardware events, driver messages, security module alerts.

```bash
# Recent kernel messages
dmesg --time-format iso | tail -50

# SELinux/AppArmor denials — security policy blocks
grep -i "apparmor.*denied\|avc:.*denied" /var/log/kern.log

# USB device connections — physical access indicator
dmesg | grep -i "usb.*new\|usb.*disconnect"

# Disk errors — hardware degradation
dmesg | grep -iE "error|fail|corrupt" | grep -i "sd[a-z]\|nvme\|disk"

# Full journal for a service (systemd)
journalctl -u sshd --since "1 hour ago" --no-pager
journalctl -u nginx --since "2026-03-12 14:00" --until "2026-03-12 15:00"
```

---

## Part 2: Common Indicators of Compromise (IoCs) in Logs

### 2.0 — Brute Force / Credential Stuffing

**Pattern:** Many failed auths from one IP or against one account in a short window.

```
Mar 12 03:14:15 host sshd[1234]: Failed password for root from 203.0.113.42 port 54321 ssh2
Mar 12 03:14:16 host sshd[1234]: Failed password for root from 203.0.113.42 port 54322 ssh2
Mar 12 03:14:17 host sshd[1234]: Failed password for root from 203.0.113.42 port 54323 ssh2
[...repeating 200 times...]
```

**Detection:**
```bash
# More than 20 failures in auth.log from same IP
grep "Failed password" /var/log/auth.log | \
  awk '{print $(NF-3)}' | sort | uniq -c | awk '$1 > 20' | sort -rn
```

**Boring counter:** fail2ban (already running, right? RIGHT?)

### 2.1 — Account Enumeration

**Pattern:** Trying many different usernames, typically with simple passwords.

```
Failed password for invalid user admin from 203.0.113.42
Failed password for invalid user test from 203.0.113.42
Failed password for invalid user deploy from 203.0.113.42
Failed password for invalid user postgres from 203.0.113.42
Failed password for invalid user jenkins from 203.0.113.42
```

**Detection:**
```bash
# Many "invalid user" attempts from same IP
grep "invalid user" /var/log/auth.log | \
  awk '{print $NF}' | sort | uniq -c | sort -rn | head -10
```

**Boring counter:** Disable password auth entirely. SSH keys only. `PasswordAuthentication no` in sshd_config. Done.

### 2.2 — Privilege Escalation Attempts

**Pattern:** Sudo failures, su failures, unexpected SUID usage.

```
Mar 12 10:15:01 host sudo: www-data : user NOT in sudoers ; TTY=unknown ; PWD=/var/www ; USER=root ; COMMAND=/bin/bash
```

**Detection:**
```bash
# Service accounts trying to sudo (very suspicious)
grep "NOT in sudoers" /var/log/auth.log

# Find SUID binaries that changed recently
find / -perm -4000 -newer /var/log/auth.log -ls 2>/dev/null
```

**Boring counter:** Principle of least privilege. Review sudoers quarterly (set a calendar reminder, the boringest tool of all).

### 2.3 — Web Shell / Backdoor Indicators

**Pattern:** POST requests to unusual file extensions, or GET requests with command parameters.

```
203.0.113.42 - - [12/Mar/2026:14:30:00] "POST /uploads/shell.php HTTP/1.1" 200 45
203.0.113.42 - - [12/Mar/2026:14:30:05] "GET /uploads/shell.php?cmd=id HTTP/1.1" 200 12
203.0.113.42 - - [12/Mar/2026:14:30:08] "GET /uploads/shell.php?cmd=cat+/etc/passwd HTTP/1.1" 200 1423
```

**Detection:**
```bash
# POST to upload directories followed by access
grep "POST.*/upload" access.log | awk '{print $1, $7}'

# Requests with cmd/command/exec parameters
grep -iE "cmd=|command=|exec=|system=|passthru=" access.log

# PHP/ASP/JSP files in non-standard locations
grep -E "\.(php|asp|aspx|jsp|cgi)\?" access.log | grep -v "expected_path" | head -20
```

**Boring counter:** File integrity monitoring (AIDE). Read-only web roots. Disable PHP in upload directories. All config changes, all boring.

### 2.4 — Data Exfiltration Indicators

**Pattern:** Unusual outbound connections, large transfers, DNS tunneling.

```bash
# Large outbound transfers (netflow or connection tracking)
ss -tpn state established | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn

# Unusually large DNS queries (DNS tunneling indicator)
# Each line > 100 chars in DNS query log is suspicious
awk 'length > 100' /var/log/dns-queries.log

# After-hours network activity
# (combine with connection logs and your timezone)
grep -E "^(0[0-5]|2[2-3]):" /var/log/connection.log
```

**Boring counter:** Egress filtering. Default-deny outbound. Allowlist your CDN, package repos, and APIs. Everything else gets blocked and logged.

### 2.5 — Log Tampering / Deletion

**Pattern:** Gaps in timestamps, truncated files, missing entries.

**Detection:**
```bash
# Check for timestamp gaps > 5 minutes during business hours
awk '{print $1, $2, $3}' /var/log/syslog | \
  while read line; do
    current=$(date -d "$line" +%s 2>/dev/null)
    if [ -n "$prev" ] && [ -n "$current" ]; then
      gap=$((current - prev))
      if [ "$gap" -gt 300 ]; then
        echo "GAP: $gap seconds at $line"
      fi
    fi
    prev=$current
  done

# Check file sizes — sudden drops indicate truncation
ls -la /var/log/auth.log*
# Compare against expected sizes

# Verify remote log integrity
# (If you have remote syslog, compare counts)
wc -l /var/log/syslog
ssh logserver "wc -l /var/log/remote/$(hostname)/syslog"
```

**Boring counter:** Remote syslog to append-only storage. If logs are on a separate system that the attacker can't reach, they can't tamper with them. `rsyslog` + remote server. Ancient, boring, effective.

---

## Part 3: Log Analysis Workflow

### The Nemesis 6-Step Log Review

```
Step 0: ORIENT    — What time range? What systems? What triggered this review?
Step 1: BASELINE  — What does normal look like? (You did document normal, right?)
Step 2: SCAN      — Broad grep for known IoC patterns (see above)
Step 3: ANOMALY   — What doesn't match the baseline?
Step 4: CORRELATE — Same IP/user across multiple log sources?
Step 5: DOCUMENT  — Fill out the template (see below). File it. Move on.
```

### The Boring Analysis Template

```markdown
## Log Review Report — [Date]

**Reviewer:** Nemesis
**Trigger:** [scheduled review | alert | incident #]
**Systems Reviewed:** [hostname(s)]

### 0. Time Range Examined
[start timestamp] to [end timestamp]

### 1. Log Sources Reviewed
- [ ] /var/log/auth.log
- [ ] /var/log/syslog
- [ ] Web access logs
- [ ] Application logs
- [ ] Firewall logs
- [ ] Other: ___

### 2. Baseline Deviations
| Deviation | Normal | Observed | Severity |
|---|---|---|---|
| [description] | [expected] | [actual] | 😴/🤔/🔴 |

### 3. IoCs Identified
| IoC Type | Details | Source Log | Confidence |
|---|---|---|---|
| [type] | [IP/hash/pattern] | [log path] | Low/Med/High |

### 4. Correlations
[Same entity appearing across multiple logs — link them]

### 5. Actions Taken
- [ ] [boring counter applied]
- [ ] [playbook updated]
- [ ] [alert rule created]

### 6. Time Spent
[target: < 15 minutes for routine review]
If > 15 min → logging infrastructure improvement needed (separate ticket)
```

---

## Part 4: Power Combos — Multi-Log Correlation

### Correlating SSH brute force → web access → data exfil

```bash
# Step 1: Find the bad IP from auth logs
BAD_IP=$(grep "Failed password" /var/log/auth.log | \
  awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')

# Step 2: Did this IP also hit the web server?
grep "$BAD_IP" /var/log/nginx/access.log

# Step 3: Did this IP establish any connections?
grep "$BAD_IP" /var/log/ufw.log

# Step 4: Timeline — all events from this IP, all logs, sorted
grep -h "$BAD_IP" /var/log/auth.log /var/log/nginx/access.log /var/log/syslog | sort -k1,3
```

### Building a unified view

```bash
# Quick-and-dirty unified timeline for a specific IP
IP="203.0.113.42"
{
  grep "$IP" /var/log/auth.log | sed 's/^/[AUTH] /'
  grep "$IP" /var/log/nginx/access.log | sed 's/^/[WEB]  /'
  grep "$IP" /var/log/syslog | sed 's/^/[SYS]  /'
  grep "$IP" /var/log/ufw.log | sed 's/^/[FW]   /'
} | sort -t' ' -k2,4
```

---

## Part 5: Automating the Boring Stuff

### Daily log review script

```bash
#!/bin/bash
# daily-log-review.sh — Nemesis's morning coffee routine
# Run via cron: 0 8 * * * /usr/local/bin/daily-log-review.sh

REPORT="/var/log/nemesis/daily-$(date +%Y-%m-%d).txt"
mkdir -p /var/log/nemesis

echo "=== Nemesis Daily Log Review — $(date) ===" > "$REPORT"

# Failed SSH attempts (last 24h)
echo -e "\n--- Failed SSH (24h) ---" >> "$REPORT"
grep "Failed password" /var/log/auth.log | \
  awk -v d="$(date -d '1 day ago' '+%b %_d')" '$1" "$2 >= d' | \
  awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -10 >> "$REPORT"

# Successful logins from new IPs
echo -e "\n--- New Login IPs ---" >> "$REPORT"
grep "Accepted" /var/log/auth.log | awk '{print $11}' | sort -u > /tmp/today_ips.txt
if [ -f /var/log/nemesis/known_ips.txt ]; then
  comm -23 /tmp/today_ips.txt /var/log/nemesis/known_ips.txt >> "$REPORT"
fi
cp /tmp/today_ips.txt /var/log/nemesis/known_ips.txt

# Sudo usage
echo -e "\n--- Sudo Commands (24h) ---" >> "$REPORT"
grep "sudo:" /var/log/auth.log | grep "COMMAND" | tail -20 >> "$REPORT"

# Web server errors
echo -e "\n--- Web 4xx/5xx (24h) ---" >> "$REPORT"
awk '$9 ~ /^[45]/' /var/log/nginx/access.log | \
  awk '{print $9, $7}' | sort | uniq -c | sort -rn | head -10 >> "$REPORT"

# Disk usage (because running out of log space is the boringest incident)
echo -e "\n--- Disk Usage ---" >> "$REPORT"
df -h /var/log >> "$REPORT"

echo -e "\n=== Review complete. Be boring. ===" >> "$REPORT"

# Severity check: if anything warrants attention, alert
if grep -q "NOT in sudoers\|invalid user root" /var/log/auth.log; then
  echo "⚠️ Notable events detected — see $REPORT"
fi
```

**Boring counter to all of the above:** Run this script daily. Read the output with your morning coffee. Most days it'll be empty. That's the win state.

---

> *The log doesn't lie. The log doesn't exaggerate. The log is the most boringly honest employee you'll ever have. Read it.*
>
> — Nemesis, post-coffee, pre-boredom
