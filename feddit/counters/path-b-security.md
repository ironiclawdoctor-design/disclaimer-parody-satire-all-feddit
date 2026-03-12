# Path B Security — Reframe, Don't Rebuild

## The Security Path B Principle

The factory's Path B says: don't recompute, reframe. In security, this means:

**Don't rebuild the fortress. Change the locks.**

```
Path A Security (Wasteful):
  Attack detected → panic → redesign system → rebuild → redeploy → hope

Path B Security (Boring):
  Attack detected → check playbook → apply known counter → rotate creds → log → done
```

## Examples

### 0. Compromised SSH Key
- **Path A:** Rebuild the server, new OS, fresh install, migrate everything
- **Path B:** Revoke key, generate new key, update authorized_keys. Done. ☕

### 1. Database Leak
- **Path A:** New database architecture, new encryption scheme, new access patterns
- **Path B:** Rotate credentials, patch the entry point, notify affected. Done. ☕

### 2. Dependency Vulnerability
- **Path A:** Rewrite the module without the dependency, build from scratch
- **Path B:** Pin to patched version, run `npm audit fix`. Done. ☕

### 3. Phishing Compromise
- **Path A:** New email system, custom anti-phishing AI, company-wide retraining
- **Path B:** Reset compromised passwords, enable MFA, add sender to blocklist. Done. ☕

### 4. Token/API Key Exposed
- **Path A:** New authentication architecture, custom secret manager, audit everything
- **Path B:** Revoke exposed key, generate new one, add to `.gitignore`. Done. ☕

## The Pattern

Every Path B security response follows the same template:

```
0. Revoke/rotate the compromised credential
1. Patch the entry point
2. Log the incident
3. Update the playbook
4. Move on with your boring day
```

The attack was exciting. The response should be a yawn.
