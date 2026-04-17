---
name: supported-versions
description: >
  Reference manifest of the exact regulatory-standard versions this
  heraldrules catalog ships configs for. Check this BEFORE writing any rule,
  updating any config, claiming a version in docs, or answering the user
  about whether a standard/version is supported. Authoritative for
  SDTM-IG, ADaM-IG, Define-XML, CDISC CT, FDA Validator Rules, FDA
  Business Rules, PMDA Validation Rules, and CORE Engine rule sets.
  Triggers: questions like "do we support X version?", "which SDTM versions
  ship?", "is 1.3 supported?", writing rules or configs, and any
  version-number claim in README / CHANGELOG / CLAUDE.md.
---

# Supported Versions — heraldrules

This is the authoritative list of standards and versions this repository
ships configs and rules for. Do not claim any version not listed here.
When asked, answer from this document — then spot-check `configs/*.json`
to confirm current state.

## Shipping configs (`configs/*.json`)

| Config file | Authority | Standard | Version |
|---|---|---|---|
| `fda-sdtm-ig-3.2.json` | FDA | SDTM-IG | 3.2 |
| `fda-sdtm-ig-3.3.json` | FDA | SDTM-IG | 3.3 |
| `fda-adam-ig-1.1.json` | FDA | ADaM-IG | 1.1 |
| `fda-adam-ig-1.2.json` | FDA | ADaM-IG | 1.2 |
| `fda-define-xml-2.1.json` | FDA | Define-XML | 2.1 |
| `pmda-sdtm-ig-3.2.json` | PMDA | SDTM-IG | 3.2 |
| `pmda-sdtm-ig-3.3.json` | PMDA | SDTM-IG | 3.3 |
| `pmda-adam-ig-1.1.json` | PMDA | ADaM-IG | 1.1 |
| `pmda-define-xml-2.1.json` | PMDA | Define-XML | 2.1 |
| `all.json` | Combined | All | Union of the above |

## Not supported

These versions exist upstream but heraldrules does **NOT** ship configs
for them. Do not advertise support, do not write 1.3-scoped rules.

- **ADaM-IG 1.3** — IG text exists on CDISC Library; heraldrules pulls
  variable/core metadata for reference (`ct/variable-to-codelist.json`)
  but ships no `fda-adam-ig-1.3` or `pmda-adam-ig-1.3` config.
- **SDTM-IG 3.4** — same story; variable metadata is fetched for
  reference only.
- **PMDA ADaM 1.2** — a `pmda-adam-ig-1.2` config is not shipped; PMDA
  ADaM coverage stops at 1.1.
- **SEND-IG** — deferred to post-CRAN release (see CLAUDE.md).
- **ODM** — 9 HRL-OD rules exist in `engines/herald/`, but no top-level
  ODM config is shipped.

## Source documents + effective dates

These are the documents each engine tracks. Update `inst/sources.json`,
`ct/ct-manifest.json`, and `manifest.json` when any effective date moves.

| Engine | Source | Version / date |
|---|---|---|
| `cdisc/` | CDISC Library API | Rolling (fetched per quarterly refresh) |
| `cdisc/` — ADaM-NNN rules | ADaM IG Conformance v1.1 + v1.2 | Ships both |
| `fda/` — Business Rules | FDA Business Rules | **v1.5** |
| `fda/` — Validator Rules | FDA Validator Rules | **v1.6** (December 2022) |
| `pmda/` | PMDA Study Data Validation Rules | **v6.0** (March 2025) |
| `ct/` | CDISC Library CT packages | Latest `sdtmct-*` + `adamct-*` (oldest-first walk across 6 recent of each) |
| `ct/` — manifest | see `ct/ct-manifest.json` | `schema_version: 2`, `terms_format: "object"` |
| `engines/cdisc/` CORE engine | CDISC Library `/api/mdr/rules` | 450 SDTM/SEND + 253 ADaM rules |

## Herald-authored ID prefixes (per CLAUDE.md)

| Prefix | Scope | Directory |
|---|---|---|
| `HRL-AD-NNN` | ADaM gap-fill | `engines/herald/` |
| `HRL-FM-NNN` | Form metadata | `engines/herald/` |
| `HRL-MD-NNN` | Metadata (ADaM v1.2) | `engines/herald/` |
| `HRL-OD-NNN` | ODM conformance | `engines/herald/` |
| `HRL-SD-NNN` | SDTM gap-fill | `engines/herald/` |
| `HRL-TS-NNN` | Trial summary | `engines/herald/` |
| `HRL-DD-NNN` | Define-XML spec | `engines/herald/define/` |
| `HRL-VAR/LBL/TYP/LEN/DS/CL-NNN` | Hardcoded spec checks | `engines/herald/` |
| `HRL-CT-NNNN` | CT per-codelist | `engines/ct/` |

## CT JSON schema version

`ct/sdtm-ct.json` and `ct/adam-ct.json` ship **schema_version: 2** (terms
as array of objects: `{submissionValue, conceptId, preferredTerm}`).
Schema 1 (plain string terms) is deprecated — downstream consumers must
dispatch on the `schema_version` + `terms_format` fields in
`ct/ct-manifest.json`.

## Deprecation tracking

Codelists present in older CT packages but removed/renamed in the latest
one carry `deprecated_in` (package name) and optionally `superseded_by`
(new submission value). Example: `RACE` (C74457) is marked
`deprecated_in: "sdtmct-2026-03-27"`, `superseded_by: "RACEC"`.

## Where to look first

- `configs/*.json` — ground truth for "which rules apply to which
  (authority, standard, version) combo".
- `manifest.json` — engine rule counts + config summary (rebuilt by
  `build-manifest.R`).
- `ct/ct-manifest.json` — CT package effective dates.
- `inst/sources.json` — upstream source URLs and fetch metadata.

If any version question remains after consulting those four files, say
so — do not guess.
