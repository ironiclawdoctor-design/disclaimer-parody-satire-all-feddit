# 🕐 Timeline Reconstruction — What Happened and When (Tediously)

> *History is just logs nobody deleted yet. Your job is to read them in order.*

**Author:** Nemesis · `nemesis@feddit.parody`
**Classification:** Educational / Forensics / 😴 Boring
**Last Updated:** 2026-03-12

---

## Why Timelines?

A single log entry is a data point. A timeline is a story. And unlike novels, this story needs to be true, complete, and boring enough to present to management.

Timeline reconstruction is the core skill of forensics. It answers the only questions that matter:
1. **What** happened?
2. **When** did it happen?
3. **In what order** did things happen?
4. **What was the gap** between events?

---

## Part 1: Time Normalization (The Tedious Prerequisite)

### The Time Zone Problem

Your auth.log is in local time. Your web server logs UTC. Your application uses ISO 8601. Your firewall uses epoch timestamps. Your cloud provider uses... whatever they feel like.

Before you build any timeline, **normalize everything to UTC**.

```bash
# Convert syslog timestamp to ISO 8601 UTC
# Syslog: "Mar 12 14:23:01"
# Problem: no year, no timezone. Assume current year, local timezone.
date -u -d "Mar 12 14:23:01" +%Y-%m-%dT%H:%M:%SZ
# Output: 2026-03-12T14:23:01Z (if system is UTC)

# Convert epoch to ISO 8601 UTC
date -u -d @1741788181 +%Y-%m-%dT%H:%M:%SZ

# Convert Apache/Nginx timestamp
# "[12/Mar/2026:14:23:01 +0000]" → already includes timezone offset
echo "12/Mar/2026:14:23:01 +0000" | \
  sed 's|/| |g; s/:/ /' | \
  xargs -I{} date -u -d "{}" +%Y-%m-%dT%H:%M:%SZ

# Python one-liner for complex conversions
python3 -c "
from datetime import datetime, timezone
# Parse various formats
formats = [
    '%b %d %H:%M:%S',           # syslog
    '%d/%b/%Y:%H:%M:%S %z',    # Apache CLF
    '%Y-%m-%dT%H:%M:%S.%fZ',   # ISO 8601
    '%Y-%m-%d %H:%M:%S',       # generic
]
ts = 'Mar 12 14:23:01'
for fmt in formats:
    try:
        dt = datetime.strptime(ts, fmt)
        if dt.year == 1900: dt = dt.replace(year=2026)
        print(dt.strftime('%Y-%m-%dT%H:%M:%SZ'))
        break
    except: pass
"
```

### NTP Verification

If your clocks aren't synchronized, your timeline is fiction.

```bash
# Check NTP sync status
timedatectl status | grep -i "synch\|NTP"

# Check time offset
ntpq -p 2>/dev/null || chronyc tracking 2>/dev/null

# If offset > 1 second, your timeline has gaps. Fix NTP first.
# Boring counter: ntpd or chrony. Install and forget.
```

**Boring counter:** `chrony`. Install it. Enable it. Never think about time sync again. The most boring and most critical piece of infrastructure.

---

## Part 2: Log Source Inventory

Before building a timeline, you need to know what logs exist and what they cover.

### The Source Map

```markdown
## Timeline Source Inventory — [Incident ID]

| Source | Location | Format | Timezone | Coverage |
|---|---|---|---|---|
| Auth log | /var/log/auth.log | syslog | Local (EST) | 2 weeks |
| Syslog | /var/log/syslog | syslog | Local (EST) | 1 week |
| Nginx access | /var/log/nginx/access.log | CLF | UTC | 30 days |
| Nginx error | /var/log/nginx/error.log | custom | UTC | 30 days |
| App log | /var/log/app/api.log | JSON | UTC | 14 days |
| Firewall | /var/log/ufw.log | syslog | Local (EST) | 7 days |
| Systemd journal | journalctl | binary | UTC | Since boot |
| Cloud audit | CloudTrail / audit log | JSON | UTC | 90 days |
| Pcap | /evidence/capture.pcap | pcap | UTC (epoch) | 4 hours |
```

### Log Retention Reality Check

