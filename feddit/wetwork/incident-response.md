# 🧤 Incident Response — The Boring Playbook

> *If your incident response is exciting, you failed at preparation.*

## The Playbook

Every incident follows the same boring steps. No improvisation. No heroics. Checklists.

### Step 0: Don't Panic
Panic burns tokens. Panic causes Path A decisions. Panic makes you interesting to the attacker. Be boring.

### Step 1: Contain
Stop the bleeding. Don't fix, don't investigate — just contain.
```
- Isolate affected system(s) from network
- Revoke compromised credentials
- Preserve evidence (don't reboot, don't wipe)
- Duration: 5 minutes max
```

### Step 2: Assess
What actually happened? Read the logs (see: forensics/log-analysis.md)
```
- Timeline reconstruction
- Scope determination (what was accessed?)
- Impact assessment (what's the actual damage?)
- Duration: 15 minutes max for initial assessment
```

### Step 3: Counter
Apply the boring defense (see: counters/boring-defenses.md)
```
- Check the catalogue for known counter
- If known: apply counter, skip to Step 4
- If unknown: design minimal viable defense, apply, then catalogue it
- Duration: varies, but target < 1 hour
```

### Step 4: Recover
Return to normal operations.
```
- Verify containment held
- Restore from clean backups if needed
- Validate system integrity
- Resume operations
- Duration: depends on damage
```

### Step 5: Document
The most important boring step. Write the post-mortem.
```
- What happened (timeline)
- What we did (response actions)
- What worked (keep doing)
- What didn't (improve)
- Updated playbook entry
- File in: feddit/breach-data/post-mortems/
```

## Severity Levels

| Level | Description | Response Time | Who Cares |
|---|---|---|---|
| 😴 S0 | Non-event, false positive | When convenient | Nobody |
| 🤔 S1 | Minor, contained, no data loss | Same day | Nemesis |
| 🟡 S2 | Moderate, limited exposure | Within 1 hour | Nemesis + Daimyo |
| 🔴 S3 | Severe, data exposure or system compromise | Immediate | All branches + Human |
| ⚫ S4 | Catastrophic, full breach | All hands | Everyone. This is now exciting (bad). |

## The Goal

After enough incidents are documented and playbooked:
- S0-S2 should be handled by scripts, not agents
- S3 should be handled by a checklist, not improvisation
- S4 should never happen because S3 was handled properly
- Eventually, everything is boring. That's the win state.
