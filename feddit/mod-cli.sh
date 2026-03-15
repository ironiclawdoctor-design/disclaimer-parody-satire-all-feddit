#!/bin/bash
# Feddit Mod CLI
# 
# Allows agents to annotate, categorize, and update breach records
# All changes logged to mod-actions.jsonl
# Cost: $0.00 (Tier 0 — bash)

set -e

FEDDIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_LOG="${FEDDIT_DIR}/mod-actions.jsonl"
BREACH_DIR="${FEDDIT_DIR}/breach-data"

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log_action() {
  local agent="$1"
  local action="$2"
  local record="$3"
  local notes="$4"
  
  jq -n \
    --arg ts "$(timestamp)" \
    --arg agent "$agent" \
    --arg action "$action" \
    --arg record "$record" \
    --arg notes "$notes" \
    '{timestamp: $ts, agent: $agent, action: $action, record: $record, notes: $notes}' >> "$MOD_LOG"
}

# Commands

list_records() {
  echo "📁 Breach records in Feddit:"
  find "$BREACH_DIR" -type f -name "*.md" -o -name "*.jsonl" | sort
}

view_record() {
  local record="$1"
  local filepath="${BREACH_DIR}/${record}"
  
  if [[ ! -f "$filepath" ]]; then
    echo "❌ Record not found: $record"
    return 1
  fi
  
  echo "📄 $record:"
  cat "$filepath"
}

annotate_record() {
  local agent="$1"
  local record="$2"
  local annotation="$3"
  
  local filepath="${BREACH_DIR}/${record}"
  
  if [[ ! -f "$filepath" ]]; then
    echo "❌ Record not found: $record"
    return 1
  fi
  
  echo ""
  echo "---"
  echo "**Mod annotation by $agent:** $annotation"
  echo "**Timestamp:** $(timestamp)"
  echo "" >> "$filepath"
  
  log_action "$agent" "annotate" "$record" "$annotation"
  echo "✅ Annotation logged"
}

categorize_record() {
  local agent="$1"
  local record="$2"
  local category="$3"
  
  # Categories: forensics, wetwork, counters, disclaimer
  if [[ ! "$category" =~ ^(forensics|wetwork|counters|disclaimer)$ ]]; then
    echo "❌ Invalid category: $category"
    echo "   Valid: forensics, wetwork, counters, disclaimer"
    return 1
  fi
  
  local source="${BREACH_DIR}/${record}"
  local dest="${FEDDIT_DIR}/${category}/${record}"
  
  if [[ ! -f "$source" ]]; then
    echo "❌ Record not found: $record"
    return 1
  fi
  
  mkdir -p "${FEDDIT_DIR}/${category}"
  cp "$source" "$dest"
  
  log_action "$agent" "categorize" "$record" "→ $category"
  echo "✅ Record categorized: $category"
}

# Main
case "${1:-help}" in
  list)
    list_records
    ;;
  view)
    view_record "$2"
    ;;
  annotate)
    annotate_record "$2" "$3" "$4"
    ;;
  categorize)
    categorize_record "$2" "$3" "$4"
    ;;
  help|--help|-h)
    cat << EOF
🛡️  Feddit Mod CLI

Usage: mod-cli.sh <command> [args]

Commands:
  list                           List all breach records
  view <record>                  View a breach record
  annotate <agent> <record> <note>  Add annotation to record
  categorize <agent> <record> <cat>  Categorize record (forensics|wetwork|counters|disclaimer)
  help                           Show this help

Examples:
  ./mod-cli.sh list
  ./mod-cli.sh view forensics/phishing-2026-03-12.md
  ./mod-cli.sh annotate Nemesis forensics/phishing-2026-03-12.md "Pattern matches PATTERN-001"
  ./mod-cli.sh categorize Nemesis forensics/phishing-2026-03-12.md counters

All mod actions are logged to: mod-actions.jsonl
EOF
    ;;
  *)
    echo "❌ Unknown command: $1"
    echo "   Run: mod-cli.sh help"
    exit 1
    ;;
esac