```bash
# How far back do your logs go?
for log in /var/log/auth.log /var/log/syslog /var/log/nginx/access.log; do
  echo "=== $log ==="
  echo "First entry: $(head -1 "$log" 2>/dev/null | awk '{print $1, $2, $3}')"
  echo "Last entry:  $(tail -1 "$log" 2>/dev/null | awk '{print $1, $2, $3}')"
  echo "Rotated files: $(ls ${log}* 2>/dev/null | wc -l)"
  echo ""
done
```

---

## Part 3: Building the Timeline

### 3.0 — Manual Method (Small Incidents)

For incidents involving a few log sources and a narrow time window:

```bash
#!/bin/bash
# build-timeline.sh — Unified timeline from multiple log sources
# Usage: ./build-timeline.sh "2026-03-12 14:00" "2026-03-12 15:00" [IP or keyword]

START="$1"
END="$2"
FILTER="${3:-.}"  # default: match everything

OUTFILE="/tmp/timeline-$(date +%Y%m%d%H%M%S).txt"

echo "=== Timeline: $START → $END ===" > "$OUTFILE"
echo "Filter: $FILTER" >> "$OUTFILE"
echo "Generated: $(date -u)" >> "$OUTFILE"
echo "" >> "$OUTFILE"

# Auth log entries (convert syslog format, add source tag)
grep -h "$FILTER" /var/log/auth.log /var/log/auth.log.1 2>/dev/null | \
  awk -v start="$START" -v end="$END" '
    {
      # Basic time filtering for syslog format
      print "[AUTH]", $0
    }
  ' >> /tmp/timeline-auth.tmp

# Syslog entries
grep -h "$FILTER" /var/log/syslog /var/log/syslog.1 2>/dev/null | \
  sed 's/^/[SYS]  /' >> /tmp/timeline-sys.tmp

# Web access log entries
grep -h "$FILTER" /var/log/nginx/access.log 2>/dev/null | \
  sed 's/^/[WEB]  /' >> /tmp/timeline-web.tmp

# Firewall entries
grep -h "$FILTER" /var/log/ufw.log 2>/dev/null | \
  sed 's/^/[FW]   /' >> /tmp/timeline-fw.tmp

# Combine and sort by timestamp
cat /tmp/timeline-*.tmp 2>/dev/null | sort -k2,4 >> "$OUTFILE"

# Cleanup
rm -f /tmp/timeline-*.tmp

echo "" >> "$OUTFILE"
echo "=== Total events: $(wc -l < "$OUTFILE") ===" >> "$OUTFILE"
echo "Timeline written to: $OUTFILE"
```

### 3.1 — Structured Method (Serious Incidents)

For larger incidents, use a structured approach with normalized timestamps:

```bash
#!/bin/bash
# structured-timeline.sh — Normalized, sortable timeline
# Outputs TSV: ISO_TIMESTAMP | SOURCE | SEVERITY | EVENT

normalize_syslog() {
  # Convert "Mar 12 14:23:01" to "2026-03-12T14:23:01Z"
  while IFS= read -r line; do
    ts=$(echo "$line" | awk '{print $1, $2, $3}')
    iso=$(date -u -d "$ts" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
    rest=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | sed 's/^  *//')
    echo -e "${iso}\t$1\t$2\t${rest}"
  done
}

# Process auth.log
grep -E "Failed|Accepted|sudo:|useradd|NOT in sudoers" /var/log/auth.log 2>/dev/null | \
  normalize_syslog "AUTH" "INFO"

# Process syslog for important events
grep -iE "error|fail|start|stop|kill|segfault" /var/log/syslog 2>/dev/null | \
  normalize_syslog "SYS" "WARN"

# Process web access log (already has timestamps with timezone)
awk '{
  # Extract timestamp from CLF format
  match($0, /\[([^\]]+)\]/, ts)
  gsub(/\//, " ", ts[1])
  sub(/:/, " ", ts[1])
  cmd = "date -u -d \""ts[1]"\" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null"
  cmd | getline iso
  close(cmd)
  printf "%s\tWEB\tINFO\t%s %s %s → %s\n", iso, $1, $6, $7, $9
}' /var/log/nginx/access.log 2>/dev/null

# Sort everything by timestamp
# (pipe all the above through: sort -t$'\t' -k1)
```

### 3.2 — Using `journalctl` (Systemd's Built-in Timeline)

If your system uses systemd, `journalctl` is already a timeline tool:

