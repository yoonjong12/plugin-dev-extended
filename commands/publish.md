---
description: Unify plugin version across GitHub + marketplace mirror + cache + installed_plugins.json
argument-hint: "[major|minor|patch] [plugin@marketplace]"
allowed-tools: Bash
---

# /publish — Unified Plugin Publishing

One command to publish a plugin update across all 3 layers:

- GitHub remote (origin)
- `~/.claude/plugins/marketplaces/<mkt>/` (local mirror)
- `~/.claude/plugins/cache/<mkt>/<plugin>/<version>/` (runtime snapshot)
- `~/.claude/plugins/installed_plugins.json` (version registry)

## Contract

The marketplace clone at `~/.claude/plugins/marketplaces/<mkt>/` is the **single source of truth**. Edit files there, then run `/publish`.

This works for same-repo marketplaces (`source: "./"`) — the standard layout where marketplace.json and plugin.json share a repo.

## Arguments

- `major` / `minor` / `patch` — semver bump type. Default: `patch`.
- `plugin@marketplace` — target plugin. Auto-detected if cwd is under `~/.claude/plugins/marketplaces/<mkt>/`.

## Examples

```
/publish                       # patch bump, cwd-detected target
/publish minor                 # minor bump, cwd-detected target
/publish patch atlas@atlas     # explicit target
```

## Execution

!bash ${CLAUDE_PLUGIN_ROOT}/scripts/publish.sh $ARGUMENTS

## After

Run `/reload-plugins` inside Claude Code to load the new version.
