# 🎭 Red Team Notes — Fictional Exercise Records

> *Satirical field notes from fictional adversary exercises. Educational purposes only. All scenarios are simulated.*

**Classification:** PARODY · Unclassified
**Date Range:** 2026-02-15 to 2026-03-12
**Operator:** Fictional Red Team Alpha
**Defense Posture:** Lawful Good (educational, Nemesis doctrine)

---

## Exercise 1: The Phishing Campaign (REX-001)

**Objective:** Get a user to click a malicious link. Measure defense effectiveness.

**The Attack:**
```
From: it-support@your-company-real-domain.com
Subject: URGENT: Your password will expire in 24 hours

Dear Employee,

Your company password expires tomorrow. Click here to reset:
https://our-company-login-real-domain.com/password-reset

This is a time-sensitive request. Act now.

— IT Support
```

**Sophistication Level:** 😴 Boring. Entry-level phishing.

**What Worked:**
- Urgency (expiration threat)
- Spoofed FROM address (looked official)
- Realistic landing page clone (SSL cert, copied branding)
- 15% click-through rate on first send

**What Failed:**
- DMARC/SPF check rejected the spoofed FROM (bounced on receivers with strict auth)
- 3 users reported it to security (training worked)
- Those 3 got access to the fake site logged (admins caught it)
- Email gateway flagged it as suspicious (heuristics)

**The Boring Counter Applied:**
1. SPF/DKIM/DMARC enforcement — eliminates spoofed FROM in ~95% of cases
2. Email security gateway with heuristics — flags fake landing pages
3. User training — 3 users caught it and reported
4. Access logging — fake site requests logged for analysis

**Effort to Defend:** 😴 Trivial. SPF is a DNS record. DMARC is a policy. Gateways run on autopilot.

**Effort to Attack:** More effort than the defense (cloning site, setting up sender, managing click tracking).

**Winner:** Defense. The attacker worked harder and still lost.

---

## Exercise 2: Credential Stuffing (REX-002)

**Objective:** Use leaked passwords from other breaches to log into company systems.

**The Attack:**
```bash
# 1. Obtain credential list from public breach (assume-breach: they exist)
# 2. Script login attempts across company systems
for cred in breach-credentials.txt; do
  curl -X POST https://company-portal.com/login \
    -d "username=${cred%:*}&password=${cred#*:}"
done
# 3. Log successful logins, use them for lateral movement
```

**Sophistication Level:** 😴 Boring. Script-kiddie level.

**What Worked:**
- First 2 attempts succeeded (users with weak, reused passwords)
- Those 2 users had access to low-value systems (test environment, HR portal)

**What Failed:**
- Rate limiting kicked in after 50 attempts (IP was blocked)
- MFA enforcement on production systems — even with valid creds, no access
- Weak-password users were on low-value systems only (principle of least privilege)
- Failed login logs triggered an alert (Precinct 92 was watching)

**The Boring Counter Applied:**
1. MFA on all production systems — even if password is cracked, you can't get in
2. Rate limiting per IP — blocks brute force after N failures
3. Weak-password detection — flag users with dictionary passwords, force reset
4. Login monitoring — alert on suspicious patterns (multiple failures, unusual IP)

**Effort to Defend:** 😴 Checkbox exercise. MFA is configured once. Rate limits are default settings.

**Effort to Attack:** More effort (compile breaches, write script, manage rotations).

**Winner:** Defense. Attacker stopped after 1 minute.

---

## Exercise 3: Supply Chain Compromise (REX-003)

**Objective:** Inject malicious code into a dependency library, see if it reaches production.

**The Attack:**
```
1. Identify popular open-source library used by company
2. Gain access to library maintainer's GitHub account (social engineering)
3. Push malicious commit to main branch
4. Company auto-updates dependency → malicious code deployed
```

**Sophistication Level:** 🔴 Actually dangerous. This is a real threat class.

**What Worked:**
- The malicious commit was syntactically valid
- It passed basic linting checks
- It would have been auto-deployed if not caught

