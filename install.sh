#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
#  Claude Code Setup — Fresh Install
#  Usage: bash install.sh [--api-key YOUR_MAGIC_KEY]
# ══════════════════════════════════════════════════════════════
set -e

REGISTRY="$(cd "$(dirname "$0")" && pwd)/config/skills-registry.json"
PLUGINS_DIR="$HOME/.claude/plugins"
CLAUDE_JSON="$HOME/.claude.json"
CLAUDE_BIN="$(find "$HOME/.config/Claude" -name "claude" -type f 2>/dev/null | head -1)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${BOLD}▶ $1${NC}"; }

# ── Parse args ──────────────────────────────────────────────
MAGIC_API_KEY=""
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --api-key) MAGIC_API_KEY="$2"; shift ;;
  esac
  shift
done

echo ""
echo -e "${BOLD}══════════════════════════════════════${NC}"
echo -e "${BOLD}  Claude Code Setup — Install         ${NC}"
echo -e "${BOLD}══════════════════════════════════════${NC}"
echo ""

# ── Check dependencies ──────────────────────────────────────
info "Checking dependencies..."
command -v git  >/dev/null || { echo "❌ git not found"; exit 1; }
command -v python3 >/dev/null || { echo "❌ python3 not found"; exit 1; }
ok "Dependencies OK"

# ── Create plugin dir ────────────────────────────────────────
mkdir -p "$PLUGINS_DIR"

# ── Read registry & install skills ──────────────────────────
info "Installing skills from registry..."
echo ""

SKILLS=$(python3 -c "import json; d=json.load(open('$REGISTRY')); [print(s['id']+'|'+s['repo']+'|'+s['description']) for s in d['skills']]")

INSTALLED=0
SKIPPED=0

while IFS='|' read -r id repo desc; do
  TARGET="$PLUGINS_DIR/$id"
  if [ -d "$TARGET/.git" ]; then
    warn "Already installed: $id — skipping (run update.sh to refresh)"
    ((SKIPPED++))
  else
    echo -e "  ${BOLD}→ Installing${NC} $id"
    echo -e "    from: https://github.com/$repo"
    git clone --depth=1 "https://github.com/$repo.git" "$TARGET" 2>&1 | sed 's/^/    /'
    ok "$id installed"
    ((INSTALLED++))
  fi
done <<< "$SKILLS"

# ── Update known_marketplaces.json ──────────────────────────
info "Registering marketplaces..."
MARKETPLACES_FILE="$PLUGINS_DIR/known_marketplaces.json"

python3 - <<EOF
import json, os, datetime

registry_path = "$REGISTRY"
marketplaces_path = "$MARKETPLACES_FILE"
plugins_dir = "$PLUGINS_DIR"

with open(registry_path) as f:
    registry = json.load(f)

# Load existing or start fresh (keep official)
if os.path.exists(marketplaces_path):
    with open(marketplaces_path) as f:
        marketplaces = json.load(f)
else:
    marketplaces = {}

now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")

for skill in registry["skills"]:
    sid = skill["id"]
    if sid not in marketplaces:
        marketplaces[sid] = {
            "source": {"source": "github", "repo": skill["repo"]},
            "installLocation": f"{plugins_dir}/{sid}",
            "lastUpdated": now
        }
        print(f"  Registered: {sid}")
    else:
        print(f"  Already registered: {sid}")

with open(marketplaces_path, "w") as f:
    json.dump(marketplaces, f, indent=2)

print("  ✅ known_marketplaces.json updated")
EOF

# ── Install MCP servers ──────────────────────────────────────
if [ -n "$CLAUDE_BIN" ]; then
  info "Installing MCP servers..."

  MCP_ENTRIES=$(python3 -c "
import json
d = json.load(open('$REGISTRY'))
for s in d.get('mcp_servers', []):
    args = ' '.join(s['args'])
    print(f\"{s['name']}|{s['command']}|{args}\")
")

  while IFS='|' read -r name cmd args; do
    # Check if already registered
    EXISTING=$(python3 -c "
import json
try:
    d = json.load(open('$CLAUDE_JSON'))
    servers = d.get('mcpServers', {})
    print('yes' if '$name' in servers else 'no')
except: print('no')
" 2>/dev/null)

    if [ "$EXISTING" = "yes" ]; then
      warn "MCP '$name' already registered — skipping"
      continue
    fi

    if [ "$name" = "magic" ] && [ -n "$MAGIC_API_KEY" ]; then
      "$CLAUDE_BIN" mcp add "$name" --scope user --env "API_KEY=$MAGIC_API_KEY" -- $cmd $args 2>&1
      ok "MCP '$name' installed"
    elif [ "$name" = "magic" ]; then
      warn "MCP 'magic' skipped — pass --api-key YOUR_KEY to install"
      warn "Or run: $CLAUDE_BIN mcp add magic --scope user --env API_KEY=YOUR_KEY -- $cmd $args"
    else
      "$CLAUDE_BIN" mcp add "$name" --scope user -- $cmd $args 2>&1
      ok "MCP '$name' installed"
    fi
  done <<< "$MCP_ENTRIES"
else
  warn "Claude binary not found — skip MCP install (run manually)"
fi

# ── Summary ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ Setup complete!${NC}"
echo -e "${BOLD}══════════════════════════════════════${NC}"
echo -e "  Skills installed : ${GREEN}$INSTALLED${NC}"
echo -e "  Skills skipped   : ${YELLOW}$SKIPPED${NC} (already exist)"
echo ""
echo -e "  ${BOLD}→ Restart Claude Code to activate all skills${NC}"
echo ""
