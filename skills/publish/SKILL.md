---
name: publish
description: Unify plugin version across GitHub, marketplace mirror, runtime cache, and installed_plugins.json in one shot. Use when the user asks to "publish a plugin", "release a plugin", "bump plugin version", "ship a plugin update", "patch/minor/major bump", "/publish", or mentions plugin version mismatch between marketplace mirror, cache, or installed_plugins.json. Skips manual checklists — the bundled script does plugin.json bump → git commit/push → cache rsync → installed_plugins.json update → 3-layer verification.
---

# /publish — Unified Plugin Publishing

Automate the full release path for a Claude Code plugin in a same-repo marketplace (`source: "./"`). One script touches all 3 layers so they stay in sync — the #1 cause of "update not detected" bugs.

## When to invoke

Trigger when the user wants to release a new version of a plugin they have edited under `~/.claude/plugins/marketplaces/<marketplace>/`. Example phrasings: "publish this plugin", "release v0.2.0", "bump patch and push", "ship the update", "/publish minor".

Do NOT invoke for:
- Plugin scaffolding / authoring → use `plugin-dev-extended:plugin-structure`.
- Marketplace concept questions / troubleshooting → answer with the explanation in this file; do not run the script.
- Plugins where the marketplace clone is not under `~/.claude/plugins/marketplaces/`.

## Contract

The marketplace clone at `~/.claude/plugins/marketplaces/<marketplace>/` is the **single source of truth**. Edit files there, then run the script.

Layers kept in sync:

| Layer | Path |
|-------|------|
| GitHub remote | `origin` of the marketplace repo |
| Marketplace mirror | `~/.claude/plugins/marketplaces/<marketplace>/` |
| Runtime cache | `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` |
| Version registry | `~/.claude/plugins/installed_plugins.json` |

If any layer drifts, `/plugin update` reports "already at latest version" or loads the previous code from cache.

## How to run

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/publish/scripts/publish.sh [major|minor|patch] [plugin@marketplace]
```

Arguments:
- `major` / `minor` / `patch` — semver bump type. **Default: `patch`**.
- `plugin@marketplace` — explicit target. Auto-detected when cwd is under `~/.claude/plugins/marketplaces/<marketplace>/` (logical path, physical path, or symlink target all work).

Examples:
```
bash ${CLAUDE_PLUGIN_ROOT}/skills/publish/scripts/publish.sh
bash ${CLAUDE_PLUGIN_ROOT}/skills/publish/scripts/publish.sh minor
bash ${CLAUDE_PLUGIN_ROOT}/skills/publish/scripts/publish.sh patch atlas@atlas
```

## What the script does

1. Resolve target (cwd auto-detect or explicit `plugin@marketplace`); locate `.claude-plugin/plugin.json` (root or `./plugin/`).
2. Preflight: confirm git remote `origin` exists and current branch has an upstream.
3. Read current semver, compute new version per bump type.
4. Rewrite `plugin.json` `version` in place.
5. `git add -A` → `git commit -m "Release v<NEW>"` → `git push origin <branch>`.
6. Rsync `<repo>` → `~/.claude/plugins/cache/<mkt>/<plugin>/<NEW>/` (excluding `.git`).
7. Update `installed_plugins.json` entry: `installPath`, `version`, `lastUpdated`, `gitCommitSha`.
8. Verify all 3 layers report the new version; abort with mismatch error otherwise.

The script aborts (and never partially commits) if the working tree has nothing to bump or the upstream is missing.

## After running

Tell the user to run `/reload-plugins` inside Claude Code so the running session picks up the new cache version.

## Failure modes to surface

- `no plugin@marketplace given and cwd is not a known marketplace` — user is outside any marketplace clone. Ask them which `plugin@marketplace` to publish or to `cd` into the clone.
- `no upstream for <branch>` — the local branch is not tracking a remote. Suggest `git push -u origin <branch>` first.
- `nothing to commit` — the bump produced no diff (already at that version, or files unstaged elsewhere). Investigate before retrying.
- Sandbox blocks writes to `~/.claude/plugins/cache/` — re-run with the sandbox disabled for that single command. The git commit and push portions complete before this step, so do not re-bump; only resume from the rsync + installed_plugins.json update.

## Plugin contract assumptions

- Same-repo marketplace: `marketplace.json` and `plugin.json` share the repo (`source: "./"` or `"./plugin"`).
- Version is declared in `plugin.json` only — never duplicated in `marketplace.json`. If both exist, `plugin.json` wins silently and the marketplace value is ignored.
- The cache directory is keyed by version string; bumping is mandatory or no user (including the author) sees the update.
