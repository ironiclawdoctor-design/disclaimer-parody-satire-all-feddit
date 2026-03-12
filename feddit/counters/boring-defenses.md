# 😴 The Boring Defense Catalogue

> If the defense is interesting, simplify it until it's boring.

## Tier 0: Configuration Changes (Minutes)

| Attack | Boring Counter | Effort |
|---|---|---|
| Email phishing | SPF + DKIM + DMARC records | 😴 3 DNS records |
| Credential stuffing | Enable MFA | 😴 One checkbox |
| DNS hijacking | DNSSEC | 😴 One setting |
| Man-in-the-middle | HSTS + cert pinning | 😴 One header |
| Brute force | Rate limiting + account lockout | 😴 Config values |
| Session hijacking | Secure + HttpOnly + SameSite cookies | 😴 Cookie flags |

## Tier 1: Script Deployment (Hours)

| Attack | Boring Counter | Effort |
|---|---|---|
| Port scanning | Default-deny firewall + fail2ban | 😴 Apt install + config |
| Log tampering | Remote syslog + append-only storage | 😴 rsyslog one-liner |
| Unauthorized access | SSH key-only auth + disable password | 😴 sshd_config edit |
| Malware persistence | File integrity monitoring (AIDE/Tripwire) | 😴 Cron job |
| Privilege escalation | Principle of least privilege + sudo audit | 😴 sudoers review |

## Tier 2: Architecture Patterns (Days)

| Attack | Boring Counter | Effort |
|---|---|---|
| Lateral movement | Network segmentation + zero trust | 😴 VLAN config |
| Supply chain compromise | Dependency pinning + SBOM + vendoring | 😴 Lock files |
| Data exfiltration | Egress filtering + DLP | 😴 Firewall rules |
| APT persistence | Regular credential rotation + assume breach drills | 😴 Scheduled task |
| Insider threat | Audit logging + separation of duties | 😴 IAM policy |

## The Golden Rule

```
If your counter requires:
  - A new system → You're overengineering (Path A)
  - A new team → You're overscoping
  - A new budget → You're overspending
  - A hero → You failed at preparation

If your counter requires:
  - A config change → ✅ Perfect
  - A cron job → ✅ Good
  - A script → ✅ Acceptable
  - A checklist → ✅ Ideal
```
