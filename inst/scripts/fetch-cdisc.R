#!/usr/bin/env Rscript
# =============================================================================
# fetch-cdisc.R -- Fetch CDISC Conformance Rules from CDISC Library API
# =============================================================================
#
# Downloads official CDISC conformance rules via the CDISC Library API
# and writes them as YAML to engines/cdisc/.
#
# Usage:
#   Rscript inst/scripts/fetch-cdisc.R                    # All SDTM + ADaM
#   Rscript inst/scripts/fetch-cdisc.R --dry-run           # Preview
#   Rscript inst/scripts/fetch-cdisc.R --catalog sdtmig/3-3  # Single catalog
#   Rscript inst/scripts/fetch-cdisc.R --force              # Overwrite
#   Rscript inst/scripts/fetch-cdisc.R --verbose            # Extra output
#
# API Key:
#   Reads from .local/.env (CDISC_API_KEY=...) or --api-key argument
#
# Output:
#   engines/cdisc/<CORE-ID>.yaml  -- One file per unique rule
#   .local/sources/cdisc-api-raw/ -- Cached raw JSON per catalog
#
# =============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L || all(is.na(x))) y else x

args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args
force   <- "--force" %in% args
verbose <- "--verbose" %in% args

catalog_filter <- NULL
if ("--catalog" %in% args) {
  idx <- match("--catalog", args)
  if (!is.na(idx) && idx < length(args)) catalog_filter <- args[idx + 1L]
}

api_key_arg <- NULL
if ("--api-key" %in% args) {
  idx <- match("--api-key", args)
  if (!is.na(idx) && idx < length(args)) api_key_arg <- args[idx + 1L]
}

# --- Locate repository root ---------------------------------------------------

repo_root <- getwd()
if (grepl("inst/scripts$", repo_root)) {
  repo_root <- normalizePath(file.path(repo_root, "..", ".."))
}

out_dir  <- file.path(repo_root, "engines", "cdisc")
raw_dir  <- file.path(repo_root, ".local", "sources", "cdisc-api-raw")
env_file <- file.path(repo_root, ".local", ".env")

if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
if (!dir.exists(raw_dir)) dir.create(raw_dir, recursive = TRUE)

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("jsonlite package required: install.packages('jsonlite')", call. = FALSE)
}
if (!requireNamespace("yaml", quietly = TRUE)) {
  stop("yaml package required: install.packages('yaml')", call. = FALSE)
}

# --- API key ------------------------------------------------------------------

get_api_key <- function() {
  if (!is.null(api_key_arg)) return(api_key_arg)
  if (nzchar(Sys.getenv("CDISC_API_KEY"))) return(Sys.getenv("CDISC_API_KEY"))
  if (file.exists(env_file)) {
    lines <- readLines(env_file, warn = FALSE)
    for (line in lines) {
      if (grepl("^CDISC_API_KEY=", line)) {
        return(sub("^CDISC_API_KEY=", "", trimws(line)))
      }
    }
  }
  stop("CDISC API key not found. Set CDISC_API_KEY in .local/.env or use --api-key",
       call. = FALSE)
}

API_KEY <- get_api_key()
BASE_URL <- "https://library.cdisc.org/api"

cat("=== Herald CDISC Rules Fetch ===\n\n")

# --- HTTP fetch ---------------------------------------------------------------

fetch_json <- function(path) {
  url <- paste0(BASE_URL, path)
  if (verbose) cat(sprintf("  GET %s\n", path))
  con <- url(url, headers = c("api-key" = API_KEY, "Accept" = "application/json"))
  on.exit(close(con))
  lines <- readLines(con, warn = FALSE)
  jsonlite::fromJSON(paste(lines, collapse = "\n"), simplifyVector = FALSE)
}

# --- Catalog configuration ----------------------------------------------------

CATALOGS <- list(
  list(path = "/mdr/rules/sdtmig/3-2", name = "SDTMIG 3.2", standard = "SDTM", version = "3.2"),
  list(path = "/mdr/rules/sdtmig/3-3", name = "SDTMIG 3.3", standard = "SDTM", version = "3.3"),
  list(path = "/mdr/rules/adam/adamig-1-1", name = "ADaMIG 1.1", standard = "ADaM", version = "1.1"),
  list(path = "/mdr/rules/adam/adamig-1-2", name = "ADaMIG 1.2", standard = "ADaM", version = "1.2")
)

if (!is.null(catalog_filter)) {
  CATALOGS <- Filter(function(c) grepl(catalog_filter, c$path, ignore.case = TRUE), CATALOGS)
  if (length(CATALOGS) == 0L) {
    stop(sprintf("No catalog matching '%s'", catalog_filter), call. = FALSE)
  }
}

