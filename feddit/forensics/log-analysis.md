# 📋 Log Analysis — Reading Logs Like a Bored Professional

> *The exciting part already happened. You're reading the aftermath. Be boring about it.*

## The Forensic Mindset

Logs are raw material zero. They contain truth, lies, noise, and signal — all mixed together. Nemesis treats them all the same: data to be read, catalogued, and mined for the boring counter.

## What To Look For

### 0. Authentication Events
```bash
# Failed logins (the boring bread and butter)
grep -i "failed\|failure\|invalid" /var/log/auth.log | tail -50

# Successful logins from unusual sources
grep "Accepted" /var/log/auth.log | awk '{print $9, $11}' | sort | uniq -c | sort -rn
```
**Boring counter:** If you see patterns → fail2ban. Literally one package install.

### 1. Timeline Gaps
Missing logs are more interesting than present logs. A gap in timestamps suggests:
- Log rotation (boring, expected)
- Service crash (boring, check why)
- Log tampering (not boring, investigate)

**Boring counter:** Remote syslog to append-only storage. Can't tamper what you can't reach.

### 2. Privilege Changes
```bash
# Who sudoed and when
grep "sudo:" /var/log/auth.log | grep "COMMAND"

# User creation/modification
grep -E "useradd|usermod|passwd" /var/log/auth.log
```
**Boring counter:** Alert on unexpected privilege changes. One-line cron job.

### 3. Network Anomalies
```bash
# Unusual outbound connections
ss -tpn | grep ESTAB | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn

# DNS queries to unusual domains (if logging)
grep -v -E "known-good-domain" /var/log/dns-queries.log
```
**Boring counter:** Egress firewall rules. Default deny outbound. Allowlist what you need.

## The Boring Analysis Template

For every log review, Nemesis fills out:

```markdown
## Incident Log Review — [Date]

### 0. Time Range Examined: [start] to [end]
### 1. Anomalies Found: [count]
### 2. Severity: 😴 Boring / 🤔 Notable / 🔴 Investigate
### 3. Actions Taken: [boring counter applied]
### 4. Playbook Updated: [yes/no]
### 5. Time Spent: [should be < 15 minutes]
```

If the review takes more than 15 minutes, your logging infrastructure needs improvement — that's a separate boring task.
