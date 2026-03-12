# ⚙️ Automation — Let the Boring Stuff Run Itself

> *The most expensive security is the one that requires humans to remember to do it. Automate the boring, and the attacker's boredom is guaranteed.*

**Doctrine:** If a defense requires daily attention, it will be forgotten. If it's automatic, the attacker gives up.

---

## 0. Core Principle: Systemd Timer + Bash Script

Don't build a complicated automation framework. Use what's already on every Linux box:

```bash
#!/bin/bash
# /usr/local/bin/security-checkpoint.sh
# Runs daily. Does boring security stuff while you sleep.

set -e  # Fail hard if anything breaks

echo "[$(date)] Starting security checkpoint..."

# 1. Update packages
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# 2. Rotate logs
sudo journalctl --vacuum=30d

# 3. Check disk space
disk_use=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$disk_use" -gt 80 ]; then
  echo "ALERT: Disk usage at ${disk_use}%" | mail -s "Disk Alert" root
fi

# 4. Verify backups completed
if [ ! -f /backup/last-success ]; then
  echo "ALERT: Backup failed!" | mail -s "Backup Failed" root
else
  echo "[$(date)] Backup OK"
fi

# 5. Audit failed logins
failed=$(grep "Failed password" /var/log/auth.log | wc -l)
if [ "$failed" -gt 100 ]; then
  echo "ALERT: $failed failed login attempts" | mail -s "Login Attacks" root
fi

# 6. Reload firewall rules
sudo ufw reload >/dev/null 2>&1

echo "[$(date)] Security checkpoint complete"
```

**Effort:** 😴 Write once, runs forever.

---

## 1. Automated Updates (fail2ban, unattended-upgrades)

### fail2ban — Auto-block brute force

```bash
# Install
sudo apt-get install fail2ban

# Configure /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600        # Block for 1 hour
findtime = 600        # Within last 10 minutes
maxretry = 5          # After 5 failures

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log

# Start
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

**What it does:** After 5 failed login attempts within 10 minutes, the IP is blocked for 1 hour. Automated.

**Effort:** 😴 Install, configure, forget. No human intervention needed.

**Result:** Brute force attacks hit the wall after 5 tries.

---

### unattended-upgrades — Patch while you sleep

```bash
# Install
sudo apt-get install unattended-upgrades apt-listchanges

# Configure /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Mail "root";  # Alert on patches

# Schedule (in /etc/apt/apt.conf.d/20auto-upgrades)
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
```

**What it does:** Every 24 hours, updates install automatically (security patches first). You wake up patched.

**Effort:** 😴 Configure once. Runs nightly. No human touch.

**Result:** Security holes get fixed before they're exploited.

---

## 2. Log Rotation (logrotate)

```bash
# /etc/logrotate.d/custom-apps
/var/log/myapp.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    missingok
}
```

**What it does:** Every day, archives log files, compresses them, keeps 30 days. Old logs auto-delete.

**Why:** Prevents `/var` from filling up. Disk full = system dies.

**Effort:** 😴 Write once, ignore forever.

---

## 3. Firewall Rules (ufw) — Automation + Intention

```bash
# Default: deny all, allow only what's needed
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Explicit allow list
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS

# Rate limiting
sudo ufw limit 22/tcp    # Max 6 connections per 30s (brute force defense)

# Enable
sudo ufw enable

# Status
sudo ufw status
```

**What it does:** Only traffic explicitly allowed gets through. Everything else blocked.

**Effort:** 😴 Configure once. Firewall handles incoming connections automatically.

---

## 4. Automated Backups (rsync + cron)

```bash
#!/bin/bash
# /usr/local/bin/backup-daily.sh

BACKUP_DIR="/backup/daily"
SOURCE="/home /etc /root"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

# Incremental backup with rsync
rsync -av --delete \
  --exclude='*.tmp' \
  --exclude='.cache' \
  --exclude='.trash' \
  $SOURCE "$BACKUP_DIR/$DATE/"

# Verify backup
if [ -d "$BACKUP_DIR/$DATE" ]; then
  echo "$(date)" > /backup/last-success
  echo "Backup successful: $DATE"
else
  echo "Backup FAILED!" | mail -s "Backup Alert" root
  exit 1
fi

# Clean old backups (keep 30 days)
find "$BACKUP_DIR" -type d -mtime +30 -exec rm -rf {} \;
```

**Cron schedule:**
```bash
# /etc/cron.d/backup
0 2 * * * root /usr/local/bin/backup-daily.sh >/dev/null 2>&1
```

**What it does:** Every day at 2 AM, backs up home + system config. Keeps 30 days.

**Effort:** 😴 Write script, add cron line, forget.

**Result:** If ransomware hits, you have yesterday's backup.

---

## 5. Alert Automation (Monitoring + Mail)

```bash
#!/bin/bash
# /usr/local/bin/daily-security-report.sh
# Runs at 9 AM. Sends email digest of overnight events.

