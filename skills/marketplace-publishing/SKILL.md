---
name: marketplace-publishing
description: Guide for Claude Code plugin marketplace publishing, versioning, and release workflow. Use when the user asks about publishing a plugin, creating a marketplace, registering on marketplace, versioning plugins, releasing updates, plugin cache, or how users get plugin updates. Also triggers on "marketplace.json", "plugin.json version", "plugin update", "plugin release", "/plugin marketplace add".
---

# Plugin Marketplace Publishing & Versioning Guide

Covers marketplace creation, publishing, versioning strategy, and the update lifecycle.

For plugin structure, skills, hooks, agents, and MCP — use `/plugin-dev-extended:plugin-structure` and related skills.

## Marketplace Setup

### Directory Structure

A marketplace is a Git repo containing `.claude-plugin/marketplace.json`:

```
my-marketplace/
  .claude-plugin/
    marketplace.json    # marketplace catalog
    plugin.json         # plugin manifest (if same-repo plugin)
  commands/             # plugin commands
  skills/               # plugin skills
  agents/               # plugin agents
  hooks/                # plugin hooks
```

For single-plugin repos (plugin = marketplace), everything lives in one repo.

### marketplace.json

```json
{
  "name": "my-marketplace",
  "owner": { "name": "author-name" },
  "plugins": [
    {
      "name": "my-plugin",
      "source": "./",
      "description": "What it does"
    }
  ]
}
```

**Reserved names**: `claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`

### Plugin Sources

| Type | source value | When to use |
|------|-------------|-------------|
| Same repo | `"./"` | Single-plugin marketplace |
| Subdirectory | `"./plugins/foo"` | Multi-plugin monorepo |
| GitHub repo | `{ "source": "github", "repo": "owner/repo", "ref": "v1.0" }` | External repo |
| Git URL | `{ "source": "url", "url": "https://...", "ref": "main" }` | Non-GitHub git |
| npm | `{ "source": "npm", "package": "@scope/pkg" }` | npm package |
| pip | `{ "source": "pip", "package": "pkg" }` | pip package |

## Versioning Rules

### The Single Source of Truth Rule

Set version in ONE place only. Never both.

| Structure | Where to set version | Why |
|-----------|---------------------|-----|
| Same-repo (`source: "./"`) | `plugin.json` only | marketplace.json and plugin.json are in same repo; plugin.json takes priority anyway |
| External repo | `marketplace.json` only | marketplace controls which version to advertise |

If both declare version, `plugin.json` wins silently — the marketplace version gets ignored, causing confusion.

### How the Cache Works

```
~/.claude/plugins/
  marketplaces/{marketplace-name}/    # shallow git clone of marketplace repo
  cache/{marketplace-name}/{plugin-name}/{version}/  # installed snapshot
```

1. `/plugin update` fetches the marketplace repo
2. Compares cached version vs remote `plugin.json` version
3. If different, copies new version to `cache/{name}/{new-version}/`

**Critical**: If you change code without bumping version, users never see the update. The cache directory is keyed by version string.

### Semantic Versioning

```
MAJOR.MINOR.PATCH

MAJOR  — breaking changes (config format change, removed commands)
MINOR  — new features, backward-compatible
PATCH  — bug fixes
```

## Publishing Workflow

### Step 1: Develop locally

```bash
claude --plugin-dir ./my-plugin    # test with local plugin
/reload-plugins                     # reload after changes
```

### Step 2: Push to GitHub

```bash
git init && git add -A
git commit -m "Initial plugin"
git remote add origin git@github.com:user/my-plugin.git
git push -u origin main
```

### Step 3: Users install

```bash
/plugin marketplace add user/my-plugin
/plugin install my-plugin@my-marketplace
```

## Release Workflow

When releasing a new version:

1. Make your code changes
2. Bump version in `plugin.json` (the single source of truth)
3. Commit and push
4. Optionally tag: `git tag v0.3.0 && git push --tags`

Users update via:
- `/plugin update my-plugin` (manual)
- Auto-update on startup (if enabled for marketplace)

### Auto-Update

- Official Anthropic marketplaces: auto-update ON by default
- Third-party marketplaces: auto-update OFF by default
- Users toggle via: `/plugin` > Marketplaces tab > Enable auto-update

### Release Channels (Advanced)

Use separate marketplace configs pointing to different branches:

- `stable` branch with marketplace pointing to tagged releases
- `latest` branch with marketplace pointing to main HEAD

Each branch's `plugin.json` must have a different version.

## Troubleshooting

### "Already at latest version" but code changed

**Cause**: You changed code without bumping `plugin.json` version.
**Fix**: Bump version, commit, push.

### Update not detected after version bump

**Cause**: Version set in both `marketplace.json` and `plugin.json`, or shallow clone not pulling.
**Fix**: Remove version from `marketplace.json`, keep only in `plugin.json`. User may need to `/plugin marketplace add` again to refresh.

### Plugin commands not appearing after install

**Cause**: Commands directory not at plugin root, or plugin.json missing/invalid.
**Fix**: Verify structure: `.claude-plugin/plugin.json` exists, `commands/` is at root level (not inside `.claude-plugin/`).

## Quick Reference

```
# Development
claude --plugin-dir ./my-plugin
/reload-plugins

# Testing install flow
/plugin marketplace add ./my-marketplace
/plugin install my-plugin@my-marketplace

# Publishing
git push origin main

# Releasing
# 1. bump .claude-plugin/plugin.json version
# 2. git commit && git push
# 3. optionally: git tag v0.3.0 && git push --tags

# User updates
/plugin update my-plugin
```
