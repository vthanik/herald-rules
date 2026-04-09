#' List available submission profile configurations
#'
#' Returns the names of all submission profiles bundled in \pkg{heraldRules}.
#' Pass any of these to \code{\link{hr_get_config}} or
#' \code{\link{hr_rules_for_config}}.
#'
#' @return A character vector of config names, e.g.
#'   \code{"fda-sdtm-ig-3.3"}, \code{"pmda-adam-ig-1.1"}.
#'
#' @examples
#' hr_list_configs()
#'
#' @export
hr_list_configs <- function() {
  sort(names(heraldRules::hr_configs))
}

#' Get rule IDs for a submission profile
#'
#' Returns the character vector of rule IDs that should be run for the
#' specified submission profile configuration.
#'
#' @param config A configuration name, e.g. \code{"fda-sdtm-ig-3.3"}.
#'   Use \code{\link{hr_list_configs}} to see available names.
#'
#' @return A character vector of rule IDs.
#'
#' @examples
#' ids <- hr_get_config("fda-sdtm-ig-3.3")
#' length(ids)
#'
#' @export
hr_get_config <- function(config) {
  stopifnot(is.character(config), length(config) == 1L)
  cfg <- heraldRules::hr_configs[[config]]
  if (is.null(cfg)) {
    available <- paste(hr_list_configs(), collapse = ", ")
    stop(
      sprintf("Config '%s' not found. Available: %s", config, available),
      call. = FALSE
    )
  }
  cfg
}

#' Subset master rules table to a submission profile
#'
#' Filters \code{\link{hr_rules}} to only rows whose \code{rule_id} is
#' included in the specified submission profile configuration.
#'
#' @param config A configuration name, e.g. \code{"fda-sdtm-ig-3.3"}.
#'   Use \code{\link{hr_list_configs}} to see available names.
#'
#' @return A data frame — a subset of \code{\link{hr_rules}}.
#'
#' @examples
#' fda_sdtm <- hr_rules_for_config("fda-sdtm-ig-3.3")
#' nrow(fda_sdtm)
#'
#' @export
hr_rules_for_config <- function(config) {
  ids <- hr_get_config(config)
  heraldRules::hr_rules[heraldRules::hr_rules$rule_id %in% ids, , drop = FALSE]
}