{
  echo "=== Daily Security Report ==="
  echo ""
  echo "Failed logins (last 24h):"
  grep "Failed password" /var/log/auth.log | tail -20
  echo ""
  echo "Sudo usage:"
  grep "sudo" /var/log/auth.log | tail -10
  echo ""
  echo "System load:"
  uptime
  echo ""
  echo "Disk space:"
  df -h /
} | mail -s "Daily Security Report" root
```

**Cron:**
```bash
0 9 * * * root /usr/local/bin/daily-security-report.sh
```

**What it does:** Every morning, mails you a digest of overnight activity.

**Effort:** 😴 Create script, one cron line.

**Result:** You spot anomalies over coffee.

---

## 6. Automated Patching Pipeline (for deployed services)

```bash
#!/bin/bash
# /usr/local/bin/auto-patch-app.sh
# Runs weekly. Pulls latest app version, tests, deploys.

set -e

APP_DIR="/opt/myapp"
GIT_REPO="https://github.com/myorg/myapp.git"

cd "$APP_DIR"

# Fetch latest
git fetch origin
NEW_VERSION=$(git describe --tags origin/main)
CURRENT_VERSION=$(cat VERSION)

if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
  echo "New version available: $NEW_VERSION"
  
  # Pull + test
  git checkout "$NEW_VERSION"
  npm test  # Run test suite
  
  if [ $? -eq 0 ]; then
    # Safe to deploy
    systemctl restart myapp
    echo "$NEW_VERSION" > VERSION
    echo "Deployed $NEW_VERSION" | mail -s "App Patched" root
  else
    # Tests failed, don't deploy
    git checkout "$CURRENT_VERSION"
    echo "Tests failed for $NEW_VERSION" | mail -s "Deploy Failed" root
    exit 1
  fi
fi
```

**Cron:**
```bash
0 3 * * 0 root /usr/local/bin/auto-patch-app.sh
```

**What it does:** Every Sunday at 3 AM, checks for new app versions. If tests pass, deploys. If tests fail, alerts you.

**Effort:** 😴 Tests run automatically.

---

## 7. Secret Rotation (automated)

```bash
#!/bin/bash
# /usr/local/bin/rotate-secrets.sh
# Runs monthly. Rotates API keys, DB passwords, etc.

# Database password rotation
OLD_PASS=$(cat /etc/db-password)
NEW_PASS=$(openssl rand -base64 32)

# Update database
mysql -u root -p"$OLD_PASS" -e "ALTER USER 'app'@'localhost' IDENTIFIED BY '$NEW_PASS';"

# Update config
echo "$NEW_PASS" > /etc/db-password
chmod 600 /etc/db-password

# Restart app (uses new password)
systemctl restart myapp

echo "Password rotated: $(date)" | mail -s "Secret Rotation" root
```

**What it does:** Monthly password rotation. App never knows — just uses the new password.

**Effort:** 😴 Automatic.

---

## 8. Compliance Reporting (automated)

```bash
#!/bin/bash
# /usr/local/bin/compliance-report.sh
# Runs monthly. Audits and reports.

{
  echo "=== Monthly Compliance Report ==="
  echo "Generated: $(date)"
  echo ""
  echo "Patched systems:"
  apt list --upgradable | wc -l
  echo ""
  echo "Failed logins (30 days):"
  grep "Failed password" /var/log/auth.log | wc -l
  echo ""
  echo "Sudo commands (30 days):"
  grep "sudo" /var/log/auth.log | wc -l
  echo ""
  echo "Firewall blocks:"
  sudo ufw status | grep -c "DENY"
  echo ""
} | mail -s "Monthly Compliance Report" ciso@company.com
```

**What it does:** Monthly audit report for compliance officers.

**Effort:** 😴 One script, one cron.

---

## The Pattern: Automation Doctrine

| What | Who | When | Effort |
|---|---|---|---|
| Package updates | unattended-upgrades | Daily, 2 AM | 😴 Zero |
| Login attempts | fail2ban | Real-time | 😴 Zero |
| Log cleanup | logrotate | Daily | 😴 Zero |
| Backups | rsync + cron | Daily, 2 AM | 😴 Zero |
| Alerts | mail + cron | Morning digest | 😴 Zero |
| App patches | auto-patch script | Weekly | 😴 Zero |
| Secret rotation | rotate-secrets | Monthly | 😴 Zero |
| Compliance | reporting script | Monthly | 😴 Zero |

**Total human effort:** Zero. Everything runs on schedule.

**Total attacker effort:** Much higher (work around all the automated defenses).

**Winner:** Boring automation.

---

## The Nemesis Prayer

> *"Automate the boring. The boring defender wins because the attacker has to work harder. An attacker who has to work harder gives up."*

Write your security scripts once. Let them run forever. Go to sleep. Wake up defended.

That's not laziness. That's efficiency.

---

**Filed by:** Nemesis · Lawful Good Paladin 🛡️
**Date:** 2026-03-12
**Doctrine:** Automate everything. Let machines do the boring work.
