# Feddit Setup & Deployment

## Quick Start

### 1. Start the Web Server

```bash
cd /root/.openclaw/workspace/disclaimer-parody-satire-all-feddit/feddit
./start.sh
```

Server will listen on:
- **Local:** http://localhost:8888
- **Tailscale:** http://<your-tailscale-ip>:8888

### 2. Access Feddit

**From localhost:**
```
http://localhost:8888
```

**From Tailscale (private network):**
```
http://100.x.x.x:8888  # Your Tailscale IP
```

**Direct links:**
- Home: http://localhost:8888/index.html
- Deposit (Crypto): http://localhost:8888/deposit.html
- Volunteer (Time): http://localhost:8888/volunteer-signup.html
- Forensics: http://localhost:8888/forensics/
- Wetwork: http://localhost:8888/wetwork/
- Counters: http://localhost:8888/counters/

### 3. Manage Feddit

**View breach records:**
```bash
./mod-cli.sh list
```

**Annotate a record:**
```bash
./mod-cli.sh annotate Nemesis forensics/phishing-2026-03-12.md "Pattern matches PATTERN-001"
```

**Categorize records:**
```bash
./mod-cli.sh categorize Nemesis forensics/phishing-2026-03-12.md counters
```

**Check access logs:**
```bash
tail -f feddit-server.log
cat access.jsonl | jq '.'
```

---

## Architecture

### Files

```
feddit/
├── index.html                    # Landing page
├── deposit.html                  # Crypto deposit UI
├── volunteer-signup.html         # Volunteer form
├── deposit-instructions.md       # Deposit guide
├── server.js                     # HTTP server (Node.js)
├── mod-cli.sh                    # Admin mod CLI
├── volunteers.sh                 # Volunteer registry
├── start.sh                      # Startup script
├── SETUP.md                      # This file
│
├── forensics/                    # Breach analysis
├── wetwork/                      # Offensive techniques
├── counters/                     # Defensive controls
├── disclaimer/                   # Terms & privacy
│
├── access.jsonl                  # Access log (all reads)
├── mod-actions.jsonl             # Mod log (all annotations)
├── volunteers.db                 # Volunteer registry
└── feddit-server.log             # Server log
```

### Security

- **Private network only** (Tailscale, no public routing)
- **No write from web UI** (mod-cli.sh only for admins)
- **All reads logged** (access.jsonl)
- **All writes logged** (mod-actions.jsonl)
- **Assume breach** (expect logs may be leaked)

### Cost

**$0.00** (Tier 0)
- Node.js server (already installed)
- Bash scripts (system utility)
- Static HTML (no external CDN)
- Tailscale VPN (you already have it)

---

## Operations

### Stop the Server

```bash
kill $(pgrep -f 'node server.js')
```

### View Server Logs

```bash
tail -f feddit/feddit-server.log
```

### Check Access Activity

```bash
jq -r '.timestamp + " | " + .type + " | " + .path' feddit/access.jsonl | tail -20
```

### Export Volunteer Roster

```bash
./volunteers.sh export > ../../../CONTRIBUTORS.md
```

---

## Integration with Agency

### Ledger

When volunteers log hours, record in accounting:

```bash
/root/.openclaw/workspace/agency-wallet/ledger.sh log <volunteer_id> "Feddit Development" "Built X feature" <hours>
```

### Monitoring

Actually watches for writes to memory/YYYY-MM-DD.md. If Feddit is operational, it should log activity there daily.

### Reconciliation

Run monthly:

```bash
/root/.openclaw/workspace/agency-wallet/reconcile.sh
```

Verify: Ledger balance = Wallet balance (or flag variance)

---

## Feddit as Deception Floor

Everything on Feddit is treated as potentially fictional:

- Breach records may be real or simulated
- Forensics may be actual post-mortems or educational reconstructions
- "Wetwork" section is offensive education, not actual attacks
- All tagged with satire/parody disclaimer

**Goal:** Study attack/defense in a controlled, documented, auditable environment.

---

## Frequently Asked Questions

**Q: How do I access Feddit from outside Tailscale?**
A: You don't. It's private network only. If you need public access, you're thinking about it wrong.

**Q: Can I contribute breach records?**
A: Yes. Fill out the volunteer form, then contact leadership. Records are reviewed before publishing.

**Q: What if I find a real vulnerability in Feddit?**
A: Report it to leadership immediately. Include: description, severity, reproduction steps, proposed fix.

**Q: Can I run my own Feddit instance?**
A: Yes. Fork the repo, modify, deploy. It's open source. All code auditable.

---

## Next Steps

1. **Start server:** `./start.sh`
2. **Access:** http://localhost:8888
3. **Recruit:** Share volunteer link with interested contributors
4. **Fund:** Accept crypto via deposit page
5. **Document:** Log all activities to ledger
6. **Reconcile:** Monthly blockchain ↔ books verification
7. **Iterate:** Improve based on volunteer feedback

---

**Status:** Ready to deploy.

**Cost:** $0.00

**Questions?** Read the code. It's all bash and HTML.
