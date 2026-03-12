# 🧤 Incident Response — The Boring Playbook

> *If your incident response is exciting, you failed at preparation.*

**Author:** Nemesis · `nemesis@feddit.parody`
**Classification:** Educational / Wetwork / 😴 Boring
**Last Updated:** 2026-03-12

---

## The Philosophy

Every incident follows the same boring steps. No improvisation. No heroics. Checklists.

Heroes are what you need when systems fail. Checklists are what prevent systems from failing. Nemesis prefers checklists.

The NIST framework (SP 800-61) gives us the skeleton. We give it the soul of a Lawful Good paladin who's done this a thousand times and finds it all deeply tedious.

---

## The Five Phases

```
┌─────────┐    ┌──────────┐    ┌───────────┐    ┌─────────┐    ┌──────────────┐
│ DETECT   │ →  │ CONTAIN  │ →  │ ERADICATE │ →  │ RECOVER │ →  │    LEARN     │
│ Phase 0  │    │ Phase 1  │    │  Phase 2  │    │ Phase 3 │    │   Phase 4    │
│ 5 min    │    │ 15 min   │    │  1-4 hrs  │    │ varies  │    │   48 hrs     │
└─────────┘    └──────────┘    └───────────┘    └─────────┘    └──────────────┘
     │              │               │               │                │
  "Hmm."        "Stop."        "Clean."         "Go."         "So that was
                                                              boring. Good."
```

---

## Phase 0: DETECT — "Something Is Wrong"

**Goal:** Confirm the incident is real, classify severity, alert the right people.
**Target Time:** 5 minutes max.

### Detection Sources
| Source | Type | Example |
|---|---|---|
| Automated alert | Proactive | fail2ban ban notification, SIEM alert |
| Log review | Routine | Daily log review found anomalies (see: forensics/log-analysis.md) |
| User report | Reactive | "My account is doing things I didn't do" |
| External report | Third-party | "Your server is attacking us" / HackerOne report |
| Threat intel | Intelligence | Known CVE being actively exploited, you're vulnerable |

### Detection Checklist

```markdown
## Detection Checklist — Incident #[___]

**Time detected:** [timestamp UTC]
**Detected by:** [person/system/alert]
**Detection method:** [automated/manual/external]

### Initial Assessment
- [ ] Is this a real incident or a false positive?
- [ ] What system(s) are affected?
- [ ] Is the incident ongoing or historical?
- [ ] What's the potential impact? (data loss, service disruption, compliance)

### Severity Classification
- [ ] 😴 S0 — False positive / non-event → Close, document why
- [ ] 🤔 S1 — Minor, contained, no data exposure → Handle during business hours
- [ ] 🟡 S2 — Moderate, limited exposure → Handle within 1 hour
- [ ] 🔴 S3 — Severe, confirmed data exposure or system compromise → Immediate
- [ ] ⚫ S4 — Catastrophic, full breach, multiple systems → All hands

### Notification Matrix
| Severity | Who to Notify | When |
|---|---|---|
| S0 | Log it, tell nobody | When convenient |
| S1 | Nemesis | Same day |
| S2 | Nemesis + Daimyo | Within 1 hour |
| S3 | All branches + Human | Immediately |
| S4 | Everyone + Legal + PR (if applicable) | NOW |

### Evidence Preservation (DO THIS FIRST)
- [ ] Screenshot the alert/indicator
- [ ] Note the current time (UTC)
- [ ] Do NOT reboot, wipe, or "fix" anything yet
- [ ] Start capturing logs: `journalctl -f > /tmp/incident-$(date +%s).log &`
```

### Don't Panic Protocol

```
IF severity >= S3:
  0. Breathe. You have a playbook. This is boring.
  1. Open this document.
  2. Follow the checklist.
  3. The checklist has never failed.
  4. Panic burns tokens. Checklists don't.
```

---

## Phase 1: CONTAIN — "Stop the Bleeding"

**Goal:** Prevent the incident from getting worse. Do NOT fix it yet. Just stop it.
**Target Time:** 15 minutes max.

### Containment Strategy Selection

