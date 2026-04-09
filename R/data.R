#' Herald master rules table
#'
#' A data frame containing all 3,593 validation rules across all engines.
#' This is the compiled form of \code{herald-master-rules.csv} and is the
#' primary data object used by the \pkg{herald} package to identify and
#' execute rules.
#'
#' @format A data frame with one row per rule and 20 columns:
#' \describe{
#'   \item{rule_id}{Unique rule identifier (e.g. \code{"CORE-000001"},
#'     \code{"FDAB001"}, \code{"HRL-AD-001"}).}
#'   \item{source}{Source system (CDISC Library, FDA, PMDA, Herald).}
#'   \item{source_document}{Source document name.}
#'   \item{source_url}{URL of the source document.}
#'   \item{authority}{Regulatory authority (CDISC, FDA, PMDA, Herald).}
#'   \item{standard}{CDISC standard (SDTM, ADaM, SEND, Define-XML).}
#'   \item{ig_versions}{Implementation guide versions the rule applies to.}
#'   \item{rule_type}{Rule type (Record Data, Dataset, Variable, etc.).}
#'   \item{publisher_id}{Original publisher ID (CDISC, FDA rule number).}
#'   \item{conformance_rule_origin}{Rule origin document reference.}
#'   \item{cited_guidance}{CDISC guidance citation.}
#'   \item{message}{Short human-readable violation message.}
#'   \item{description}{Full rule description.}
#'   \item{domains}{Applicable CDISC domains.}
#'   \item{classes}{Applicable CDISC classes.}
#'   \item{severity}{Error, Warning, or Notice.}
#'   \item{sensitivity}{Rule sensitivity level.}
#'   \item{executability}{Fully Executable, Partially Executable, or Hardcoded.}
#'   \item{status}{Published or Draft.}
#'   \item{notes}{Additional notes.}
#' }
#' @source \url{https://github.com/vthanik/herald-rules}
"hr_rules"

#' Herald submission profile configurations
#'
#' A named list of submission profile configurations. Each element corresponds
#' to one configuration file (e.g. \code{"fda-sdtm-ig-3.3"}) and contains the
#' vector of rule IDs that should be run for that profile.
#'
#' @format A named list. Names are config identifiers (e.g.
#'   \code{"fda-sdtm-ig-3.3"}). Each element is a character vector of rule IDs.
#'
#' @seealso \code{\link{hr_get_config}}, \code{\link{hr_rules_for_config}}
#' @source \url{https://github.com/vthanik/herald-rules}
"hr_configs"

#' CDISC controlled terminology
#'
#' A data frame containing CDISC NCI EVS controlled terminology terms for
#' SDTM and ADaM. Used by the \pkg{herald} package for terminology validation.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{codelist_code}{NCI codelist C-code.}
#'   \item{codelist_name}{Human-readable codelist name.}
#'   \item{codelist_submission_value}{Submission value for the codelist.}
#'   \item{codelist_extensible}{Whether the codelist is extensible.}
#'   \item{term_code}{NCI term C-code.}
#'   \item{term_submission_value}{Submission value for the term.}
#'   \item{term_preferred_name}{NCI preferred term name.}
#'   \item{term_definition}{Term definition.}
#'   \item{standard}{SDTM or ADaM.}
#' }
#' @source NCI EVS CDISC Controlled Terminology \url{https://evs.nci.nih.gov/}
"hr_ct"

#' Herald rules manifest
#'
#' A list containing package metadata: rule counts by engine, source
#' descriptions, minimum herald version, and generation date.
#'
#' @format A list with elements \code{schema_version}, \code{herald_min_version},
#'   \code{generated}, \code{sources}, and \code{stats}.
#' @source \url{https://github.com/vthanik/herald-rules}
"hr_manifest"
