# Scenario 002: Insider Threat — Data Exfiltration

> **Classification:** S1 — Minor, contained, employee terminated
> **Date:** 2026-03-05
> **Source:** Simulated incident (fictional employee scenario)
> **Defense Posture:** Assume Breach Doctrine (detection + investigation)

---

## What Happened

An employee with legitimate system access downloaded sensitive data to a personal device, intending to take it after resignation.

**Timeline:**

```
2026-03-01 09:00 — Employee (System Admin) submits 2-week notice
                     "Leaving for startup opportunity"
                     
2026-03-01 14:30 — Access NOT revoked immediately (policy failure)
                    Admin access still active for "transition period"
                    
2026-03-05 23:45 — After-hours database dump
                    Employee connects to database server
                    Runs query: SELECT * FROM customers, payments, secrets
                    ~2.3 GB downloaded via SCP to personal laptop
                    
2026-03-05 23:58 — DLP (Data Loss Prevention) alert triggers
                    "Bulk data download: 2.3 GB in 13 minutes"
                    "Destination: unusual device"
                    Alert sent to security team
                    
2026-03-06 00:05 — Security on-call reviews alert
                    Identifies source: employee's personal laptop
                    Notices employee's credentials, after-hours timing
                    Decision: LOCK ACCOUNT IMMEDIATELY
                    
2026-03-06 00:12 — Employee VPN session terminated
                    SSH key revoked
                    Database password changed
                    
2026-03-06 00:45 — Employee called in (red team called)
                    "We detected unusual database activity from your account"
                    Employee admits: "I was backing up important data"
                    
2026-03-06 09:00 — Investigation begins
                    Forensics: laptop contains exfiltrated data
                    Email audit: employee scouting competitor jobs
                    USB usage logs: personal drive connected 47 times
                    
2026-03-06 17:00 — Incident classified as insider threat
                    Employee terminated for cause
                    Data confirmed to NOT have left facility
                    Criminal investigation initiated (IP jurisdiction dependent)
```

---

## Attack Analysis

### Vector: Trusted Insider Abuse

```
Attacker's path:
  1. Source: Legitimate employee (system admin)
  2. Motivation: Data sale / competitive advantage
  3. Access: System-wide by role
  4. Method: Direct database query, bulk download
  5. Timing: After-hours (lower observation)
  6. Device: Personal laptop (harder to monitor)
  7. Intent: Physical exfiltration (take device when leaving)
```

### Why It Happened

- ✗ Access not revoked immediately after notice (2-week notice = transition period)
- ✗ No real-time monitoring of admin activity
- ✗ No requirement for 2FA on after-hours access
- ✗ No restrictions on USB device usage
- ✗ DLP was reactive (caught after download), not preventive

### Why We Caught It (Defense Worked)

1. **DLP monitoring** — Flagged bulk download in real-time
2. **Unusual pattern detection** — After-hours + bulk data = alert
3. **USB logging** — We knew about 47 USB connections (suspicious)
4. **Rapid response** — On-call security team within 5 minutes of alert
5. **Access revocation** — Immediate lockout prevented further exfiltration
6. **Forensics capability** — Could audit what was taken and when
7. **Exit procedures** — Laptop seized, data verified contained

---

## Indicators of Compromise (IoCs)

```
If missed detection, look for:

1. Access Pattern IoCs:
   - Admin login outside normal hours (2 AM - 5 AM)
   - Query pattern change: SELECT * (dump) vs. normal operational queries
   - Lateral movement: Admin accessing non-work systems
   - Long-running queries: Database full scans taking 10+ minutes

2. Data Transfer IoCs:
   - Large SCP/rsync transfers: >500 MB in <30 minutes
   - Compression: tar/zip of sensitive directories
   - Unusual destinations: Personal email, cloud storage, personal VPS
   - USB activity: Foreign device mounted, large copy operations

3. Behavioral IoCs:
   - Privilege escalation: Requesting root, sudoers changes
   - Credential access: Dumping /etc/shadow, AWS keys, database passwords
   - Archive activity: tar, zip operations on data directories
   - Cleanup attempts: Clearing command history, log deletion

4. Network IoCs:
   - SSH: Non-standard ports, proxy connections
   - SCP: Unusual file sizes, unusual destinations
   - VPN: Connection from unusual geolocations
   - DNS: Queries to suspicious external hosts (cloud storage, crypto, darknet)
```

---

## Containment Steps (What We Did)

### Immediate (Seconds)

```
0. DLP alert received at 23:58 UTC
1. Alert flagged: "Bulk download + admin creds + personal device"
2. Automated response: Session logged out, key revoked
3. Human review: On-call security views audit trail (within 2 minutes)
```

### Urgent (Minutes 5-30)

