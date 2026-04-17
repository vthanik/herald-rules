---
name: rule-sync
description: >
  Propagate a single rule add / modify / delete across every interlinked
  file in heraldrules so nothing drifts. Use whenever a rule YAML under
  engines/ is created, edited, or deprecated — even for seemingly small
  edits to description, scope, or severity. Covers master CSV, configs,
  manifest, CHANGELOG, README, CLAUDE.md, GOVERNANCE, RULE_SCHEMA,
  LICENSE-adjacent metadata, and the ct/ and inst/metadata/ assets when
  applicable. This is the safety net that prevents "I edited the YAML
  but forgot the CSV" drift.
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
---

# Rule-Sync — keep every interlinked file consistent

A single rule change touches many files. This skill is the runbook;
execute the matching branch (ADD / MODIFY / DELETE) end-to-end.

## Trigger
Invoke whenever:
- A file under `engines/**/*.yaml` is created, edited, or deprecated.
- A rule ID is renamed.
- A codelist or CT entry is added/removed/renamed that a rule references.
- The user says "sync everything", "update all the places", or similar.

## Pre-flight
Before touching anything:

```bash
# Snapshot so you can verify downstream counts after
cat manifest.json | python3 -c "import sys,json; print(json.load(sys.stdin)['stats'])"
git status --short
```

## Branch A — ADDING a rule

All steps required:

1. **YAML file** — `engines/<engine>/<rule_id>.yaml` (or
   `engines/herald/define/HRL-DD-NNN.yaml` for Define-XML spec rules).
   Include `version: 1`, `status: Published`, `tests:` block with at
   least one `positive` and one `negative` case (CLAUDE.md mandate),
   full `provenance:`.
2. **`herald-master-rules.csv`** — append a row with all 20 columns
   (`rule_id, source, source_document, source_url, authority, standard,
   ig_versions, rule_type, publisher_id, conformance_rule_origin,
   cited_guidance, message, description, domains, classes, severity,
   sensitivity, executability, status, notes`). Match quoting style of
   neighbouring rows.
3. **Regenerate `configs/*.json`** via `Rscript inst/scripts/build-configs.R`.
4. **Regenerate `manifest.json`** via `Rscript inst/scripts/build-manifest.R`.
5. **`CHANGELOG.md`** — append a bullet under `## Unreleased` (or the
   current unreleased heading). Include the rule ID, one-line purpose,
   and authority.
6. **`README.md`** — if the engine count changed, update the table row
   under "Overview" (`| engine | N | source |`).
7. **`CLAUDE.md`** — "Architecture" block engine counts AND the "Herald
   Rule ID Convention" table if a new prefix/category was introduced.
8. **`RULE_SCHEMA.md`** — touch only if the rule uses a new operator
   or schema field not already documented.
9. **`GOVERNANCE.md`** — only if the add changes governance scope (new
   authority, new release cadence, etc.).
10. **Validate** — run all three validators. Non-negotiable:
    ```bash
    Rscript tests/validate-rules.R
    Rscript tests/validate-herald-rules.R
    Rscript tests/validate-define-rules.R
    ```

## Branch B — MODIFYING a rule

1. **YAML file** — edit in place; **bump `version:`** (existing
    value + 1).
2. **`herald-master-rules.csv`** — update the matching row (columns
    that describe the rule: description, message, severity, scope,
    status).
3. **`configs/*.json`** — re-run `build-configs.R` **only if** the
    scope, `herald.ig_versions`, executability, or status changed.
    Description/message-only edits do not need a rebuild.
4. **`manifest.json`** — re-run `build-manifest.R` **only if** counts
    moved (e.g. status changed to Deprecated).
5. **`CHANGELOG.md`** — bullet under `## Unreleased`: "Changed — <ID>:
    what changed and why."
6. **`README.md`** — touch only if the engine count moved.
7. **Validate** — full 3-validator sweep.

## Branch C — DEPRECATING a rule

Per CLAUDE.md: do NOT delete the YAML file.

1. **YAML file** — set `status: Deprecated`; add a `deprecated:` block
    with `date:`, `reason:`, `replaced_by:` (ID of replacement rule if
    any).
2. **`herald-master-rules.csv`** — set the status column to
    `Deprecated`.
3. **`configs/*.json`** — KEEP the rule ID in configs (audit trail).
    Do not remove.