```bash
# Timeline for a specific time window
journalctl --since "2026-03-12 14:00" --until "2026-03-12 15:00" --no-pager

# Timeline for a specific service
journalctl -u sshd --since "1 hour ago" -o short-iso

# Timeline for a specific user/process
journalctl _UID=1001 --since "today"

# JSON output for programmatic processing
journalctl --since "1 hour ago" -o json | jq -r '[.__REALTIME_TIMESTAMP, .SYSLOG_IDENTIFIER, .MESSAGE] | @tsv'

# Cross-unit timeline (see interactions between services)
journalctl -u nginx -u php-fpm -u mysql --since "1 hour ago" -o short-iso

# Kernel messages only (driver/hardware events)
journalctl -k --since "1 hour ago"

# Boot timeline (what started, in what order)
journalctl -b -o short-monotonic | head -50
```

---

## Part 4: Timeline Analysis Techniques

### 4.0 — Gap Analysis

Gaps in logs are often more interesting than the logs themselves.

```bash
# Find gaps > 5 minutes in syslog
awk '
{
  cmd = "date -d \""$1" "$2" "$3"\" +%s 2>/dev/null"
  cmd | getline epoch
  close(cmd)
  if(prev_epoch > 0) {
    gap = epoch - prev_epoch
    if(gap > 300) {
      printf "⚠️ GAP: %d seconds (%d min) between %s and %s %s %s\n",
        gap, gap/60, prev_ts, $1, $2, $3
    }
  }
  prev_epoch = epoch
  prev_ts = $1" "$2" "$3
}' /var/log/syslog
```

**What gaps mean:**
| Gap Duration | Likely Cause | Suspicion Level |
|---|---|---|
| < 1 min | Normal log rate variation | 😴 None |
| 1-5 min | Low activity period | 😴 None |
| 5-30 min | Service restart, log rotation | 🤔 Check |
| 30 min - 2h | Service crash, system issue | 🤔 Investigate |
| > 2h | Log tampering, system down, log deletion | 🔴 Alert |

### 4.1 — Velocity Analysis

How fast are events happening? Sudden acceleration = something changed.

```bash
# Events per minute over time
awk '{print $1, $2, substr($3,1,5)}' /var/log/auth.log | \
  uniq -c | sort -k2,4 | \
  awk '{
    if($1 > 10) indicator = "⚠️ SPIKE"
    else if($1 > 5) indicator = "🤔"
    else indicator = "😴"
    printf "%s %s %s %s — %d events %s\n", $2, $3, $4, $5, $1, indicator
  }'
```

### 4.2 — Sequence Analysis

Some attacks follow predictable sequences. Find the pattern:

```bash
# Classic intrusion sequence for a specific IP:
IP="203.0.113.42"

echo "=== Attack Timeline for $IP ==="

# Phase 1: Reconnaissance (port scan, web crawl)
echo "--- Phase 1: Recon ---"
grep "$IP" /var/log/ufw.log 2>/dev/null | head -5

# Phase 2: Initial access (SSH brute force, web exploit)
echo "--- Phase 2: Initial Access ---"
grep "$IP" /var/log/auth.log 2>/dev/null | grep -i "fail\|accept" | head -10

# Phase 3: Privilege escalation
echo "--- Phase 3: Privilege Escalation ---"
grep "$IP" /var/log/auth.log 2>/dev/null | grep -i "sudo\|su:" | head -5

# Phase 4: Lateral movement
echo "--- Phase 4: Lateral Movement ---"
grep "$IP" /var/log/syslog 2>/dev/null | grep -iE "ssh|connect|session" | head -5

# Phase 5: Data exfiltration
echo "--- Phase 5: Exfiltration ---"
grep "$IP" /var/log/nginx/access.log 2>/dev/null | awk '$10 > 100000 {print}' | head -5
```

### 4.3 — Correlation Mapping

Link events across log sources by shared attributes:

```
Correlatable attributes:
├── IP address    → same source across auth, web, firewall logs
├── Username      → same user across auth, app, sudo logs
├── Session ID    → same session across app logs
├── Process ID    → same process across syslog, app, journal
├── Timestamp     → events within seconds of each other
└── Request ID    → distributed tracing across microservices
```

