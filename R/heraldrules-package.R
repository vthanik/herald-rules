#' heraldrules: Validation Rules Data for the 'herald' Package
#'
#' Pre-compiled validation rules, submission profile configurations, and
#' CDISC controlled terminology for use with the \pkg{herald} package.
#'
#' ## Datasets
#'
#' \describe{
#'   \item{\code{\link{hr_rules}}}{Master rules table — 3,593 rules, 20 columns.}
#'   \item{\code{\link{hr_configs}}}{Submission profile configs (named list).}
#'   \item{\code{\link{hr_ct}}}{CDISC controlled terminology (SDTM + ADaM).}
#'   \item{\code{\link{hr_manifest}}}{Package manifest with rule counts and sources.}
#' }
#'
#' ## Accessor functions
#'
#' \describe{
#'   \item{\code{\link{hr_list_configs}}}{List available submission profile names.}
#'   \item{\code{\link{hr_get_config}}}{Get rule IDs for a submission profile.}
#'   \item{\code{\link{hr_rules_for_config}}}{Subset \code{hr_rules} to a profile.}
#' }
#'
#' @keywords internal
"_PACKAGE"
