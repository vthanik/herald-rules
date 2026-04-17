---
name: autoupdate
description: >
  Run the full heraldrules quarterly refresh — fetch upstream sources,
  regenerate CT assets, rebuild configs + manifest + master CSV, and run
  the full validator suite. Use when the user types `/autoupdate` or
  asks to "do the quarterly refresh", "sync all sources", or "pull the
  new CT packages". Not for incremental single-rule changes — use the
  `rule-sync` skill for those.
allowed-tools: Bash, Read, Edit
---

# Autoupdate — quarterly refresh workflow

## When to invoke
- User says `/autoupdate`, "quarterly refresh", "fetch new CT", "sync
  all sources", "rebuild everything from upstream", or equivalents.
- NCI EVS / CDISC Library / PMDA / FDA announce a new release.
- Calendar: roughly once per CDISC CT quarterly release (Mar, Jun, Sep, Dec).

## Prereqs (check before running)
1. `.local/.env` exists and contains `CDISC_API_KEY=...`.
2. FDA Validator Rules v1.6 Excel file at `.local/sources/` (if a newer
   FDA version was released, replace it; otherwise the cached file is
   reused).
3. Working tree is clean enough that reviewing the diff makes sense
   (ask the user to stash or commit WIP first if not).
4. Internet reachable to `library.cdisc.org`, `api-evsrest.nci.nih.gov`,
   `www.pmda.go.jp`.

## Execution plan

Run these in order. STOP at the first failure and show the user the
output; do not silently continue.

```bash
# 0. Snapshot the current counts so the diff is visible
cat manifest.json | python3 -c "import sys,json; print(json.load(sys.stdin)['stats'])"

# 1. Full refresh (fetches CDISC rules, PMDA, FDA, CT; regenerates configs+manifest)
Rscript inst/scripts/refresh-all.R

# 2. If refresh-all.R aborted partway, run the individual steps manually:
#    Rscript inst/scripts/fetch-cdisc.R
#    Rscript inst/scripts/fetch-pmda.R
#    Rscript inst/scripts/fetch-fda.R
#    Rscript inst/scripts/fetch-ct.R
#    Rscript inst/scripts/fetch-ig-variables.R
#    Rscript inst/scripts/build-configs.R
#    Rscript inst/scripts/build-master-csv.R
#    Rscript inst/scripts/build-manifest.R

# 3. Validate
Rscript tests/validate-rules.R
Rscript tests/validate-herald-rules.R
Rscript tests/validate-define-rules.R

# 4. Post-refresh sanity checks
python3 -c "
import json, glob, sys
for f in sorted(glob.glob('configs/*.json')):
    d = json.load(open(f)); ids = d['rule_ids']
    if len(ids) != len(set(ids)): print('FAIL dupes', f); sys.exit(1)
    print('OK', f, len(ids))
"

# 5. Show the diff summary
cat manifest.json | python3 -c "import sys,json; print(json.load(sys.stdin)['stats'])"
git status --short
```

## After-the-fact review (CRITICAL — do not skip)

The refresh may silently add, remove, or rename rules/codelists.
Walk through these AFTER the scripts succeed:

1. **Diff `manifest.json`** — compare `stats.by_engine` against the
   pre-refresh snapshot. Any count change needs a CHANGELOG entry.
2. **Check for deprecated codelists** in `ct/sdtm-ct.json` /
   `ct/adam-ct.json` (search for `deprecated_in`). Note them in
   CHANGELOG if new.
3. **Diff `configs/all.json`** — which rule IDs were added or removed?
4. **Inspect `herald-master-rules.csv`** tail — new CDISC CORE /
   PMDA / FDA rules should have full provenance populated.
5. **Bump docs** — CLAUDE.md "Architecture" block and README table both
   carry engine counts. If counts moved, update both (and CHANGELOG).
6. **NO version bump without user approval** (CLAUDE.md rule). Record
   the refresh under `## Unreleased`.

## What NOT to do

- Do NOT commit during the refresh — do the full run first, then review
  the diff, then let the user decide what gets committed.
- Do NOT overwrite `.local/.env`.
- Do NOT use `--force` on fetches unless the user explicitly asks; the
  on-disk cache lets reviewers re-run cheaply.
- Do NOT remove deprecated rules or codelists — they keep working for
  legacy specs; only flag them.

## Rollback

If the refresh produces something wrong and you need to revert:

```bash
git status
git diff --stat                # see what changed
git checkout -- ct/ configs/ manifest.json herald-master-rules.csv
# OR, if you need to keep some and drop others, stage selectively then reset
```

Ask the user before any destructive rollback.