4. **`manifest.json`** — re-run `build-manifest.R`.
5. **`CHANGELOG.md`** — bullet under `## Unreleased`: "Deprecated —
    <ID>: reason. Replaced by <new-ID>."
6. **`README.md`** — no change unless the engine count definition
    excludes deprecated rules (it doesn't today).
7. **`CLAUDE.md`** — add a note only if this deprecation is a lesson
    worth remembering (e.g. "HRL-X-NNN retired because of Y").
8. **Validate** — full 3-validator sweep.

## Branch D — CT / codelist / variable-mapping update

If the change affects CT JSON or the variable→codelist map:

1. Run **`Rscript inst/scripts/fetch-ct.R`** and/or
    **`fetch-ig-variables.R`**. These are cached (`.local/cdisc-cache/`)
    so iteration is cheap.
2. Inspect the diff on `ct/sdtm-ct.json`, `ct/adam-ct.json`,
    `ct/variable-to-codelist.json`, `ct/ct-manifest.json`.
3. Any new `deprecated_in` entries → note in CHANGELOG.
4. If the **schema** of any ct/* file changed (e.g. new field), bump
    `schema_version` in `ct-manifest.json` AND update
    `HERALD_HANDOFF.md` so the herald R package consumer is warned.
5. Regenerate configs + manifest. Validate.

## Branch E — Per-codelist rules (HRL-CT-NNNN)

These are auto-generated with terms baked in. If CT changes:

1. The bulk regenerator lives under `inst/scripts/` (check
    `build-*.R` — there is not always an explicit rebuilder; sometimes
    rules are generated once and committed).
2. If individual HRL-CT rules need to be regenerated, do that
    separately and treat as Branch A or B per rule.
3. Never edit per-codelist YAMLs by hand if a regenerator exists —
    edits will be clobbered on the next refresh.

## Sanity checklist (run at the end of every branch)

```bash
# 1. All configs have unique IDs (no silent dupes)
python3 -c "
import json, glob, sys
for f in sorted(glob.glob('configs/*.json')):
    d = json.load(open(f)); ids = d['rule_ids']
    if len(ids) != len(set(ids)):
        print('FAIL dupes in', f); sys.exit(1)
    print('OK', f, len(ids))
"

# 2. No references to a local doc/path leaked into YAML provenance
#    (e.g. SAS_TO_P21_SPEC.md, buildspec-test, any /Users/... path)
grep -rn "SAS_TO_P21_SPEC\|buildspec-test\|HERALDRULES_HANDOFF\|/Users/" \
     engines/ herald-master-rules.csv configs/ CHANGELOG.md README.md \
     CLAUDE.md GOVERNANCE.md RULE_SCHEMA.md CONTRIBUTING.md \
     HERALD_HANDOFF.md engines/herald/define/TRACEABILITY.md 2>/dev/null \
     || echo "OK clean"

# 3. All three validators pass with no errors
Rscript tests/validate-rules.R         | tail -5
Rscript tests/validate-herald-rules.R   | tail -5
Rscript tests/validate-define-rules.R   | tail -5

# 4. Git diff summary — show the user what changed
git status --short
git diff --stat
```

## Markdown documentation sweep (MANDATORY — every branch)

Catalog counts, rule-ID ranges, and rule-ID examples drift silently in
`.md` files as soon as anything is added, renamed, or deprecated. After
rules change, audit every markdown file for stale content. Run this
before closing the branch:

```bash
# List every .md under the repo root (excluding .git, .local, node_modules)
find . -name "*.md" -not -path "*/.git/*" -not -path "*/.local/*" \
     -not -path "*/node_modules/*" | sort
```

For each file, compare against current state:

| Markdown file | What to check |
|---|---|
| `README.md` | Engine counts in the overview table; "Repository Structure" tree counts; Define-XML rule-range table; any embedded rule YAML examples (must use current ID + current operator polarity) |
| `CLAUDE.md` | "Architecture" block engine counts; "Herald Rule ID Convention" table (prefixes, counts, directories); any absolute paths — replace with relative `../` references |
| `CONTRIBUTING.md` | Repository tree counts; Rule ID Pattern table (prefix + example) |
| `RULE_SCHEMA.md` | Rule ID Pattern table (must match CONTRIBUTING.md); operator list (must match `tests/allowed-operators.txt`) |
| `GOVERNANCE.md` | Release cadence, source/authority list, effective-date claims |
| `CHANGELOG.md` | Current `## Unreleased` section names every changed file AND every changed rule ID |
| `HERALD_HANDOFF.md` | Cross-repo items (CT asset shape changes, new operators, renamed rule IDs consumers pin on) — any unresolved items still listed |
| `engines/herald/define/TRACEABILITY.md` | Rule-ID ranges in the mapping table (HRL-DD-NNN, not legacy DDnnnn) |
| `.claude/skills/supported-versions/SKILL.md` | Supported IG versions, config list, CT schema version |
| `.claude/skills/autoupdate/SKILL.md` | Script names + flags (if refresh flow changed) |
| `.claude/skills/rule-sync/SKILL.md` | This file — keep it honest about which files sync touches |

### Grep sweep for common drift patterns

```bash
# Stale rule-count claims (must be updated after any add/rename/deprecate)
grep -rn "3,749\|3,761\|3,819\|251\|135 YAML\|100 YAML.*Define\|147 HRL\|18 rules" \
     README.md CLAUDE.md CONTRIBUTING.md RULE_SCHEMA.md GOVERNANCE.md \
     HERALD_HANDOFF.md engines/herald/define/TRACEABILITY.md 2>/dev/null \
     || echo "OK: no stale counts"

# Stale DDnnnn references outside of CHANGELOG/HERALD_HANDOFF history blocks
# (those two files intentionally keep old names while describing renames)
grep -rn "DD00[0-9]\{2\}" README.md CLAUDE.md CONTRIBUTING.md RULE_SCHEMA.md \
     GOVERNANCE.md 2>/dev/null || echo "OK: no stale DDnnnn references"

# Any rule-YAML example in docs using an inverted-polarity operator
grep -rn "operator: equal_to" README.md CLAUDE.md RULE_SCHEMA.md \
     CONTRIBUTING.md 2>/dev/null
# If any matches: verify the example is meant to demonstrate the rule
# as-written (post-polarity-fix). Older examples pre-fix should be swapped
# to not_equal_to / non_empty / in per the CLAUDE.md operator guide.
```

### When doc updates are required

- **Any rule add/delete** → README table row, CLAUDE.md architecture
  counts, CHANGELOG entry. If the add introduces a new prefix, also
  CONTRIBUTING.md + RULE_SCHEMA.md ID-pattern tables.
- **Any rule rename** → the rename note must appear in TRACEABILITY.md
  (if it's a define-xml rule) or the appropriate ID-convention table.
  Plus a CHANGELOG "Renamed" bullet and an HERALD_HANDOFF entry for
  downstream consumers.
- **Any CT/asset schema change** → supported-versions skill +
  HERALD_HANDOFF.md (consumer warning) + ct-manifest.json bump.
- **Any script interface change** → autoupdate skill + CLAUDE.md
  Quarterly Refresh block.
- **Any config add/remove** → README Overview counts + supported-versions
  skill table + manifest.json regeneration.

### Decision rule

Before declaring rule-sync done, every file on the markdown table above
must either:
1. Have been verified unchanged and still correct, **or**
2. Be in the current commit's `git diff --stat` with the correct
   updates applied.

If neither holds for any file, stop and update it.

## Edits that DO NOT need full sync

These are internal-only and do not touch the catalog:

- Comment-only edits inside a script in `inst/scripts/` (no rule
  effect). Update script docstring if behaviour changed.
- Fixes to validator scripts under `tests/`.
- `.claude/` skill edits (skills themselves).

## Pitfalls worth calling out

- **Cross-engine DD ID duplicates** — DD0001..DD0086 live in both
  `engines/pmda/` and `engines/herald/define/`. `build-configs.R`
  dedupes silently with a warning; do not panic, but if you added a
  new DDnnnn rule check both dirs first.
- **Define/ subdirectory** — `engines/herald/define/` is scanned
  recursively by `build-configs.R` and `build-manifest.R` (both have
  `recursive = TRUE`). Anything added here will be picked up.
- **Pre-existing issues discovered during sync** — per CLAUDE.md, flag
  to the user and ASK before fixing. Do not snowball scope.
- **Version bumps** — CLAUDE.md forbids version bumps without explicit
  user approval. If the user says "release", ask what version string.
- **Master CSV quoting** — always double-quote every column; match the
  surrounding rows' formatting exactly.
