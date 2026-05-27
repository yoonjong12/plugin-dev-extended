---
name: optimize-skills
description: This skill should be used when the user says "optimize plugin tokens", "reduce token usage in skills", "scriptify skills", "extract boilerplate into scripts", "reduce LLM overhead in plugin", or wants to move repetitive state management / path resolution out of SKILL.md into shell scripts.
version: 0.1.0
---

# Optimize Skills

Extract repetitive boilerplate from SKILL.md files into scripts. After optimization, the LLM handles content generation only — scripts handle state transitions, file I/O, and path resolution.

## Step 1: Locate and run analysis

```bash
SCRIPT=$(find ~/.claude/plugins/cache -name "analyze-skills.sh" -path "*/plugin-dev-extended*" 2>/dev/null | head -1)
bash "$SCRIPT" "<target-plugin-dir>"
```

Outputs a triage table: each skill labeled as `hybrid`, `state-machine`, `content-core`, or `guidance`.

## Step 2: Filter with user

Present the triage table. Confirm target list before proceeding.

| Category | Optimize? |
|----------|-----------|
| `state-machine` | YES — routing / dispatch logic, all scriptable |
| `hybrid` | YES — scripts handle boilerplate, LLM handles content |
| `content-core` | NO — text generation is the primary job |
| `guidance` | NO — methodology docs, no mechanical parts |

See the triage criteria reference in this skill's directory for the full decision tree.

## Step 3: Extract scripts

For each target skill, extract the patterns found by the analyzer.

Common extractions:

| Pattern | Extract to |
|---------|-----------|
| Workspace detection `while` loop | `scripts/find-workspace.sh` |
| `json.load` / `json.dump` on state file | `scripts/update-state.sh <key> <value>` |
| STATUS line update in tracking file | `scripts/update-task-status.sh <id> <status>` |
| Skeleton file creation (structural only) | `scripts/<skill>-skeleton.sh` |

## Step 4: Rewrite SKILL.md

Replace each extracted block with a single script invocation. The rewritten body instructs the LLM to:

1. Run the script via Bash tool
2. Use output as focused context
3. Generate content-only output (no boilerplate)

Target SKILL.md length after optimization: ≤ 50% of original.

## Step 5: Verify

Re-run the analyzer — target skills must show no remaining scriptable patterns.
Then run `plugin-dev-extended:publish` to ship the optimized plugin.
