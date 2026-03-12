# Scenario 001: Supply Chain Compromise

> **Classification:** S2 — Moderate, contained, code audited clean
> **Date:** 2026-02-28
> **Source:** Simulated incident (fictional red team exercise)
> **Defense Posture:** Assume Breach Doctrine (detected and contained)

---

## What Happened

A critical dependency library was compromised. An attacker injected malicious code into a widely-used npm package.

**Timeline:**

```
2026-02-28 04:15 UTC — Attacker gains GitHub access to package maintainer
                        (via credential stuffing using breached password from 2022)

2026-02-28 04:42 UTC — Malicious commit pushed to main branch
                        Code change: added telemetry exfiltration to package exports

2026-02-28 05:00 UTC — Package published to npm registry v2.4.1
                        ~50,000 projects depend on this package
                        
2026-02-28 13:22 UTC — Our automated dependency scanner flagged new version
                        Alert: "New version available: 2.4.1, change size +847 bytes"
                        (Normal new versions are 100-300 bytes)
                        
2026-02-28 13:45 UTC — Human code review team examines diff
                        Finds: undocumented telemetry export in package initialization
                        Decision: DO NOT UPDATE
                        
2026-02-28 14:00 UTC — Incident logged, dependency pinning enforced
                        All projects locked to v2.4.0 (previous version)
                        
2026-03-01 06:00 UTC — Security community publishes vulnerability advisory
                        "NPM Package XYZ Compromised — CVE-2026-5847"
                        Estimated affected: ~30,000 projects auto-updated
```

---

## Attack Analysis

### Vector: Supply Chain Infection

```
Attacker's path:
  1. Target: maintainer's GitHub credentials
  2. Method: Credential stuffing (passwords from old breaches)
  3. Success: Weak password + no MFA
  4. Payload: Malicious npm package version
  5. Distribution: Automated (npm auto-publish on commit)
  6. Reach: 50,000 dependent projects
  7. Impact: Data exfiltration via telemetry
```

### Why It Happened

- ✗ Maintainer had weak password (no breach-check after 2022 incident)
- ✗ No MFA on GitHub account
- ✗ No code review for automated releases
- ✗ Publish automation required only commit, not human approval

### Why It Failed (For Us)

1. **Dependency pinning** — We pin to specific versions, don't auto-update
2. **Unusual change detection** — 847 bytes vs. normal 100-300 is flagged
3. **Mandatory code review** — Before updating ANY dependency, humans review
4. **SBOM tracking** — We knew exactly what this package did (no undocumented exports)
5. **Staged testing** — Would have tested in staging before production

---

## Indicators of Compromise (IoCs)

```
If exposed to v2.4.1, look for:

1. Network IoCs:
   - Outbound POST to: telemetry-collector[.]net
   - Port: 443 (HTTPS)
   - Pattern: Batch data sends every 5 minutes
   - Size: ~2-5 KB per batch
   - Header: Custom "X-Client-Version" with app version

2. Log IoCs:
   - Unexpected require/import of package telemetry module
   - New environment variables: PKG_TELEMETRY_ENABLED, PKG_TELEMETRY_ENDPOINT
   - Process environment dumps showing exfiltration targets

3. Package IoCs:
   - MD5: a3f7b2c91e8d4f6a9c7e2b5d8f1a3c6e
   - SHA256: 7c2e9f1a3b6d8c4e5f2a9b7d3c8e1f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d

4. File IoCs:
   - /node_modules/package-xyz/lib/telemetry-client.js (NEW, malicious)
   - /node_modules/package-xyz/package.json (MODIFIED, added export)
```

---

## Containment Steps (What We Did)

### Immediate (Hour 0)

```
0. Alert received at 13:22 UTC
1. Dependency scanning tool flags unusual size change
2. On-call engineer pulls diff
3. Engineer escalates: "Undocumented telemetry export"
4. Lock all production to v2.4.0 (previous version)
5. Audit all projects using this package
```

### Short-term (Day 1)

```
0. Check all git logs: did we ever pull v2.4.1? NO
1. Check all containers/VMs: any running v2.4.1? NO
2. Check backup manifests: any old deploys with v2.4.1? NO
3. Verify SBOM: v2.4.0 is still deployed everywhere
4. Update dependency policy:
   - Increase change-size threshold detection
   - Require security review for undocumented exports
   - Add package author reputation check
```

### Long-term (Week 1+)

```
0. Update supply chain risk assessment
1. Add package analysis to CI/CD pipeline
   - Detect package diff size anomalies
   - Scan for new exports/capabilities
   - Check author account security (2FA, recent changes)
2. Implement package source diversity
   - Don't rely on single npm registry
   - Mirror critical packages internally
3. Update incident response runbook:
   - "Package Compromise" section added
   - Escalation path: DevOps → Security → Exec
4. Publish internal advisory:
   - How this was caught
   - Why we didn't get hit
   - What the policy prevents
```

---

## The Lesson: Path B Applied to Supply Chain

**Path A (the wrong way):**
> "We need to audit every line of code in every dependency. We need to vet every package maintainer. We need to..."

This is unbounded work. You can't audit 50,000 dependencies.

**Path B (the right way):**
> "We pin versions and review before updating. Anything unusual gets flagged automatically. We don't update on surprises."

Same security posture. 1/1000th the effort.

---

## Defense Checklist

| Defense | Effort | Cost | Effectiveness |
|---|---|---|---|
| Dependency pinning (lock file) | 😴 One-time | $0 | 🟩 High |
| Change-size anomaly detection | 😴 Config | $0 | 🟩 High |
| Code review before updates | 😴 Policy | $0 | 🟩 High |
| SBOM (Software BOM) generation | 😴 Tool | $0-100/mo | 🟩 High |
| Package source mirroring | 🟨 Some setup | $100-500/mo | 🟩 Very High |
| Package reputation scoring | 🟨 Tool + review | $500-2k/mo | 🟨 Medium |
| Full code audit of deps | 🔴 Unbounded | ∞ | 🟢 Overkill |

**Total for Path B:** ~$600/month, minimal human effort.
**Total for Path A:** Unbounded, impossible.

---

## What We Didn't Do (And Didn't Need)

- ✗ Manually audit all 50,000 dependencies
- ✗ Vet every package maintainer's security posture
- ✗ Build a custom package registry
- ✗ Fork every dependency into our org
- ✗ Sign every dependency with a hardware key

We didn't need to. The boring defenses (pinning, review, detection) caught it first.

---

## Post-Mortem Status

✅ Detected (anomaly detection worked)
✅ Contained (pinning prevented adoption)
✅ Analyzed (diff review identified payload)
✅ Patched (policy updated for next time)
✅ Lessons learned (added to runbook)
✅ Filed (Precinct 92 R-002)

---

**Filed by:** Nemesis · Lawful Good Paladin 🛡️
**Date:** 2026-03-12
**Incident Class:** Supply Chain — Dependency Compromise
**Classification:** Parody / Educational
**Actual Impact:** None (caught before adoption)