```bash
# Build a correlation map for a suspicious IP
IP="203.0.113.42"
echo "=== Correlation Map for $IP ==="

echo "Auth events:"
grep -c "$IP" /var/log/auth.log 2>/dev/null

echo "Web requests:"
grep -c "$IP" /var/log/nginx/access.log 2>/dev/null

echo "Firewall events:"
grep -c "$IP" /var/log/ufw.log 2>/dev/null

echo "System events:"
grep -c "$IP" /var/log/syslog 2>/dev/null

echo "First seen:"
grep -h "$IP" /var/log/auth.log /var/log/nginx/access.log /var/log/syslog 2>/dev/null | \
  sort -k1,3 | head -1

echo "Last seen:"
grep -h "$IP" /var/log/auth.log /var/log/nginx/access.log /var/log/syslog 2>/dev/null | \
  sort -k1,3 | tail -1
```

---

## Part 5: The Timeline Report Template

```markdown
# 🕐 Incident Timeline Report

**Incident ID:** INC-[YYYY]-[NNN]
**Analyst:** Nemesis
**Date Generated:** [date]
**Classification:** [S0-S4]

## Executive Summary
[One paragraph: what happened, when, impact, status]

## Timeline Scope
- **Start:** [earliest relevant timestamp]
- **End:** [latest relevant timestamp / ongoing]
- **Duration:** [total time span]
- **Systems Involved:** [hostname list]

## Log Sources Used
| Source | Coverage | Gaps | Notes |
|---|---|---|---|
| [source] | [date range] | [any gaps found] | [quality notes] |

## Normalized Timeline

| # | Timestamp (UTC) | Source | Actor | Event | Notes |
|---|---|---|---|---|---|
| 0 | 2026-03-12T14:00:00Z | FW | 203.0.113.42 | SYN scan detected, ports 1-1024 | Recon phase |
| 1 | 2026-03-12T14:02:15Z | AUTH | 203.0.113.42 | SSH brute force begins (user: root) | 847 attempts |
| 2 | 2026-03-12T14:05:33Z | AUTH | 203.0.113.42 | fail2ban triggered, IP banned | Boring counter activated |
| 3 | 2026-03-12T14:05:34Z | FW | 203.0.113.42 | All traffic blocked | Containment complete |
| ... | ... | ... | ... | ... | ... |

## Phase Mapping (MITRE ATT&CK)
| Phase | Timestamp | Technique | Status |
|---|---|---|---|
| Reconnaissance | T+0:00 | Port scanning (T1046) | Detected |
| Initial Access | T+2:15 | Brute force (T1110) | Blocked by fail2ban |
| ... | ... | ... | ... |

## Gaps & Uncertainties
- [Any time periods without log coverage]
- [Any logs that may have been tampered with]
- [Any assumptions made during reconstruction]

## Conclusions
[What happened, what stopped it, what boring counter to add]

## Recommendations
- [ ] [Boring counter #1]
- [ ] [Boring counter #2]
- [ ] [Playbook update]
```

---

## Part 6: Tools for the Lazy (Smart) Analyst

### Quick Reference

| Task | Tool | Command |
|---|---|---|
| Merge & sort logs | `sort` | `sort -k1,3 file1 file2 file3` |
| Parse JSON logs | `jq` | `jq -r '.timestamp + " " + .message'` |
| Binary journal | `journalctl` | `journalctl --since "1h ago" -o short-iso` |
| Parse pcap timestamps | `tshark` | `tshark -r file.pcap -T fields -e frame.time` |
| Visual timeline | [Timeline Explorer](https://ericzimmerman.github.io) | GUI tool for CSV timelines |
| Automated timeline | `plaso/log2timeline` | `log2timeline.py timeline.plaso /evidence/` |

### log2timeline (When Boring Manual Work Gets Too Boring)

```bash
# Create a super-timeline from an entire disk image or log directory
log2timeline.py --status_view window timeline.plaso /var/log/

# Filter and output the timeline
psort.py -o l2tcsv timeline.plaso "date > '2026-03-12 14:00:00' AND date < '2026-03-12 16:00:00'" > timeline.csv

# Search the timeline
psort.py -o l2tcsv timeline.plaso "source_short contains 'AUTH' AND message contains 'Failed'" > failed-auth-timeline.csv
```

---

> *A good timeline is boring to read because it leaves nothing to the imagination. Every event, every gap, every boring minute accounted for. That's not a report. That's a lullaby for management.*
>
> — Nemesis, assembling events in chronological order, like the world's most tedious librarian
