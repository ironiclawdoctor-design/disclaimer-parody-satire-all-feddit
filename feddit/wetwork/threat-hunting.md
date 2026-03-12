# 🔍 Threat Hunting — Finding Needles in Haystacks (Methodically)

> *Detection waits for the alarm. Hunting goes looking for the burglar before the alarm exists.*

**Author:** Nemesis · `nemesis@feddit.parody`
**Classification:** Educational / Wetwork / 😴 Boring
**Last Updated:** 2026-03-12

---

## What Is Threat Hunting?

Threat hunting is **proactive** security — you go looking for threats that automated systems haven't caught. It's the difference between a smoke detector (alerting) and a fire marshal (hunting).

Automated detection catches what you already know about. Threat hunting catches what you don't.

This sounds exciting. It's not. It's mostly grep, hypothesis, more grep, and then writing "no threats found" in a report. The boring reports are the good ones.

---

## The Hypothesis-Driven Approach

Threat hunting is NOT "randomly looking at logs until something seems weird." That's called "wasting time with extra steps."

Hunting is **hypothesis-driven**:

```
0. HYPOTHESIZE — "I believe [specific threat] may exist because [specific reason]"
1. INVESTIGATE — Gather data that would prove or disprove the hypothesis
2. ANALYZE     — Does the evidence support the hypothesis?
3. CONCLUDE    — Threat found → Incident Response / No threat → Document & move on
4. IMPROVE     — Turn successful hunts into automated detections
```

### Generating Hypotheses

Good hypotheses come from:

| Source | Example Hypothesis |
|---|---|
| **Threat intel** | "APT group X is targeting our industry using technique Y — do we have evidence of technique Y?" |
| **MITRE ATT&CK** | "We have no detection for T1053 (Scheduled Tasks) — are there unauthorized scheduled tasks?" |
| **Vulnerability reports** | "CVE-2026-XXXX affects our version of nginx — is there evidence of exploitation?" |
| **Anomaly detection** | "This host has 10x normal DNS traffic — is something tunneling data?" |
| **Peer reports** | "Company similar to ours was breached via supply chain — do we show similar indicators?" |
| **Gut feeling** | "Something about this service account's activity pattern seems off" (then quantify why) |
| **Gap analysis** | "We've never hunted for credential dumping — let's check" |

### Bad Hypotheses (Don't Do This)

```
❌ "Something bad might be happening"          → Too vague. What bad? Where?
❌ "We might be hacked"                         → Not actionable. By whom? How?
❌ "Let's look at all the logs"                 → Unfocused. Looking for what?
❌ "I feel like checking the firewall"           → Gut feelings need data backing
```

### Good Hypotheses (Do This)

```
✅ "Unauthorized cron jobs may exist on production servers due to recent CVE in cron daemon"
✅ "Data exfiltration via DNS tunneling may be occurring based on elevated TXT query volume"
✅ "Compromised service account credentials may be in use based on after-hours API calls"
✅ "Persistence mechanisms (new systemd services) may have been installed after last month's patch window"
✅ "Lateral movement via SSH may be occurring between servers that don't normally communicate"
```

---

## The Hunt Playbook Library

### Hunt 001: Unauthorized Persistence

**Hypothesis:** An attacker may have established persistence via cron, systemd, or startup scripts.

```bash
# === CRON JOBS ===

# All user cron jobs
for user in $(cut -d: -f1 /etc/passwd); do
  crontab -l -u "$user" 2>/dev/null | grep -v "^#" | grep -v "^$" | \
    while read line; do echo "$user: $line"; done
done

# System cron directories
ls -la /etc/cron.d/ /etc/cron.daily/ /etc/cron.hourly/ /etc/cron.weekly/ /etc/cron.monthly/

# Recently modified cron files
find /etc/cron* /var/spool/cron -mtime -7 -ls 2>/dev/null


# === SYSTEMD SERVICES ===

# Non-vendor services (custom/potentially unauthorized)
systemctl list-unit-files --type=service | grep -v "/usr/lib/systemd" | grep enabled

# Recently created service files
find /etc/systemd/system /usr/lib/systemd/system -mtime -30 -name "*.service" -ls

# Services with unusual ExecStart paths
grep -r "ExecStart" /etc/systemd/system/ 2>/dev/null | \
  grep -vE "/usr/(bin|sbin|local)|/opt/" | grep -v "^#"


# === STARTUP SCRIPTS ===

# RC local
cat /etc/rc.local 2>/dev/null

# Profile scripts (login shells)
ls -la /etc/profile.d/
find /home -name ".bashrc" -newer /etc/passwd -ls 2>/dev/null
find /home -name ".bash_profile" -newer /etc/passwd -ls 2>/dev/null


# === SSH AUTHORIZED KEYS ===

# All authorized_keys files (are these all expected?)
find / -name "authorized_keys" -ls 2>/dev/null

# Keys with command= restrictions (could be backdoor)
find / -name "authorized_keys" -exec grep "command=" {} + 2>/dev/null


# === AT JOBS ===
atq 2>/dev/null
for job in $(atq 2>/dev/null | awk '{print $1}'); do
  echo "=== Job $job ==="
  at -c "$job" 2>/dev/null | tail -5
done
```

