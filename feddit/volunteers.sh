#!/bin/bash
# Agency Volunteer Registry
# Manages volunteer applications, roster, contributions
# Cost: $0.00 (bash + sqlite3)

set -e

FEDDIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB="${FEDDIT_DIR}/volunteers.db"

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Initialize database
init_db() {
  if [[ ! -f "$DB" ]]; then
    sqlite3 "$DB" << 'EOF'
CREATE TABLE volunteers (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  timezone TEXT,
  roles TEXT, -- comma-separated
  background TEXT,
  hours_per_week TEXT,
  status TEXT DEFAULT 'pending', -- pending, approved, contributor, inactive
  signed_up_at TIMESTAMP NOT NULL,
  approved_at TIMESTAMP,
  approved_by TEXT,
  last_activity TIMESTAMP,
  notes TEXT
);

CREATE TABLE contributions (
  id INTEGER PRIMARY KEY,
  volunteer_id INTEGER NOT NULL,
  project TEXT,
  description TEXT,
  date TIMESTAMP,
  hours INTEGER,
  FOREIGN KEY (volunteer_id) REFERENCES volunteers(id)
);

CREATE TABLE roles_roster (
  volunteer_id INTEGER,
  role TEXT,
  PRIMARY KEY (volunteer_id, role),
  FOREIGN KEY (volunteer_id) REFERENCES volunteers(id)
);
EOF
  fi
}

# Add volunteer
add_volunteer() {
  local name="$1"
  local email="$2"
  local timezone="$3"
  local roles="$4"
  local background="$5"
  local hours="$6"
  
  init_db
  
  sqlite3 "$DB" << EOF
INSERT INTO volunteers (name, email, timezone, roles, background, hours_per_week, signed_up_at)
VALUES ('$name', '$email', '$timezone', '$roles', '$background', '$hours', '$(timestamp)');
EOF
  
  echo "✅ Volunteer registered: $name ($email)"
}

# List pending volunteers
list_pending() {
  init_db
  
  echo "⏳ Pending Approvals:"
  echo ""
  
  sqlite3 "$DB" << EOF
.mode column
.headers on
SELECT id, name, email, hours_per_week, roles, signed_up_at FROM volunteers WHERE status='pending' ORDER BY signed_up_at;
EOF
}

# Approve volunteer
approve_volunteer() {
  local volunteer_id="$1"
  local approver="$2"
  
  init_db
  
  sqlite3 "$DB" << EOF
UPDATE volunteers 
SET status='approved', approved_at='$(timestamp)', approved_by='$approver'
WHERE id=$volunteer_id;
EOF
  
  local name=$(sqlite3 "$DB" "SELECT name FROM volunteers WHERE id=$volunteer_id;")
  local email=$(sqlite3 "$DB" "SELECT email FROM volunteers WHERE id=$volunteer_id;")
  
  echo "✅ Approved: $name ($email)"
  echo "   Send welcome email to: $email"
}

# List all contributors
list_contributors() {
  init_db
  
  echo "🤝 All Contributors:"
  echo ""
  
  sqlite3 "$DB" << EOF
.mode column
.headers on
SELECT id, name, email, status, hours_per_week, signed_up_at FROM volunteers ORDER BY status DESC, signed_up_at;
EOF
}

# Log contribution
log_contribution() {
  local volunteer_id="$1"
  local project="$2"
  local description="$3"
  local hours="$4"
  
  init_db
  
  sqlite3 "$DB" << EOF
INSERT INTO contributions (volunteer_id, project, description, date, hours)
VALUES ($volunteer_id, '$project', '$description', '$(timestamp)', $hours);

UPDATE volunteers SET last_activity='$(timestamp)' WHERE id=$volunteer_id;
EOF
  
  echo "✅ Contribution logged for volunteer #$volunteer_id"
}

# Export roster (for CONTRIBUTORS.md)
export_roster() {
  init_db
  
  echo "# Agency Contributors"
  echo ""
  echo "Thank you to everyone who has donated time, energy, and ideas."
  echo ""
  
  sqlite3 "$DB" << EOF
SELECT 
  '- **' || name || '** (' || email || ') — ' || roles || ', ' || hours_per_week || '/week'
FROM volunteers 
WHERE status IN ('approved', 'contributor')
ORDER BY signed_up_at;
EOF
}

# Usage
case "${1:-help}" in
  add)
    add_volunteer "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
  pending)
    list_pending
    ;;
  approve)
    approve_volunteer "$2" "$3"
    ;;
  list)
    list_contributors
    ;;
  log)
    log_contribution "$2" "$3" "$4" "$5"
    ;;
  export)
    export_roster
    ;;
  help|--help|-h)
    cat << EOF
🤝 Agency Volunteer Registry

Usage: volunteers.sh <command> [args]

Commands:
  add <name> <email> <tz> <roles> <background> <hours>
      Register a new volunteer
  
  pending
      Show pending approvals
  
  approve <volunteer_id> <approver_name>
      Approve a volunteer
  
  list
      Show all contributors
  
  log <volunteer_id> <project> <description> <hours>
      Log a contribution
  
  export
      Export roster for CONTRIBUTORS.md
  
  help
      Show this help

Database: $DB
EOF
    ;;
  *)
    echo "❌ Unknown command: $1"
    echo "   Run: volunteers.sh help"
    exit 1
    ;;
esac