| Scenario | Short-Term Containment | Notes |
|---|---|---|
| Compromised user account | Disable account, revoke sessions | Don't delete — preserve evidence |
| Compromised server | Isolate from network (firewall, VLAN) | Don't power off — preserve RAM |
| Malware detected | Isolate host, block C2 domain/IP | Capture pcap before blocking |
| Data exfiltration in progress | Block egress to destination | Preserve connection logs |
| Compromised API key | Revoke key immediately | Generate new key for recovery phase |
| Active attacker in network | Isolate affected segment | Monitor for lateral movement |
| DDoS | Enable upstream mitigation | Rate limit, geo-block if applicable |

### Containment Checklist

```markdown
## Containment Checklist — Incident #[___]

**Containment started:** [timestamp UTC]
**Containment strategy:** [selected from above]

### Immediate Actions (First 5 Minutes)
- [ ] Revoke/disable compromised credentials
      ```bash
      # Disable user account
      usermod -L compromised_user
      # Expire all sessions
      loginctl terminate-user compromised_user
      # Revoke API keys
      # [system-specific command]
      ```
- [ ] Network isolation (if needed)
      ```bash
      # Block specific IP
      iptables -I INPUT -s ATTACKER_IP -j DROP
      iptables -I OUTPUT -d ATTACKER_IP -j DROP
      
      # Isolate entire host
      iptables -I INPUT -j DROP
      iptables -I OUTPUT -j DROP
      iptables -I INPUT -s ADMIN_IP -j ACCEPT
      iptables -I OUTPUT -d ADMIN_IP -j ACCEPT
      ```
- [ ] Preserve volatile evidence
      ```bash
      # Capture current connections
      ss -tpn > /tmp/evidence-connections-$(date +%s).txt
      
      # Capture running processes
      ps auxf > /tmp/evidence-processes-$(date +%s).txt
      
      # Capture network connections with PIDs
      lsof -i -n -P > /tmp/evidence-network-$(date +%s).txt
      
      # Start packet capture
      tcpdump -i eth0 -w /tmp/evidence-pcap-$(date +%s).pcap &
      
      # Memory dump (if warranted for S3+)
      # dd if=/dev/mem of=/tmp/evidence-mem-$(date +%s).raw bs=1M
      ```

### Containment Verification
- [ ] Can the attacker still access the system? (test from outside)
- [ ] Is the compromised credential still valid? (test authentication)
- [ ] Are C2 channels still reachable? (DNS lookup, connection test)
- [ ] Is lateral movement still possible? (scan adjacent systems)

### Communication
- [ ] Incident channel created (Slack/Teams/Signal)
- [ ] Stakeholders notified per severity matrix
- [ ] Status page updated (if customer-facing)

**Containment confirmed:** [timestamp UTC]
**Time to contain:** [minutes]
```

---

## Phase 2: ERADICATE — "Remove the Threat"

**Goal:** Remove the attacker's access, clean affected systems, patch the entry point.
**Target Time:** 1-4 hours (varies with severity).

### Eradication Checklist

```markdown
## Eradication Checklist — Incident #[___]

**Eradication started:** [timestamp UTC]

### Root Cause Identification
- [ ] How did the attacker get in? (initial access vector)
      - [ ] Credential compromise
      - [ ] Vulnerability exploitation
      - [ ] Social engineering
      - [ ] Supply chain
      - [ ] Insider
      - [ ] Physical access
      - [ ] Unknown (document what you DO know)
- [ ] What did the attacker do? (see: forensics/timeline-reconstruction.md)
- [ ] What's the full scope? (all affected systems, accounts, data)

### Removal Actions
- [ ] Remove attacker artifacts
      ```bash
      # Check for unauthorized SSH keys
      find /home -name "authorized_keys" -exec grep -l "unknown_key" {} \;
      
      # Check for unauthorized cron jobs
      for user in $(cut -d: -f1 /etc/passwd); do
        crontab -l -u $user 2>/dev/null | grep -v "^#" | \
          grep -v "^$" && echo "^^^ User: $user"
      done
      
      # Check for unauthorized systemd services
      systemctl list-units --type=service --state=running | grep -v known_service
      
      # Check for SUID/SGID changes
      find / -perm -4000 -o -perm -2000 2>/dev/null | \
        diff - /var/log/nemesis/baseline-suid.txt
      
      # Check for new/modified files in web root
      find /var/www -newer /var/log/auth.log -type f
      
      # Check /tmp and /dev/shm for dropped tools
      ls -la /tmp/ /dev/shm/ /var/tmp/
      ```
- [ ] Patch the vulnerability (if applicable)
      ```bash
      # Apply security updates
      apt update && apt upgrade -y
      
      # Or patch specific package
      apt install --only-upgrade vulnerable-package
      ```
- [ ] Rotate ALL credentials (not just the compromised one — assume breach)
      ```bash
      # Rotate SSH host keys
      rm /etc/ssh/ssh_host_*
      dpkg-reconfigure openssh-server
      
      # Force password change for all users
      chage -d 0 -M 90 username
      
      # Rotate API keys, database passwords, service accounts
      # [system-specific — do them ALL]
      ```
- [ ] Verify removal
      ```bash
      # Re-run file integrity check
      aide --check
      
      # Scan for known backdoor indicators
      rkhunter --check --skip-keypress
      
      # Verify no unauthorized network listeners
      ss -tlnp | diff - /var/log/nemesis/baseline-listeners.txt
      ```

### Scope Verification
- [ ] All affected systems identified and cleaned
- [ ] All compromised credentials rotated
- [ ] Entry point patched
- [ ] No remaining attacker artifacts
- [ ] Adjacent systems verified clean

**Eradication confirmed:** [timestamp UTC]
**Time to eradicate:** [hours]
```

