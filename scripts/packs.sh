#!/usr/bin/env bash
# Skill packs — mount curated skill collections into this instance.
# Contract: framework systems/packs.md; registry: systems/packs.yaml (read through
# the mount). A pack is a pinned submodule at .packs/<name>; skills/ is the UNION
# of framework skills + pack skills, as per-skill relative symlinks.
#
# Rules encoded here:
#   - framework wins on name collision; earlier-mounted packs win over later ones
#   - real (non-symlink) entries in skills/ are the instance's own — never touched
#   - sync only manages symlinks; re-run after any framework or pack bump
set -euo pipefail

die() { echo "packs.sh: $*" >&2; exit 1; }
[ -f CLAUDE.md ] && [ -e agents ] || die "run from the instance root"

# Framework root, derived from a whole-folder mount (agents/ stays a symlink in
# both consumption modes; skills/ does not — it's the union dir we manage).
fw_root() { local t; t=$(readlink agents) || die "agents/ is not a symlink — mounts broken (scripts/framework-mode.sh)"; echo "${t%/agents}"; }

registry_field() { # <pack> <field> → value from systems/packs.yaml, empty if absent
  [ -f systems/packs.yaml ] || return 0
  awk -v p="$1" -v f="$2:" '
    $0 ~ "^  "p":$" { inpack=1; next }
    inpack && /^  [a-zA-Z0-9_-]+:/ { inpack=0 }
    inpack && $1 == f { $1=""; sub(/^ /,""); gsub(/"/,""); print; exit }
  ' systems/packs.yaml
}

# Directory holding a pack's skill folders: skills/ subdir if present, else repo root.
skills_src() { if [ -d "$1/skills" ]; then echo "$1/skills"; else echo "$1"; fi; }

# --- declarative manifest (.packs.yaml at the instance root) ------------------
# Desired-state list of packs; `apply` reconciles mounts to it. This is what makes
# headless installs possible (container/CI: write the manifest, run apply).
MANIFEST=.packs.yaml

manifest_names() {
  [ -f "$MANIFEST" ] || return 0
  awk '/^packs:/{inp=1;next} inp && /^  [a-zA-Z0-9_-]+:/{gsub(/[: ]/,"");print}' "$MANIFEST"
}
manifest_repo() { # <name> → repo override, if any
  [ -f "$MANIFEST" ] || return 0
  awk -v p="$1" '
    $0 ~ "^  "p":" { inpack=1; next }
    inpack && /^  [a-zA-Z0-9_-]+:/ { inpack=0 }
    inpack && $1 == "repo:" { print $2; exit }
  ' "$MANIFEST"
}
manifest_add() {
  [ -f "$MANIFEST" ] || printf '# Desired packs — reconciled by scripts/packs.sh apply\npacks:\n' > "$MANIFEST"
  grep -q "^  $1:" "$MANIFEST" && return 0
  # Registry packs carry no repo: line (URL lives in the registry). Guard the
  # optional line with an explicit if — a bare `[ -n "$2" ] && echo` returns
  # non-zero when $2 is empty and would trip `set -e`, aborting the caller.
  echo "  $1:" >> "$MANIFEST"
  if [ -n "${2:-}" ]; then echo "    repo: $2" >> "$MANIFEST"; fi
  return 0
}
manifest_remove() {
  [ -f "$MANIFEST" ] || return 0
  awk -v p="$1" '
    $0 ~ "^  "p":" { skip=1; next }
    skip && /^    / { next }
    { skip=0; print }
  ' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
}

cmd_sync() {
  local fw; fw=$(fw_root)
  [ -d "$fw/skills" ] || die "framework skills not found at $fw/skills (submodule not initialized?)"
  [ -L skills ] && rm skills   # legacy whole-folder symlink → becomes the union dir
  mkdir -p skills
  find skills -maxdepth 1 -type l -exec rm {} +
  # framework first — it wins collisions by getting there first
  local d name
  for d in "$fw"/skills/*/; do
    name=$(basename "$d")
    [ -e "skills/$name" ] || ln -s "../$fw/skills/$name" "skills/$name"
  done
  [ -e skills/_index.md ] || ln -s "../$fw/skills/_index.md" skills/_index.md
  # then packs, in mount-name order
  local p pname src
  for p in .packs/*/; do
    [ -d "$p" ] || continue
    pname=$(basename "$p"); src=$(skills_src ".packs/$pname")
    for d in "$src"/*/; do
      [ -f "${d}SKILL.md" ] || continue
      name=$(basename "$d")
      if [ -e "skills/$name" ]; then
        echo "warn: '$name' from pack '$pname' is shadowed by an existing skill — skipped" >&2
      else
        ln -s "../$src/$name" "skills/$name"
      fi
    done
  done
  echo "skills/ union rebuilt — $(find skills -maxdepth 1 -mindepth 1 | wc -l | tr -d ' ') entries"
  sync_claude
}

# Project-local .claude/ enrichment — the engine's discovery surface. Skills mirror
# the union; agents come from packs (framework agents/ is a docs roster, not engine
# definitions). Pack HOOKS are STAGED under .claude/hooks/<pack>/ but never wired
# into settings.json automatically — enabling third-party executable hooks is an
# explicit, per-hook user decision.
sync_claude() {
  mkdir -p .claude/skills .claude/agents .claude/hooks
  local d name p pname f b
  find .claude/skills -maxdepth 1 -type l -exec rm {} +
  for d in skills/*/; do
    name=$(basename "$d")
    [ -e ".claude/skills/$name" ] || ln -s "../../skills/$name" ".claude/skills/$name"
  done
  find .claude/agents -maxdepth 1 -type l -exec rm {} +
  find .claude/hooks -maxdepth 1 -type l -exec rm {} +
  for p in .packs/*/; do
    [ -d "$p" ] || continue
    pname=$(basename "$p")
    if [ -d "${p}agents" ]; then
      for f in "${p}agents"/*.md; do
        [ -f "$f" ] || continue
        b=$(basename "$f")
        if [ -e ".claude/agents/$b" ]; then
          echo "warn: agent '$b' from pack '$pname' collides — skipped" >&2
        else
          ln -s "../../.packs/$pname/agents/$b" ".claude/agents/$b"
        fi
      done
    fi
    if [ -d "${p}hooks" ]; then
      ln -sfn "../../.packs/$pname/hooks" ".claude/hooks/$pname"
      echo "hooks from '$pname' staged at .claude/hooks/$pname — review and wire explicitly in .claude/settings.json (never auto-enabled)"
    fi
  done
  echo ".claude/ enriched — $(find .claude/skills -maxdepth 1 -type l | wc -l | tr -d ' ') skills, $(find .claude/agents -maxdepth 1 -type l | wc -l | tr -d ' ') agents"
}

cmd_add() {
  local name="${1:?usage: packs.sh add <name> [repo-url]}" url="${2:-}"
  [ -e ".packs/$name" ] && die "pack '$name' is already mounted"
  if [ -z "$url" ]; then
    url=$(registry_field "$name" repo)
    [ -n "$url" ] || die "'$name' is not in the registry (systems/packs.yaml) — pass a repo url"
    local status prov lic
    status=$(registry_field "$name" status); prov=$(registry_field "$name" provenance); lic=$(registry_field "$name" license)
    [ "$status" = "planned" ] && die "'$name' is registered but not published yet (status: planned)"
    echo "registry: $name — provenance: ${prov:-?} · license: ${lic:-?}"
    [ "$lic" = "verify-at-add" ] && echo "note: check the upstream LICENSE before relying on this pack" >&2
  else
    echo "warn: '$name' is not from the curated registry — provenance unverified" >&2
  fi
  git submodule add -f "$url" ".packs/$name"
  manifest_add "$name" "${2:-}"
  cmd_sync
  echo "mounted. Review, then: git add .gitmodules .packs.yaml .packs/$name skills .claude && git commit"
}

cmd_remove() {
  local name="${1:?usage: packs.sh remove <name>}"
  [ -d ".packs/$name" ] || die "pack '$name' is not mounted"
  git submodule deinit -f ".packs/$name"
  git rm -f ".packs/$name"
  rm -rf ".git/modules/.packs/$name"
  manifest_remove "$name"
  cmd_sync
}

# Reconcile mounted packs to the manifest — idempotent, headless-safe.
cmd_apply() {
  local name p
  for name in $(manifest_names); do
    if [ ! -d ".packs/$name" ]; then
      echo "apply: mounting '$name'"
      cmd_add "$name" "$(manifest_repo "$name")" || echo "apply: '$name' failed — continuing" >&2
    fi
  done
  for p in .packs/*/; do
    [ -d "$p" ] || continue
    name=$(basename "$p")
    if ! manifest_names | grep -qx "$name"; then
      echo "apply: unmounting '$name' (not in $MANIFEST)"
      cmd_remove "$name"
    fi
  done
  cmd_sync
  echo "apply: state matches $MANIFEST"
}

cmd_update() {
  if [ -n "${1:-}" ]; then git submodule update --remote ".packs/$1"
  else git submodule update --remote $(git config -f .gitmodules --get-regexp path | awk '$2 ~ /^\.packs\// {print $2}'); fi
  cmd_sync
  echo "pin(s) moved. Review, then commit the bump."
}

cmd_list() {
  local p pname pin n
  for p in .packs/*/; do
    [ -d "$p" ] || { echo "no packs mounted"; return; }
    pname=$(basename "$p")
    pin=$(git -C "$p" rev-parse --short HEAD 2>/dev/null || echo "?")
    n=$(find "$(skills_src ".packs/$pname")" -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
    echo "$pname  @$pin  ($n skills)"
  done
}

case "${1:-}" in
  add) shift; cmd_add "$@" ;;
  remove) shift; cmd_remove "$@" ;;
  update) shift; cmd_update "${1:-}" ;;
  list) cmd_list ;;
  sync) cmd_sync ;;
  apply) cmd_apply ;;
  *) echo "usage: $0 add <name> [repo-url] | remove <name> | update [name] | list | sync | apply" >&2; exit 1 ;;
esac
