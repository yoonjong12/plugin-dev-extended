#!/usr/bin/env bash
# analyze-skills.sh <plugin-dir>
# Scans all SKILL.md files in a Claude Code plugin and triages each by scriptable pattern detection.

PLUGIN_DIR="${1:?Usage: analyze-skills.sh <plugin-dir>}"
SKILLS_DIR="$PLUGIN_DIR/skills"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "ERROR: No skills/ directory found in $PLUGIN_DIR" >&2
  exit 1
fi

echo "Plugin: $PLUGIN_DIR"
echo ""
printf "%-35s %-14s %-14s %-14s %-16s\n" "Skill" "WS-Loop" "State-Write" "Template" "Category"
printf "%-35s %-14s %-14s %-14s %-16s\n" "-----" "-------" "-----------" "--------" "--------"

TARGET_COUNT=0
SKIP_COUNT=0

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  [ -f "$skill_md" ] || continue

  has_ws_loop="no"
  has_state_write="no"
  has_template="no"

  # Workspace detection: bash while-loop walking up directory tree
  grep -qE 'while \[ "\$DIR" != "/" \]|while \[ .DIR. != ./.* \]' "$skill_md" && has_ws_loop="YES"

  # State JSON writes: json.dump, json.load, or direct state.json manipulation
  grep -qE 'json\.dump|json\.load|state\.json.*["\x27]w["\x27]|update-state' "$skill_md" && has_state_write="YES"

  # Template/skeleton creation: Write() tool calls or file skeleton generation
  grep -qE 'Write\(|Wrote.*lines|skeleton\.sh|round1\.md|tasks\.md|plan\.md' "$skill_md" && has_template="YES"

  # Category assignment
  if [ "$has_ws_loop" = "YES" ] || [ "$has_state_write" = "YES" ]; then
    if [ "$has_template" = "YES" ]; then
      category="hybrid"
    elif [ "$has_ws_loop" = "YES" ] && [ "$has_state_write" = "no" ]; then
      category="state-machine"
    else
      category="hybrid"
    fi
    TARGET_COUNT=$((TARGET_COUNT + 1))
  else
    # Check for content-core signals
    if grep -qE 'one question at a time|dialogue|natural.*conversation|articulate' "$skill_md"; then
      category="content-core"
    else
      category="guidance"
    fi
    SKIP_COUNT=$((SKIP_COUNT + 1))
  fi

  printf "%-35s %-14s %-14s %-14s %-16s\n" "$skill_name" "$has_ws_loop" "$has_state_write" "$has_template" "$category"
done

echo ""
echo "Optimize targets: $TARGET_COUNT  |  Skip: $SKIP_COUNT"