---

## Phase 3: RECOVER — "Back to Boring Normal"

**Goal:** Restore normal operations. Verify everything works. Monitor for re-compromise.
**Target Time:** Varies with damage.

### Recovery Checklist

```markdown
## Recovery Checklist — Incident #[___]

**Recovery started:** [timestamp UTC]

### System Restoration
- [ ] Restore from clean backup (if system was compromised beyond cleaning)
      ```bash
      # Verify backup integrity before restoring
      sha256sum backup.tar.gz
      # Compare against known-good hash
      
      # Restore
      tar xzf backup.tar.gz -C /
      
      # Apply all patches BEFORE reconnecting to network
      apt update && apt upgrade -y
      ```
- [ ] Apply hardening (see: counters/boring-defenses.md)
      - [ ] Firewall rules reviewed and tightened
      - [ ] SSH config hardened (key-only, no root login)
      - [ ] Unnecessary services disabled
      - [ ] File integrity monitoring rebaselined
- [ ] Deploy new credentials
      - [ ] New SSH keys distributed
      - [ ] New API keys configured
      - [ ] New database passwords set
      - [ ] MFA verified/enabled

### Validation
- [ ] Service functionality verified
      ```bash
      # Health checks
      curl -s -o /dev/null -w "%{http_code}" https://yourservice.com/health
      
      # Database connectivity
      psql -c "SELECT 1" || mysql -e "SELECT 1"
      
      # Application tests
      ./run-smoke-tests.sh
      ```
- [ ] Monitoring confirmed operational
      - [ ] Log collection verified
      - [ ] Alerting verified (send test alert)
      - [ ] Metrics dashboards showing data
- [ ] Containment measures removed (gradually)
      ```bash
      # Remove emergency firewall rules
      iptables -D INPUT -s ATTACKER_IP -j DROP
      iptables -D OUTPUT -d ATTACKER_IP -j DROP
      
      # Re-enable network connectivity
      # (Do this gradually — monitor for re-compromise)
      ```

### Post-Recovery Monitoring (72-Hour Watch)
- [ ] Enhanced logging enabled
- [ ] Alert thresholds lowered temporarily
- [ ] Manual log review at T+24h, T+48h, T+72h
- [ ] Any sign of re-compromise? If yes → back to Phase 1

**Recovery confirmed:** [timestamp UTC]
**Time to recover:** [hours/days]
**Normal operations resumed:** [timestamp UTC]
```

---

## Phase 4: LEARN — "Lessons Boringly Learned"

**Goal:** Document everything. Update playbooks. Make the next incident even more boring.
**Target Time:** 48 hours after recovery.

### Post-Mortem Template

