#!/usr/bin/env bash
# /publish — unify GitHub + marketplace mirror + cache + installed_plugins.json.
#
# Usage:
#   publish.sh [major|minor|patch] [plugin@marketplace]
#
# Defaults:
#   bump = patch
#   plugin@marketplace auto-detected from cwd if under ~/.claude/plugins/marketplaces/<mkt>/...
#
# Contract:
#   - The marketplace clone at ~/.claude/plugins/marketplaces/<mkt>/ is treated as
#     the single source of truth. Edit there, then /publish.
#   - Works for same-repo marketplaces (source: "./") where marketplace.json and
#     plugin.json live in the same repo.

set -euo pipefail

ROOT="$HOME/.claude/plugins"
MARKETPLACES_DIR="$ROOT/marketplaces"
CACHE_DIR="$ROOT/cache"
INSTALLED_JSON="$ROOT/installed_plugins.json"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "[publish] $*"; }

# --- Args ---
BUMP="patch"
TARGET=""
for arg in "$@"; do
  case "$arg" in
    major|minor|patch) BUMP="$arg" ;;
    *@*) TARGET="$arg" ;;
    *) die "unknown arg: $arg (expected major|minor|patch or plugin@marketplace)" ;;
  esac
done

# --- Resolve target ---
if [[ -z "$TARGET" ]]; then
  phys=$(pwd -P)
  logi=$PWD
  MKT=""
  # 1) cwd already inside marketplaces dir (logical or physical)
  for c in "$logi" "$phys"; do
    case "$c" in
      "$MARKETPLACES_DIR"/*)
        MKT=$(echo "$c" | sed -E "s#^$MARKETPLACES_DIR/([^/]+).*#\1#")
        break ;;
    esac
  done
  # 2) cwd is the target of a symlinked marketplace (reverse lookup)
  if [[ -z "$MKT" ]]; then
    for m in "$MARKETPLACES_DIR"/*; do
      [[ -L "$m" ]] || continue
      target=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$m")
      if [[ "$phys" == "$target" || "$phys" == "$target"/* ]]; then
        MKT=$(basename "$m")
        break
      fi
    done
  fi
  [[ -n "$MKT" ]] || die "no plugin@marketplace given and cwd is not a known marketplace (checked logical, physical, and symlink targets under $MARKETPLACES_DIR)"
  REPO_PATH="$MARKETPLACES_DIR/$MKT"
  # plugin.json can be at root (./) or subdir (./plugin/)
  if [[ -f "$REPO_PATH/.claude-plugin/plugin.json" ]]; then
    PJ_DIR="$REPO_PATH"
  elif [[ -f "$REPO_PATH/plugin/.claude-plugin/plugin.json" ]]; then
    PJ_DIR="$REPO_PATH/plugin"
  else
    die "no plugin.json found under $REPO_PATH (checked . and ./plugin)"
  fi
  PLUGIN=$(python3 -c "import json; print(json.load(open('$PJ_DIR/.claude-plugin/plugin.json'))['name'])")
else
  PLUGIN="${TARGET%@*}"
  MKT="${TARGET#*@}"
  REPO_PATH="$MARKETPLACES_DIR/$MKT"
  if [[ -f "$REPO_PATH/.claude-plugin/plugin.json" ]]; then
    PJ_DIR="$REPO_PATH"
  elif [[ -f "$REPO_PATH/plugin/.claude-plugin/plugin.json" ]]; then
    PJ_DIR="$REPO_PATH/plugin"
  else
    die "no plugin.json found under $REPO_PATH"
  fi
fi

[[ -d "$REPO_PATH/.git" ]] || die "not a git repo: $REPO_PATH"
[[ -f "$PJ_DIR/.claude-plugin/plugin.json" ]] || die "missing plugin.json at $PJ_DIR"

info "plugin=$PLUGIN marketplace=$MKT repo=$REPO_PATH bump=$BUMP"

# --- Compute new version ---
CUR_VERSION=$(python3 -c "import json; print(json.load(open('$PJ_DIR/.claude-plugin/plugin.json'))['version'])")
NEW_VERSION=$(python3 -c "
import sys
cur='$CUR_VERSION'; bump='$BUMP'
parts=[int(x) for x in cur.split('.')]
if len(parts)!=3: sys.exit('invalid semver: '+cur)
maj,mnr,pat=parts
if bump=='major': maj+=1; mnr=0; pat=0
elif bump=='minor': mnr+=1; pat=0
else: pat+=1
print(f'{maj}.{mnr}.{pat}')
")
info "version: $CUR_VERSION → $NEW_VERSION"

# --- Git preflight ---
cd "$REPO_PATH"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git remote get-url origin >/dev/null || die "no remote 'origin'"
if ! git rev-parse --verify --quiet "@{u}" >/dev/null 2>&1; then
  die "no upstream for $BRANCH — set with: git push -u origin $BRANCH"
fi

# --- Bump plugin.json ---
python3 -c "
import json, pathlib
p=pathlib.Path('$PJ_DIR/.claude-plugin/plugin.json')
d=json.loads(p.read_text())
d['version']='$NEW_VERSION'
p.write_text(json.dumps(d, indent=2)+'\n')
"

# --- Commit + push ---
git add -A
if git diff --cached --quiet; then
  die "nothing to commit — all working changes already committed. Bump aborted (plugin.json bump got no-op? check state)"
fi
git commit -m "Release v$NEW_VERSION"
git push origin "$BRANCH"
COMMIT_SHA=$(git rev-parse --short=12 HEAD)
info "pushed $COMMIT_SHA to origin/$BRANCH"

# --- Sync cache ---
NEW_CACHE="$CACHE_DIR/$MKT/$PLUGIN/$NEW_VERSION"
if [[ -d "$NEW_CACHE" ]]; then
  info "cache dir already exists, overwriting: $NEW_CACHE"
  rm -rf "$NEW_CACHE"
fi
mkdir -p "$NEW_CACHE"
# rsync: exclude .git; preserve structure
rsync -a --delete --exclude='.git' "$PJ_DIR/" "$NEW_CACHE/"
info "cache synced: $NEW_CACHE"

# --- Update installed_plugins.json ---
python3 -c "
import json, pathlib, datetime
p=pathlib.Path('$INSTALLED_JSON')
d=json.loads(p.read_text())
key='$PLUGIN@$MKT'
entries=d.setdefault('plugins',{}).get(key, [])
if not entries:
    # fresh install entry
    entries=[{'scope':'user','installedAt':datetime.datetime.utcnow().isoformat()+'Z'}]
    d['plugins'][key]=entries
e=entries[0]
e['installPath']='$NEW_CACHE'
e['version']='$NEW_VERSION'
e['lastUpdated']=datetime.datetime.utcnow().isoformat()+'Z'
e['gitCommitSha']='$COMMIT_SHA'
p.write_text(json.dumps(d, indent=2))
print(f'installed_plugins.json updated: {key} → {e[\"version\"]}')
"

# --- Verify ---
V_REPO=$(python3 -c "import json; print(json.load(open('$PJ_DIR/.claude-plugin/plugin.json'))['version'])")
# plugin.json relative path same as in source
REL_PJ=${PJ_DIR#$REPO_PATH/}
[[ "$REL_PJ" == "$PJ_DIR" ]] && REL_PJ="."
V_CACHE=$(python3 -c "import json,os; base='$NEW_CACHE'; rel='$REL_PJ'; p=os.path.join(base, '' if rel=='.' else rel, '.claude-plugin/plugin.json'); print(json.load(open(p))['version'])")
V_INST=$(python3 -c "import json; print(json.load(open('$INSTALLED_JSON'))['plugins']['$PLUGIN@$MKT'][0]['version'])")

echo
echo "  Layer                     Version"
echo "  ─────────────────────────────────"
echo "  marketplace mirror        $V_REPO"
echo "  cache                     $V_CACHE"
echo "  installed_plugins.json    $V_INST"
echo

if [[ "$V_REPO" == "$V_CACHE" && "$V_CACHE" == "$V_INST" && "$V_REPO" == "$NEW_VERSION" ]]; then
  info "all 3 layers aligned at $NEW_VERSION"
  echo
  echo "Next: /reload-plugins  (inside Claude Code, to reload running plugin)"
else
  die "version mismatch after publish"
fi
