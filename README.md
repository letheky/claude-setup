# Claude Code Setup

Sync Claude Code skills & MCP servers across machines with one command.

## Quick Start

### New machine
```bash
git clone https://github.com/YOUR_USERNAME/claude-setup.git
cd claude-setup
bash install.sh --api-key YOUR_MAGIC_API_KEY
```

### Update existing machine
```bash
cd claude-setup
bash update.sh
```

---

## What's included

| Skill | Description |
|---|---|
| **ui-ux-pro-max** | UI/UX design intelligence: 67 styles, 161 palettes, font pairings |
| **gsap-skills** | GSAP animations: ScrollTrigger, plugins, React, timeline |
| **cybersecurity-skills** | 754 cybersecurity skills across 26 security domains |
| **vercel-agent-skills** | React best practices, web design, composition patterns, view transitions |
| **mattpocock-skills** | TDD, improve architecture, diagnose issues, prototype |
| **shadcn-ui** | shadcn/ui components, theming, CLI, customization, MCP integration |
| **anthropics-skills** | Anthropic official skills: webapp testing |
| **remotion-skills** | Video rendering, animations, React-based video production |

### MCP Servers
| Server | Description |
|---|---|
| **magic** | 21st.dev component builder — needs `API_KEY` |

---

## Add a new skill

1. Add entry to `config/skills-registry.json`:
```json
{
  "id": "my-new-skill",
  "repo": "owner/repo-name",
  "description": "What this skill does"
}
```

2. Commit & push:
```bash
git add config/skills-registry.json
git commit -m "add: my-new-skill"
git push
```

3. On any machine, run:
```bash
bash update.sh
```

---

## How it works

- `config/skills-registry.json` — source of truth for all skills & MCP servers
- `install.sh` — fresh install: clones all skill repos, registers marketplaces, adds MCP servers
- `update.sh` — pulls latest from all skill repos + installs any new skills from registry
- Skill files are **not stored** in this repo (just references) — they're cloned from their original repos