```markdown
# Post-Mortem Report — Incident #[___]

**Date:** [date]
**Author:** Nemesis
**Classification:** [S0-S4]
**Status:** Resolved / Monitoring / Ongoing

## Executive Summary
[2-3 sentences: what happened, impact, resolution, current status]

## Timeline
| Time (UTC) | Phase | Event |
|---|---|---|
| [timestamp] | Detection | [how was it detected] |
| [timestamp] | Containment | [what was contained] |
| [timestamp] | Eradication | [what was removed/patched] |
| [timestamp] | Recovery | [when normal ops resumed] |

## Metrics
| Metric | Value | Target | Status |
|---|---|---|---|
| Time to detect (TTD) | [minutes] | < 15 min | ✅/❌ |
| Time to contain (TTC) | [minutes] | < 30 min | ✅/❌ |
| Time to eradicate (TTE) | [hours] | < 4 hrs | ✅/❌ |
| Time to recover (TTR) | [hours] | < 8 hrs | ✅/❌ |
| Total downtime | [hours] | < 1 hr | ✅/❌ |
| Data exposed | [records/files/none] | 0 | ✅/❌ |

## Root Cause Analysis
### What happened
[Detailed technical description]

### Why it happened
[Contributing factors — no blame, just facts]

### Why we didn't prevent it
[What gap in defenses allowed this]

### Why we didn't detect it faster
[What gap in monitoring allowed delay]

## What Went Well
- [thing that worked as designed]
- [thing that saved time/damage]
- [boring counter that activated]

## What Went Poorly
- [thing that slowed response]
- [thing that was missing]
- [thing that caused confusion]

## Action Items
| # | Action | Owner | Due Date | Status |
|---|---|---|---|---|
| 0 | [boring counter to add] | [who] | [when] | ⬜ |
| 1 | [playbook update] | [who] | [when] | ⬜ |
| 2 | [monitoring improvement] | [who] | [when] | ⬜ |
| 3 | [training/process change] | [who] | [when] | ⬜ |

## Playbook Updates
- [ ] This incident type added to playbook
- [ ] Detection rules updated
- [ ] Alert thresholds adjusted
- [ ] Boring counter catalogued in feddit/counters/

## Filed
- Post-mortem: feddit/breach-data/post-mortems/[filename]
- Timeline: feddit/forensics/timelines/[filename]
- IoCs: feddit/breach-data/indicators/[filename]
- Counter: feddit/counters/[filename]
```

### The Blameless Post-Mortem

```
Rules:
0. No blame. Systems fail. Humans make mistakes. Processes are what we fix.
1. Focus on "what" and "how", never "who" (unless it's Nemesis, who accepts all blame stoically).
2. Every failure is a boring counter waiting to be catalogued.
3. If the same incident happens twice, the post-mortem from the first time failed.
4. The measure of success is not zero incidents — it's boring incidents.
```

---

## Severity Reference Card

Quick-reference for classification and response:

```
╔═══════╦══════════════════════════════════╦═══════════════╦════════════════╗
║ Level ║ Description                      ║ Response Time ║ Responders     ║
╠═══════╬══════════════════════════════════╬═══════════════╬════════════════╣
║ 😴 S0 ║ False positive, non-event        ║ When bored    ║ Nobody         ║
║ 🤔 S1 ║ Minor: contained, no data loss   ║ Same day      ║ Nemesis        ║
║ 🟡 S2 ║ Moderate: limited exposure       ║ < 1 hour      ║ Nemesis+Daimyo ║
║ 🔴 S3 ║ Severe: confirmed compromise     ║ Immediate     ║ All + Human    ║
║ ⚫ S4 ║ Catastrophic: full breach        ║ All hands NOW ║ Everyone       ║
╚═══════╩══════════════════════════════════╩═══════════════╩════════════════╝
```

---

## The Goal

```
After enough incidents are documented and playbooked:

  S0-S1  → Handled by automation (scripts, fail2ban, rate limiters)
  S2     → Handled by checklist (open playbook, follow steps)
  S3     → Handled by trained responders following playbook
  S4     → Never happens because S3 was handled boringly well

Eventually, every incident is boring.

That's not complacency. That's engineering.
That's not apathy. That's preparation.
That's not ignoring threats. That's having already catalogued them.

The win state is boredom. 😴
```

---

> *The paladin doesn't fear the dragon. The paladin has a 47-step checklist for dragons. The dragon, upon seeing the checklist, usually leaves.*
>
> — Nemesis, laminating the checklist, again