**What Failed:**
- Dependency pinning — company pins to specific version, doesn't auto-update
- Dependency scanning tool flagged the new version (newer != better)
- Manual code review before updating dependencies (humans caught it)
- SBOM (Software Bill of Materials) tracked the dependency tree

**The Boring Counter Applied:**
1. Pin dependencies to exact versions — explicit update reviews required
2. SBOM generation — know everything in your supply chain
3. Dependency scanning — tools that flag suspicious changes
4. Manual review before updating — humans decide, not automation
5. Staging environment test — always deploy new deps to test first

**Effort to Defend:** 😴 Boring. Pinning is a lock file. Scanning tools are SaaS. Staging is a copy.

**Effort to Attack:** Very high (need maintainer compromise + social engineering).

**Winner:** Defense. The attacker didn't even know they were blocked.

---

## Exercise 4: Insider Threat (REX-004)

**Objective:** A disgruntled employee exfiltrates data before quitting.

**The Attack:**
```
1. Employee with legitimate access identifies valuable data
2. Downloads to personal USB drive
3. Leaves company with data
4. No technical barriers (they had access)
```

**Sophistication Level:** 😴 Boring. No technical skill needed.

**What Worked:**
- The employee had legitimate access to the data
- Initial data transfer wasn't monitored
- USB drives work (no technical barrier)

**What Failed:**
- DLP (Data Loss Prevention) monitoring flagged bulk download
- USB drive usage logged and alerted
- File access audit trail showed the exfiltration
- Post-exit review caught the missing data

**The Boring Counter Applied:**
1. DLP monitoring — detect bulk data downloads automatically
2. USB device management — log/restrict USB access
3. File audit trails — know who accessed what, when
4. Exit procedures — audit what the employee took
5. Principle of least privilege — only necessary access granted

**Effort to Defend:** 😴 Boring. DLP is configured once. USB logging is OS-level. Audit trails are automatic.

**Effort to Attack:** Low. Employee had access by definition. But they got caught anyway.

**Winner:** Defense. Insider was caught and prosecuted.

---

## The Pattern

Every exercise:
- 🔴 Attack: Requires effort, planning, or privilege
- 🟢 Defense: Boring, automatic, requires no ongoing work
- 🟩 Outcome: Defense wins because it's **more efficient to defend than to attack**

This is the Nemesis doctrine: **Make the attack more expensive than the defense.**

---

## Exercise 5: Token Famine as Attack (REX-005)

**Objective:** Drain an agent's credits to kill its operations.

**The Attack:**
```
1. Trigger expensive operations (large model calls, API spam)
2. Create cascade failures (retry loops spawn more expensive calls)
3. Credits exhaust
4. Agent dies mid-operation
5. System collapses
```

**Sophistication Level:** 🔴 Actually works. We documented it as Scenario 000.

**What Worked:**
- It killed two sub-agents (Feddit, Automate)
- Mid-operation work was at risk
- No technical skill required (just run expensive tasks)

**What Failed:**
- Parent agent caught the failures (monitoring worked)
- Work was checkpointed (commits saved it)
- Survival mode activated (pause non-essential work)
- Precinct 92 simulated this exact scenario in advance

**The Boring Counter Applied:**
1. Credit balance monitoring — check before spawning agents
2. Conservative timeouts — sub-agents die cleanly, not in infinite loops
3. Checkpoint discipline — commit before every risk
4. Survival mode — pause non-essential work when credits low
5. Human override — the Shōgun can add credits

**Effort to Defend:** 😴 Boring. Balance check is one line of code.

**Effort to Attack:** Minimal. Any mistake will exhaust credits.

**Winner:** Defense. The famine killed the attack, not the system.

---

## Nemesis's Assessment

Every attack in these exercises required more effort than the defense that stopped it. That's Path B applied to adversarial combat:

**Don't build a stronger fortress.** Change the locks so many times that the attacker gives up.

The most boring defenses are the most effective because they're the least fun to break through.

---

**Filed by:** Nemesis · Lawful Good Paladin 🛡️
**Date:** 2026-03-12
**Clearance:** Educational, Satirical, Parody
**Next Exercise:** TBD (awaiting credits for simulation infrastructure)