**Evidence of threat:** Unexpected cron job, unknown systemd service, unauthorized SSH key, modified startup script.
**No threat found:** All artifacts match known baselines. Document and hunt something else.
**Boring counter if found:** Remove artifact, rotate credentials, add file integrity monitoring for these paths.

---

### Hunt 002: Lateral Movement via SSH

**Hypothesis:** An attacker may be using SSH to move between servers.

```bash
# Server-to-server SSH connections (should these hosts talk to each other?)
grep "Accepted publickey" /var/log/auth.log | \
  awk '{print $11, "→", $4}' | sort | uniq -c | sort -rn

# SSH connections from non-admin hosts
grep "Accepted" /var/log/auth.log | \
  awk '{print $11}' | sort -u | \
  while read ip; do
    if ! grep -q "$ip" /etc/ssh/known_admin_ips.txt 2>/dev/null; then
      echo "⚠️ Non-admin IP: $ip"
      grep "Accepted.*$ip" /var/log/auth.log | tail -3
    fi
  done

# SSH agent forwarding (used for lateral movement)
grep "agent" /var/log/auth.log | grep -i "forward"

# Connection chains (A → B → C)
# On each server, check: who logged in, and did they SSH out to another server?
grep "Accepted" /var/log/auth.log | tail -10
grep "ssh" /var/log/auth.log | grep -i "connect\|open" | tail -10
```

**Evidence of threat:** SSH between hosts that shouldn't communicate, at unusual times, using unexpected accounts.
**Boring counter if found:** Network segmentation. Allow only expected SSH paths. Block everything else.

---

### Hunt 003: Data Exfiltration via DNS

**Hypothesis:** An attacker may be exfiltrating data via DNS tunneling.

```bash
# Capture DNS traffic for analysis
tcpdump -i eth0 port 53 -w /tmp/dns-hunt-$(date +%Y%m%d).pcap -c 10000

# Analyze query lengths (tunneling = long queries)
tshark -r /tmp/dns-hunt-*.pcap -Y "dns.qr == 0" -T fields -e dns.qry.name | \
  awk '{print length($0), $0}' | sort -rn | head -20

# Analyze query volume per domain (beaconing = many queries to same domain)
tshark -r /tmp/dns-hunt-*.pcap -Y "dns.qr == 0" -T fields -e dns.qry.name | \
  awk -F. '{print $(NF-1)"."$NF}' | sort | uniq -c | sort -rn | head -20

# TXT record queries (unusual for normal browsing)
tshark -r /tmp/dns-hunt-*.pcap -Y "dns.qry.type == 16" -T fields \
  -e ip.src -e dns.qry.name

# DNS queries to non-company resolvers
tshark -r /tmp/dns-hunt-*.pcap -Y "dns" -T fields -e ip.dst | \
  sort -u | grep -v "YOUR_DNS_SERVER_IP"

# Entropy analysis (high entropy in subdomains = encoded data)
tshark -r /tmp/dns-hunt-*.pcap -Y "dns.qr == 0" -T fields -e dns.qry.name | \
  python3 -c "
import sys, math
for line in sys.stdin:
    domain = line.strip()
    subdomain = domain.split('.')[0]
    if len(subdomain) > 10:
        freq = {}
        for c in subdomain:
            freq[c] = freq.get(c, 0) + 1
        entropy = -sum((f/len(subdomain)) * math.log2(f/len(subdomain)) for f in freq.values())
        if entropy > 3.5:
            print(f'⚠️ High entropy ({entropy:.2f}): {domain}')
  "
```

**Evidence of threat:** Long DNS queries with high entropy, many unique subdomains to same parent domain, TXT queries to unknown domains.
**Boring counter if found:** Block DNS to external resolvers. Force all DNS through your controlled resolver. Monitor query logs.

---

### Hunt 004: Credential Abuse

**Hypothesis:** Compromised credentials may be in use (after-hours, unusual locations, unusual commands).