# --- Fetch and deduplicate rules ----------------------------------------------

# Rules may appear in multiple catalogs (SDTMIG 3.2 and 3.3 share many rules).
# We deduplicate by CORE ID, keeping the richest version (most IG references).

all_rules <- list()       # keyed by CORE ID
rule_catalogs <- list()   # which catalogs each rule appears in

for (cat_cfg in CATALOGS) {
  cat(sprintf("Fetching %s...", cat_cfg$name))

  # Check cache
  cache_file <- file.path(raw_dir, sprintf("%s-%s.json",
                                           gsub("/", "-", cat_cfg$standard),
                                           cat_cfg$version))

  if (file.exists(cache_file) && !force) {
    cat(" (cached)")
    data <- jsonlite::fromJSON(readLines(cache_file, warn = FALSE),
                               simplifyVector = FALSE)
  } else {
    data <- tryCatch(fetch_json(cat_cfg$path), error = function(e) {
      cat(sprintf(" ERROR: %s\n", conditionMessage(e)))
      return(NULL)
    })
    if (is.null(data)) next

    # Cache raw response
    if (!dry_run) {
      writeLines(jsonlite::toJSON(data, auto_unbox = TRUE, pretty = TRUE),
                 cache_file)
    }
  }

  rules <- data$rules %||% list()
  cat(sprintf(" %d rules\n", length(rules)))

  for (rule in rules) {
    core_id <- rule$Core$Id %||% ""
    if (!nzchar(core_id)) next

    # Track catalog membership
    rule_catalogs[[core_id]] <- c(rule_catalogs[[core_id]], cat_cfg$name)

    # Keep rule if new, or replace if this version has more authorities
    existing <- all_rules[[core_id]]
    if (is.null(existing)) {
      all_rules[[core_id]] <- rule
    } else {
      # Keep the one with more authority references
      n_new <- length(rule$Authorities[[1]]$Standards %||% list())
      n_old <- length(existing$Authorities[[1]]$Standards %||% list())
      if (n_new > n_old) {
        all_rules[[core_id]] <- rule
      }
    }
  }
}

cat(sprintf("\nUnique rules after dedup: %d\n\n", length(all_rules)))

# --- Write YAML files ---------------------------------------------------------

cat("Writing YAML rules...\n")

written <- 0L
skipped <- 0L

for (core_id in names(all_rules)) {
  rule <- all_rules[[core_id]]

  # Remove _links (internal API navigation, not needed in YAML)
  rule[["_links"]] <- NULL
  rule[["id"]] <- NULL

  # Add herald metadata
  rule[["herald"]] <- list(
    source     = "CDISC Library API",
    catalogs   = as.list(rule_catalogs[[core_id]]),
    fetched    = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )

  fname <- sprintf("%s.yaml", core_id)
  fpath <- file.path(out_dir, fname)

  if (file.exists(fpath) && !force) {
    skipped <- skipped + 1L
    next
  }

  if (dry_run) {
    cat(sprintf("  [DRY RUN] %s: %s\n", core_id,
                substr(rule$Description %||% "", 1, 60)))
    written <- written + 1L
    next
  }

  yaml_str <- yaml::as.yaml(rule, indent.mapping.sequence = TRUE)
  writeLines(yaml_str, fpath, useBytes = TRUE)
  written <- written + 1L
}

# --- Summary ------------------------------------------------------------------

cat(sprintf("\n=== Summary ===\n"))
cat(sprintf("  Catalogs fetched: %d\n", length(CATALOGS)))
cat(sprintf("  Unique rules:     %d\n", length(all_rules)))
cat(sprintf("  Written:          %d\n", written))
cat(sprintf("  Skipped:          %d\n", skipped))
cat(sprintf("  Output:           %s\n", out_dir))

# Executability breakdown
exec <- vapply(all_rules, function(r) r$Executability %||% "Unknown", character(1))
cat(sprintf("\n  Executability:\n"))
for (e in sort(unique(exec))) {
  cat(sprintf("    %-25s %d\n", paste0(e, ":"), sum(exec == e)))
}

# Status breakdown
status <- vapply(all_rules, function(r) r$Core$Status %||% "Unknown", character(1))
cat(sprintf("\n  Status:\n"))
for (s in sort(unique(status))) {
  cat(sprintf("    %-25s %d\n", paste0(s, ":"), sum(status == s)))
}

if (dry_run) cat("\n  [DRY RUN] No files were actually written.\n")

cat("\nDone.\n")