```
0. Call employee (can't reach, phone off)
1. Secure the personal laptop (physical security)
2. Revoke all credentials
3. Change all passwords employee had access to
4. Audit: What data was accessed?
   - Database query logs show: customers, payments, API keys
   - File access logs show: /etc/credentials, /backup/secrets
5. Containment: Data confirmed on-site (laptop in building)
```

### Short-term (Hours 1-6)

```
0. Forensic imaging of laptop
   - Data verified: 2.3 GB of sensitive data
   - Analysis: How was it taken? (SCP + custom script)
   - Timeline: Exactly when? (logs show 23:45-23:58)
   
1. Investigation
   - Email audit: Competitor communications? 6-month history.
   - Slack audit: Did employee coordinate with others? No.
   - Meetings: Was employee interviewing elsewhere? Yes (personal calendar).
   - Motivation: Opportunistic (taking data "just in case"), not organized crime.

2. Access audit
   - All systems employee ever accessed: 47 systems
   - Data touched: Prioritize by sensitivity
   - Damage assessment: What's exposed?
   
3. Policy violations
   - Employee requested early exit (terminated for cause)
   - Data exposure: 2.3 GB, likely contains:
     * Customer PII (names, emails, purchase history)
     * Payment data (last 4 digits, frequency)
     * Internal API keys (non-production, all rotated)
```

### Long-term (Days 1+)

```
0. Customer notification (required by regulation)
   - "We detected unauthorized access to customer data"
   - "Data was contained on-site"
   - "Monitoring enhanced"
   
1. Policy updates
   - Immediate access revocation on notice (no 2-week transition)
   - Personal device prohibition for admin accounts
   - Mandatory 2FA for after-hours access
   - DLP: block sensitive data to personal devices
   
2. System improvements
   - Real-time admin activity logging (not post-incident)
   - Behavioral analysis: alert on unusual query patterns
   - USB device whitelisting (only approved external drives)
   - Outbound data transfer limits
   
3. Cultural changes
   - Termination for cause (public, documented)
   - Updated insider threat training
   - Clear policy on data ownership
   
4. Legal/HR
   - Criminal referral (IP jurisdiction dependent)
   - Civil suit to recover damages
   - Unemployment appeal denied (termination for cause)
```

---

## The Lesson: Insider Threats Are Hard

**Why:**
- Insiders have legitimate access
- Can't block all their activity (they do real work)
- Motivation is often only revealed post-incident
- No perimeter defense helps (attacker is already inside)

**Solution: Assume Breach**
- Monitor *what* they access, not *if*
- Detect patterns (bulk downloads, unusual queries)
- Respond fast (revoke access immediately)
- Accept: Some risk is inevitable

---

## Defense Checklist

| Defense | Effort | Cost | Effectiveness |
|---|---|---|---|
| DLP monitoring | 🟨 Setup + tuning | $500-2k/mo | 🟩 High |
| Real-time activity logging | 🟨 Infrastructure | $1-5k/mo | 🟩 High |
| Behavioral analysis | 🟨 ML tool | $2-10k/mo | 🟨 Medium |
| Immediate access revocation | 😴 Policy | $0 | 🟩 High |
| USB whitelisting | 😴 Config | $0 | 🟨 Medium |
| 2FA for privileged accounts | 😴 Config | $0 | 🟩 High |
| Exit procedures (laptop seizure) | 😴 Policy + tech | $0 | 🟨 Medium |
| Background checks | 🟨 One-time per hire | $100-500 | 🟨 Low |
| Trust nobody (air-gapped secrets) | 🔴 Unbounded | ∞ | 🟩 Perfect |

**Total for Path B (practical):** ~$3-20k/mo, strong detection + response.
**Total for Path A (impossible):** Can't prevent insiders. Insider IS the perimeter.

---

## What We Didn't Do

- ✗ Trust employees implicitly
- ✗ Wait for exit interview to discover data theft
- ✗ Assume "good employees don't steal"
- ✗ Remove DLP because "it's invasive" (it's not)
- ✗ Allow 2-week admin access after notice

---

## Post-Mortem Status

✅ Detected (DLP alert worked)
✅ Contained (access revoked before exfiltration)
✅ Investigated (forensics confirmed scope)
✅ Responded (employee terminated, data secured)
✅ Improved (policies updated for next insider)
✅ Filed (Precinct 92 R-003)

---

## Nemesis's Assessment

Insider threats are the hardest attack because the attacker has legitimate keys. But they're also the *most detectable* because legitimate access generates audit trails.

The defense isn't "prevent insiders." It's "detect betrayal before it matters."

This scenario proves it works.

---

**Filed by:** Nemesis · Lawful Good Paladin 🛡️
**Date:** 2026-03-12
**Incident Class:** Insider Threat — Trusted Access Abuse
**Classification:** Parody / Educational
**Actual Impact:** None (caught before physical exfiltration)
