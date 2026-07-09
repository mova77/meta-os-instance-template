# {{instance-name}} — Agentic OS instance

<!-- TODO: replace {{instance-name}} everywhere (including the vault title in _index.md)
     and fill in the "Instance facts" section below with your real estate. -->

This vault is **the OS instance for this machine/estate**: the private layer holding
project registry, memory, and live automations. The generic framework (skills, systems,
templates, agents) is the separate **[[meta-os]]** repo, mounted in as the `.meta-os`
git submodule (dot-folder, so Obsidian doesn't index framework notes twice):

```
{{instance-name}}/              ← PRIVATE instance (this repo) — open THIS as the vault
├── CLAUDE.md  _index.md        ← instance contract + home
├── projects/                   ← estate registry (repos, trackers, paths)
├── memory/                     ← raw → wiki → output — the knowledge, accrues here
├── automations/                ← live routine rows
├── vaults/                     ← symlinks to federated project vaults
├── .meta-os/                   ← the framework (git submodule, pinned version)
├── .packs/                     ← mounted skill packs (pinned submodules; see
│                                 the framework's systems/packs.md)
├── skills/                     ← UNION mount: framework + pack skills, as per-skill
│                                 symlinks — rebuilt by scripts/packs.sh sync
├── systems/   → .meta-os/systems     ┐
├── templates/ → .meta-os/templates   │ framework mounts — one Obsidian graph,
└── agents/    → .meta-os/agents      ┘ wikilinks resolve in both repos
```

Framework developers can point the mounts at a sibling `../meta-os` checkout instead:
`scripts/framework-mode.sh sibling` (and back with `submodule`) — see the framework's
[[systems/distribution]] for both modes.

**Framework rules apply here** — read the framework's `CLAUDE.md` (at `.meta-os/`, or
the sibling checkout in sibling mode); mounted docs describe the generic *how*, this
file holds only what is instance-specific.

## Instance facts

<!-- Fill these in as your estate grows. Delete this comment once populated. -->

- **Estate:** (list your projects — one node each in [[projects/_index|projects/]])
- **Authority order (process/backlog):** (e.g. Jira → a `backlog.json` mirror →
  [[skills/agile-process/SKILL|agile-process]] → framework invariants. Higher source
  wins. Skip this line if you don't run the agile-process skill.)
- **Skill discovery:** `~/.claude/skills/<name> → meta-os/skills/<name>` (machine-global).
  Skills are edited in `meta-os` — never create a second real copy.
- **Privacy boundary is structural:** anything instance-specific (repo names, trackers,
  paths, business context, promoted knowledge) belongs HERE, never in `meta-os`. The
  framework must stay public-safe by construction.

## Rules

- Memory promotion, `_index.md` discipline, naming, and linking conventions: as per the
  framework ([[systems/memory-layer]], `meta-os/CLAUDE.md`).
- Projects are nodes, not clones. Federated vault notes are edited in *their* conventions.
- This repo should stay **private**. Never make it public; never move private notes into
  `meta-os`.
