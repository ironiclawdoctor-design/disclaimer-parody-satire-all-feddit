# Scenario 000: Token Famine (Real Event)

> **Classification:** S1 — Minor, contained, no data loss
> **Date:** 2026-03-12
> **Source:** Real incident during agency bootstrap

## What Happened

0. Official sub-agent spawned to bootstrap deception-floor-commodity-factory
1. 56 seconds into task, Ampere credits exhausted (HTTP 402)
2. Sub-agent terminated mid-operation
3. Work-in-progress existed but was uncommitted
4. Parent agent (Fiesta) detected failure and manually completed the work

## Attack Vector Analysis (Satirical)

This wasn't an "attack" — it was **resource exhaustion**, the most boring threat class. But modeled as assume-breach:

- **Attacker:** Reality (the ultimate adversary)
- **Vector:** Economic — credit balance depletion
- **Impact:** Sub-agent death, potential work loss
- **Sophistication:** Zero. Literally just ran out of money.
- **Boring counter applied:** Parent agent caught and completed the work manually

## Lessons (Boring)

0. Sub-agents die first in resource famines (they're the canary)
1. Uncommitted work is at-risk work (commit early, commit often)
2. Parent recovery patterns work (the chain of command held)
3. Check balance before spawning sub-agents (trivially preventable)
4. The most dangerous attack is the one that's too boring to prepare for

## Counter Added

```
Before spawning sub-agent:
  0. Check credit balance
  1. Set conservative timeout
  2. Instruct sub-agent to commit early
  3. Parent monitors for 402/failure
  4. Parent catches falling work if child dies
```

**Effort level:** 😴 Boring. Checklist item.

## Post-Mortem Status

✅ Documented
✅ Counter designed
✅ Playbook updated
✅ Filed in Precinct 92 resistance log (R-001)
