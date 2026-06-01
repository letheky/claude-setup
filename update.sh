#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
#  Claude Code Setup — Update / Sync
#  Usage: bash update.sh
#  - Pulls latest from all installed skill repos
#  - Installs any new skills added to the registry
# ══════════════════════════════════════════════════════════════
set -e

REGISTRY="$(cd "$(dirname "$0")" && pwd)/config/skills-registry.json"
PLUGINS_DIR="$HOME/.claude/plugins"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${BOLD}▶ $1${NC}"; }

echo ""
echo -e "${BOLD}══════════════════════════════════════${NC}"
echo -e "${BOLD}  Claude Code Setup — Update          ${NC}"
echo -e "${BOLD}══════════════════════════════════════${NC}"
echo ""

# ── Pull self (this repo) first ──────────────────────────────
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$SELF_DIR/.git" ]; then
  info "Pulling latest claude-setup registry..."
  git -C "$SELF_DIR" pull --rebase 2>&1 | sed 's/^/  /'
  ok "Registry up to date"
  echo ""
fi

# ── Read skills from registry ────────────────────────────────
SKILLS=$(python3 -c "import json; d=json.load(open('$REGISTRY')); [print(s['id']+'|'+s['repo']+'|'+s['description']) for s in d['skills']]")

UPDATED=0
NEW=0
FAILED=0

info "Syncing skills..."
echo ""

while IFS='|' read -r id repo desc; do
  TARGET="$PLUGINS_DIR/$id"

  if [ -d "$TARGET/.git" ]; then
    # Already installed — pull latest
    echo -e "  ${CYAN}↻ Updating${NC} $id..."
    RESULT=$(git -C "$TARGET" pull --rebase 2>&1)
    if echo "$RESULT" | grep -q "Already up to date"; then
      echo -e "    ${YELLOW}Already up to date${NC}"
    else
      echo "$RESULT" | sed 's/^/    /'
      ok "$id updated"
      ((UPDATED++))
    fi
  else
    # New skill added to registry — install it
    echo -e "  ${GREEN}+ New skill:${NC} $id"
    echo -e "    from: https://github.com/$repo"
    git clone --depth=1 "https://github.com/$repo.git" "$TARGET" 2>&1 | sed 's/^/    /'
    ok "$id installed"
    ((NEW++))

    # Register in marketplaces
    python3 - <<PYEOF
import json, datetime

mf = "$PLUGINS_DIR/known_marketplaces.json"
try:
    with open(mf) as f:
        mp = json.load(f)
except:
    mp = {}

if "$id" not in mp:
    mp["$id"] = {
        "source": {"source": "github", "repo": "$repo"},
        "installLocation": "$TARGET",
        "lastUpdated": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")
    }
    with open(mf, "w") as f:
        json.dump(mp, f, indent=2)
    print("    Registered in marketplaces")
PYEOF
  fi

  echo ""
done <<< "$SKILLS"

# ── Summary ──────────────────────────────────────────────────
echo -e "${BOLD}══════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ Update complete!${NC}"
echo -e "${BOLD}══════════════════════════════════════${NC}"
echo -e "  Skills updated   : ${GREEN}$UPDATED${NC}"
echo -e "  New skills added : ${GREEN}$NEW${NC}"
echo ""
if [ "$UPDATED" -gt 0 ] || [ "$NEW" -gt 0 ]; then
  echo -e "  ${BOLD}→ Restart Claude Code to activate changes${NC}"
fi
echo ""
