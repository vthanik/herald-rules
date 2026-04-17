# Define-XML v2.1 Spec Validation Rules -- Traceability

Rules derived from the CDISC Define-XML v2.1 Specification (Final, 2019-05-15)
and aligned with Pinnacle 21 Enterprise define validation rules.

> **Rename history:** Rules in this directory were originally numbered
> `DD0001..DD0086`. They were renamed to `HRL-DD-024..HRL-DD-109`
> (new number = old number + 23) to avoid ID collision with PMDA's
> DD-series rules in `engines/pmda/`. The "Internal ID" column below shows
> the current heraldrules ID; the "P21 Alignment" column keeps the external
> P21 Community identifiers unchanged because those belong to P21's
> namespace, not ours.

## Rule → Spec Section Mapping

| Internal ID range | Spec Section | Topic | P21 Alignment |
|---|---|---|---|
| HRL-DD-024..028 | 5.3.3, 5.3.4, 5.3.5 | ODM root, Study, GlobalVariables, MetaDataVersion | DD0006, DD0007 |
| HRL-DD-029..030 | 5.3.11, 5.3.9.1 | ItemGroupDef required attrs, Description | DD0057 |
| HRL-DD-031..033 | 5.3.11.2 | def:Class, def:SubClass allowable values | DD0055 |
| HRL-DD-034 | 5.3.11 | def:Structure required | -- |
| HRL-DD-035..039 | 4.1.1, 5.3.6.1 | def:Standard Name/Type/Version allowable values | DD0148 |
| HRL-DD-040 | 5.3.9.2 | ItemRef KeySequence requirement | DD0040 |
| HRL-DD-041..042 | 5.3.11 | Repeating, IsReferenceData business rules | OD0072 |
| HRL-DD-043 | 5.3.11 | Purpose: Tabulation vs Analysis | -- |
| HRL-DD-044..045 | 5.3.12, 5.3.9.1 | ItemDef Name, Description required | DD0057 |
| HRL-DD-046..051 | 4.3.1, 5.3.12 | DataType, Length, SignificantDigits rules | DD0068, DD0123 |
| HRL-DD-052 | 5.3.9.2 | Mandatory attribute | -- |
| HRL-DD-053..061 | 4.3.2, 5.3.12.3, 4.9 | Origin/Source/Traceability rules | DD0072, DD0109 |
| HRL-DD-062..063 | 5.3.9.2, 5.3.11 | OrderNumber, cross-ref to ItemGroupDef | OD0046 |
| HRL-DD-064..070 | 5.3.9, 5.3.10, 4.5 | ValueListDef, WhereClauseDef rules | DD0001 |
| HRL-DD-071..078 | 5.3.13, 4.4 | CodeList, EnumeratedItem, CodeListItem rules | DD0024, DD0031, DD0032, DD0033 |
| HRL-DD-079..082 | 5.3.14 | MethodDef rules | DD0104 |
| HRL-DD-083..086 | 5.3.15, 5.3.16 | CommentDef, def:leaf rules | DD0071 |
| HRL-DD-087..096 | 3.5 (OIDs/Defs-and-Refs) | Cross-reference integrity between sheets | OD0046, OD0048, DD0071 |
| HRL-DD-097..100 | 3.5 (OIDs) | Orphan detection | DD0079, DD0080, DD0082 |
| HRL-DD-101..104 | ARM 1.0 | Analysis Results Metadata rules | DD0091, DD0096, DD0099, DD0100 |
| HRL-DD-105..108 | 4.3.2, 5.3.12, 5.3.13, 4.1.1 | Origin consistency, datatype match, CT | DD0029, OD0075, OD0080, DD0148 |
| HRL-DD-015..023 | Various | Herald-original extensions (SUPPQUAL VLM, origin biconditionals) | -- |

## Quarterly Refresh Process

When CDISC publishes a new Define-XML specification version:

1. Diff the new spec against the current version, section by section
2. Use the table above to identify which HRL-DD rules are affected
3. For changed requirements: increment `version` in YAML, update provenance
4. For new requirements: create new HRL-DD rules with next available ID
5. For removed requirements: set `status: Deprecated` with reason
6. Update: herald-master-rules.csv, configs/*.json, manifest.json, CHANGELOG.md

## Source Documents

- CDISC Define-XML v2.1 Specification (Final, 2019-05-15)
- P21 Enterprise define_rules.xlsx (31 DD rules + 6 OD rules) — P21 rule IDs
  are preserved verbatim in the YAML `provenance.p21_reference` field
- Define-XML v2.1 XML Schema (define2-1-0.xsd)