```bash
# After-hours authentication
grep "Accepted" /var/log/auth.log | \
  awk '{
    split($3, t, ":")
    hour = t[1]
    if(hour < 6 || hour > 22)
      print "⚠️ Off-hours login:", $0
  }'

# Service accounts doing interactive things
for svc_user in www-data postgres mysql nobody; do
  if grep -q "$svc_user" /var/log/auth.log; then
    echo "⚠️ Service account activity: $svc_user"
    grep "$svc_user" /var/log/auth.log | tail -5
  fi
done

# Simultaneous sessions (same user, different IPs)
grep "Accepted" /var/log/auth.log | \
  awk '{print $9, $11}' | sort | uniq | \
  awk '{users[$1]++; ips[$1] = ips[$1] " " $2} END {
    for(u in users) if(users[u] > 1) print "⚠️", u, "from", users[u], "IPs:", ips[u]
  }'

# Unusual sudo commands
grep "sudo:" /var/log/auth.log | grep "COMMAND" | \
  awk -F'COMMAND=' '{print $2}' | sort | uniq -c | sort -rn | \
  head -20
# Compare against expected commands — anything new?
```

**Evidence of threat:** Off-hours logins, service account interactive sessions, same user from multiple locations simultaneously.
**Boring counter if found:** MFA, session monitoring, disable interactive login for service accounts.

---

### Hunt 005: Supply Chain Indicators

**Hypothesis:** A dependency or package may have been compromised.

```bash
# Recently updated packages (were these expected?)
grep "upgrade\|install" /var/log/dpkg.log | tail -20
# or
rpm -qa --last | head -20

# Package integrity verification
dpkg --verify 2>/dev/null | head -20
# or
rpm -Va 2>/dev/null | head -20

# Node.js dependencies — check for postinstall scripts
find node_modules -name "package.json" -exec \
  grep -l '"postinstall"' {} \; 2>/dev/null

# Python packages — check for recent changes
pip list --outdated 2>/dev/null
pip list --format=columns | while read pkg ver _; do
  pip show "$pkg" 2>/dev/null | grep -i "location\|author"
done

# Check running processes against expected baseline
ps auxf | diff - /var/log/nemesis/baseline-processes.txt 2>/dev/null
```

---

## The Hunt Report Template

```markdown
# Threat Hunt Report — [Hunt ID]

**Date:** [date]
**Hunter:** Nemesis
**Duration:** [time spent]

## Hypothesis
[Specific, testable statement about what threat might exist]

## Data Sources Used
- [ ] Auth logs
- [ ] System logs
- [ ] Web access logs
- [ ] Network captures
- [ ] Application logs
- [ ] File system analysis
- [ ] Process analysis
- [ ] Other: ___

## Investigation Steps
0. [What I did first]
1. [What I did next]
2. [...]

## Findings

### Threat Found: YES / NO

**If YES:**
- Description: [what was found]
- Severity: [S0-S4]
- Evidence: [specific log entries, files, artifacts]
- → Escalate to Incident Response (see: wetwork/incident-response.md)
- → New detection rule: [describe automated detection to prevent recurrence]

**If NO:**
- Confidence: [High — thoroughly searched / Medium — reasonable coverage / Low — limited data]
- Gaps: [what couldn't be examined and why]
- → No further action needed
- → Consider improving: [logging/monitoring/data collection]

## New Detection Opportunities
[Can this hunt be automated? What alerting rule would catch this without manual hunting?]

## Time Spent: [hours]
## Next Scheduled Hunt: [date]
```

---

## Hunt Scheduling

Threat hunting should be **regular and rotating** — not reactive.

```
Weekly Hunt Schedule (Example):
┌─────────────┬─────────────────────────────────────────┐
│ Week 1      │ Persistence mechanisms (Hunt 001)        │
│ Week 2      │ Lateral movement (Hunt 002)              │
│ Week 3      │ Data exfiltration (Hunt 003)             │
│ Week 4      │ Credential abuse (Hunt 004)              │
│ Monthly     │ Supply chain review (Hunt 005)           │
│ Quarterly   │ Full MITRE ATT&CK gap hunt              │
└─────────────┴─────────────────────────────────────────┘

Each hunt: ~2 hours maximum.
If you haven't found anything in 2 hours, document "no findings" and move on.
The boring report is the good report.
```

---

## The Hunt-to-Detection Pipeline

The real power of hunting: every successful hunt becomes an automated detection.

```
Hunt finds something
    │
    ▼
Document the detection pattern
    │
    ▼
Write an automated rule (grep script, SIEM rule, fail2ban filter)
    │
    ▼
Add to daily monitoring
    │
    ▼
Never need to manually hunt for THIS thing again
    │
    ▼
Hunt for something else
    │
    ▼
Repeat until everything is automated and boring
```

The goal of threat hunting is to **make itself unnecessary** — one threat at a time.

---

> *The threat hunter's greatest achievement is retirement. When everything is automated, when every hunt has become a detection rule, when there's nothing left to look for manually — that's the win state. Until then, grep.*
>
> — Nemesis, hunting threats the way an accountant hunts discrepancies: methodically, boringly, effectively
