# meta-os instance template

A ready-to-use skeleton for bootstrapping your own private **Agentic OS instance** on top
of the public [meta-os](https://github.com/mova77/meta-os) framework. This is the
*instance* side of the framework/instance split: your project registry, memory, and
automations — the framework arrives as the `.meta-os` git submodule, mounted by
per-folder symlinks. **One clone and you're running.**

## Use this template

1. Click **Use this template → Create a new repository** above (or `gh repo create
   <you>/<instance-name> --template mova77/meta-os-instance-template --private`).
   **Keep the new repo private** — this is where your real, non-public data will live.
2. Clone it — one command, nothing else to arrange:
   ```bash
   git clone --recursive git@github.com:<you>/<instance-name>.git
   ```
   The framework lands in `.meta-os/` at a pinned, known-good version, and the mounts
   (`skills/`, `systems/`, `templates/`, `agents/`) already point at it. (Cloned
   without `--recursive`? Run `git submodule update --init`.)
3. Rename `{{instance-name}}` in `CLAUDE.md` and `_index.md` to your actual instance name,
   and fill in the "Instance facts" section of `CLAUDE.md` (your estate, authority order
   if you use the agile-process skill).
4. Open the instance repo as your Obsidian vault — wikilinks resolve across both repos
   because they're vault-root-relative (`.meta-os/` itself stays out of the graph:
   Obsidian ignores dot-folders, so framework notes aren't indexed twice).
5. *(Optional)* Project-local discovery is already wired — `.claude/skills/` mirrors the
   union, so Claude Code sessions inside this repo see everything with zero setup. For
   **machine-global** discovery too (skills usable from any directory):
   ```bash
   for s in "$(pwd)"/skills/*/; do
     ln -s "$s" ~/.claude/skills/"$(basename "$s")"
   done
   ```
6. In Claude Code, run the `bootstrap-instance` skill
   (`skills/bootstrap-instance/SKILL.md`) — a one-time onboarding conversation
   that asks you to choose a backlog/tracking model (none / local JSON / Jira-integrated),
   registers your first project, and optionally wires up its GitHub repo. Or do it by
   hand: copy `templates/project.md` into `projects/<name>.md`, fill it in, add a row to
   `projects/_index.md`.

## Updating the framework

The submodule pins an exact framework version — updates are a deliberate, reviewable
bump that **cannot touch your folders**:

```bash
git submodule update --remote .meta-os   # fetch the latest framework main
git add .meta-os && git commit -m "chore: bump framework"
```

## Skill packs

The framework core ships only generic OS skills; domain skill sets (agile process,
third-party collections) mount as **packs** — pinned submodules under `.packs/`, unioned
into `skills/` alongside the framework's own:

```bash
scripts/packs.sh add superpowers        # from the curated registry (systems/packs.yaml)
scripts/packs.sh add mypack <repo-url>  # any repo with SKILL.md folders (flat, nested, or plugin.json)
scripts/packs.sh list | update | remove <name>
scripts/packs.sh apply                  # reconcile mounts to .packs.yaml (headless-safe)
scripts/packs.sh config <pack> [key]    # resolve a pack's parameters + validate
```

`skills/` is a union of per-skill symlinks (framework wins on name collisions; your own
real folders in `skills/` are never touched). Mounting also enriches the project-local
**`.claude/`** engine surface: `.claude/skills/` mirrors the union, pack `agents/` land
in `.claude/agents/`, and pack `hooks/` are **staged** under `.claude/hooks/<pack>/` —
never auto-wired into `settings.json`; enabling an executable hook is always your
explicit, per-hook decision. After bumping the framework or a pack, re-run
`scripts/packs.sh sync`.

**Declarative & headless.** `.packs.yaml` is the desired-state list of packs; `add`/
`remove` maintain it and `apply` reconciles to it (idempotent) — so a container or CI can
install packs with no conversation: write the manifest and run `apply`.

**Parameterised packs.** A pack that ships a `pack.yaml` carries the method; your choices
live under `packs.<name>.config` in `.packs.yaml`. The agile pack, for example, takes a
`profile` (`scrum` | `kanban`) plus `tracker`/`space`/`mirror-repo` — switching
methodology is one line, not a fork. `scripts/packs.sh config <pack>` prints the resolved
values. See the framework's [`systems/packs.md`](.meta-os/systems/packs.md) for the full
contract.

## Hacking the framework itself? (sibling mode)

Clone `meta-os` next to this repo and flip the mounts:

```bash
scripts/framework-mode.sh sibling     # mounts → ../meta-os/*
scripts/framework-mode.sh submodule   # back to the pinned .meta-os/*
```

## What's pre-wired

- `_index.md` / `CLAUDE.md` — instance contract + home MOC, ready to fill in
- `projects/`, `memory/{raw,wiki,output}/`, `automations/`, `vaults/` — the folder
  skeleton with `_index.md` tables of contents, per the framework's conventions
- `automations/_index.md` — a starter table of generic candidate automations (including
  the `meta-os-dashboard` heartbeat) — prune or extend to taste
- The framework as the `.meta-os` submodule, mounted via symlinks (`skills/`,
  `systems/`, `templates/`, `agents/`) — flip to a sibling checkout with
  `scripts/framework-mode.sh`

## Optional: the dashboard

[meta-os-dashboard](https://github.com/mova77/meta-os-dashboard) is a layer-3
observability app that reads this instance's markdown/JSON straight off disk — sprint
lanes, a live knowledge graph, the memory promotion pipeline, ontology linting, and more.
Point its `instance.config.json` at this repo's path once you have real data flowing.

## Learn the model

Read `.meta-os/CLAUDE.md` and `systems/_index.md` for the full operating model —
this template only gets you to a blank, correctly-wired vault; the framework repo
explains *how* to use it.
