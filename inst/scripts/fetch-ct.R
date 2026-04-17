#!/usr/bin/env Rscript
# =============================================================================
# fetch-ct.R -- Fetch CDISC Controlled Terminology from CDISC Library API
# =============================================================================
#
# Downloads the most recent SDTM and ADaM CT packages from CDISC Library and
# writes herald-shaped JSON with per-term NCI concept IDs and preferred terms.
#
# Usage:
#   Rscript inst/scripts/fetch-ct.R               # Fetch all CT packages
#   Rscript inst/scripts/fetch-ct.R --sdtm-only   # SDTM CT only
#   Rscript inst/scripts/fetch-ct.R --adam-only   # ADaM CT only
#   Rscript inst/scripts/fetch-ct.R --top-n 3     # Walk 3 recent packages/type
#   Rscript inst/scripts/fetch-ct.R --force       # Ignore on-disk cache
#   Rscript inst/scripts/fetch-ct.R --verbose     # Log each HTTP call
#
# Output:
#   ct/sdtm-ct.json        -- SDTM codelist terms (object-shaped)
#   ct/adam-ct.json        -- ADaM codelist terms (object-shaped)
#   ct/ct-manifest.json    -- CT version metadata
#
# Schema note:
#   terms[] is now an array of objects:
#     { submissionValue, conceptId, preferredTerm }
#   rather than plain character vector. ct-manifest.json carries
#   `schema_version: 2` and `terms_format: "object"` so downstream
#   consumers can dispatch. Version 1 (plain string terms) is deprecated.
#
# Requirements:
#   - CDISC_API_KEY in environment or .local/.env
#   - jsonlite package
#
# =============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

args       <- commandArgs(trailingOnly = TRUE)
sdtm_only  <- "--sdtm-only" %in% args
adam_only  <- "--adam-only" %in% args
force      <- "--force"     %in% args
verbose    <- "--verbose"   %in% args
top_n_arg  <- which(args == "--top-n")
top_n      <- if (length(top_n_arg) && length(args) > top_n_arg) {
  as.integer(args[top_n_arg + 1L])
} else 6L

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("The jsonlite package is required.", call. = FALSE)
}

# --- Locate repository root --------------------------------------------------

repo_root <- getwd()
if (grepl("inst/scripts$", repo_root)) {
  repo_root <- normalizePath(file.path(repo_root, "..", ".."))
}

ct_dir    <- file.path(repo_root, "ct")
cache_dir <- file.path(repo_root, ".local", "cdisc-cache")
dir.create(ct_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

cat("=== Herald CT Fetch (CDISC Library) ===\n\n")

# --- Resolve API key --------------------------------------------------------

get_api_key <- function() {
  k <- Sys.getenv("CDISC_API_KEY")
  if (nzchar(k)) return(k)
  env_path <- file.path(repo_root, ".local", ".env")
  if (file.exists(env_path)) {
    for (l in readLines(env_path, warn = FALSE)) {
      if (grepl("^CDISC_API_KEY=", l)) {
        return(trimws(sub("^CDISC_API_KEY=", "", l)))
      }
    }
  }
  stop("CDISC_API_KEY not found in env or .local/.env", call. = FALSE)
}

API_KEY  <- get_api_key()
BASE_URL <- "https://library.cdisc.org/api"

# --- HTTP helper (tiny, built-in, with cache) -------------------------------

fetch_json <- function(path, cache_file = NULL) {
  if (!is.null(cache_file) && file.exists(cache_file) && !force) {
    if (verbose) cat(sprintf("  CACHE %s\n", path))
    return(jsonlite::read_json(cache_file, simplifyVector = FALSE))
  }
  if (verbose) cat(sprintf("  GET %s\n", path))
  con <- url(
    paste0(BASE_URL, path),
    headers = c("api-key" = API_KEY, "Accept" = "application/json")
  )
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  txt  <- paste(readLines(con, warn = FALSE), collapse = "\n")
  data <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
  if (!is.null(cache_file)) {
    writeLines(jsonlite::toJSON(data, auto_unbox = TRUE), cache_file)
  }
  data
}

# --- Select recent CT packages ---------------------------------------------

cat("Listing CT packages from CDISC Library...\n")
idx <- fetch_json(
  "/mdr/ct/packages",
  file.path(cache_dir, "ct_packages_index.json")
)
pkgs_refs <- idx[["_links"]][["packages"]] %||% list()
pkg_hrefs <- vapply(pkgs_refs, function(x) x$href %||% "", character(1))

top_n_of <- function(prefix, n = top_n) {
  pat  <- sprintf("/mdr/ct/packages/%s-[0-9]", prefix)
  hits <- grep(pat, pkg_hrefs, value = TRUE)
  if (length(hits) == 0) return(character(0))
  head(sort(hits, decreasing = TRUE), n)
}

sdtm_pkgs <- top_n_of("sdtmct")
adam_pkgs <- top_n_of("adamct")
cat(sprintf(
  "  SDTM: %s\n  ADaM: %s\n\n",
  paste(basename(sdtm_pkgs), collapse = ", "),
  paste(basename(adam_pkgs), collapse = ", ")
))

# --- Fetch one package, return list keyed by submissionValue ----------------

fetch_package_codelists <- function(pkg_href, label) {
  if (is.null(pkg_href) || !nzchar(pkg_href)) return(list())
  safe <- gsub("[^A-Za-z0-9]+", "_", pkg_href)
  res  <- fetch_json(pkg_href, file.path(cache_dir, paste0(safe, ".json")))
  cls  <- res[["codelists"]] %||% list()
  cat(sprintf("  %s: %d codelists\n", label, length(cls)))
  out <- list()
  for (cl in cls) {
    short <- cl[["submissionValue"]] %||% NA_character_
    if (is.null(short) || is.na(short) || !nzchar(short)) next
    code  <- cl[["conceptId"]] %||% NA_character_
    if (is.null(code) || is.na(code)) {
      href <- cl[["_links"]][["self"]][["href"]] %||% ""
      code <- sub(".*/", "", href)
    }
    terms_out <- list()
    for (t in cl[["terms"]] %||% list()) {
      sv <- t[["submissionValue"]] %||% NA_character_
      if (is.null(sv) || is.na(sv) || !nzchar(sv)) next
      terms_out[[length(terms_out) + 1L]] <- list(
        submissionValue = sv,
        conceptId       = t[["conceptId"]] %||% NA_character_,
        preferredTerm   = t[["preferredTerm"]] %||%
                            t[["definition"]] %||% NA_character_
      )
    }
    raw_ext <- cl[["extensible"]] %||% FALSE
    ext_flag <- if (is.logical(raw_ext)) {
      raw_ext
    } else {
      tolower(as.character(raw_ext)) %in% c("true", "yes", "1")
    }
    out[[short]] <- list(
      codelist_code = code,
      codelist_name = cl[["name"]] %||% NA_character_,
      extensible    = ext_flag,
      terms         = terms_out
    )
  }
  out
}

# --- Walk oldest-first so newer packages override older ones ----------------

pkgs_map <- list()
if (!adam_only) {
  cat("Fetching SDTM packages (oldest-first; newer overrides)...\n")
  lookup_sdtm <- list()
  for (pkg in rev(sdtm_pkgs)) {
    this <- fetch_package_codelists(pkg, paste("SDTM", basename(pkg)))
    for (k in names(this)) lookup_sdtm[[k]] <- this[[k]]
  }
  pkgs_map[["sdtm"]] <- list(
    file         = "sdtm-ct.json",
    label        = "CDISC SDTM Controlled Terminology",
    package_href = sdtm_pkgs[1],
    codelists    = lookup_sdtm
  )
}
if (!sdtm_only) {
  cat("Fetching ADaM packages (oldest-first; newer overrides)...\n")
  lookup_adam <- list()
  for (pkg in rev(adam_pkgs)) {
    this <- fetch_package_codelists(pkg, paste("ADaM", basename(pkg)))
    for (k in names(this)) lookup_adam[[k]] <- this[[k]]
  }
  pkgs_map[["adam"]] <- list(
    file         = "adam-ct.json",
    label        = "CDISC ADaM Controlled Terminology",
    package_href = adam_pkgs[1],
    codelists    = lookup_adam
  )
}

# --- Flag deprecated codelists (present in older pkg, absent in newest) -----
# Populates deprecated_in and superseded_by on legacy codelist entries so
# consumers that reference an older codelist submission value (e.g. "RACE"
# renamed to "RACEC" in sdtmct-2026-03-27) can warn instead of silently
# failing lookups.
#
# Successor detection strategy (in order):
#   1. Hand-curated override in ct/codelist-renames.json (highest priority)
#   2. Same codelist concept ID in the latest package (simple version bump)
#   3. New codelist name starts with old name (RACE -> "Race As Collected")
# If none match, superseded_by stays NA_character_.

load_rename_overrides <- function(ct_dir, pkg_key) {
  path <- file.path(ct_dir, "codelist-renames.json")
  if (!file.exists(path)) return(list())
  ov <- tryCatch(
    jsonlite::read_json(path, simplifyVector = FALSE),
    error = function(e) list()
  )
  ov[[pkg_key]] %||% list()
}

mark_deprecations <- function(pkgs, latest_href, pkg_key = NULL) {
  if (is.null(pkgs) || !length(pkgs)) return(list())
  latest_pkg <- basename(latest_href %||% "")
  if (!nzchar(latest_pkg)) return(pkgs)
  # We detect supersession by name similarity: when a renamed codelist is
  # present in the newest package but its OLD name isn't, mark the old one.
  current_names <- names(pkgs)
  # Refetch just the latest package to know which codelists are "current".
  safe <- gsub("[^A-Za-z0-9]+", "_", latest_href)
  latest <- tryCatch(
    jsonlite::read_json(file.path(cache_dir, paste0(safe, ".json")),
                        simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(latest)) return(pkgs)
  latest_subs <- vapply(latest$codelists %||% list(),
                        function(cl) cl$submissionValue %||% "",
                        character(1))
  overrides <- load_rename_overrides(ct_dir, pkg_key %||% "")
  for (nm in current_names) {
    if (!(nm %in% latest_subs)) {
      old_code <- pkgs[[nm]]$codelist_code
      old_name <- pkgs[[nm]]$codelist_name %||% ""
      successor <- NA_character_

      # 1. Hand-curated override wins (null value is kept as NA).
      if (nm %in% names(overrides)) {
        ov <- overrides[[nm]]
        successor <- if (is.null(ov)) NA_character_ else as.character(ov)
      } else {
        for (cl in latest$codelists %||% list()) {
          # 2. Same codelist concept ID (simple version bump)
          if (!is.null(old_code) &&
              (identical(cl$conceptId, old_code) ||
               identical(sub(".*/", "", cl$`_links`$self$href %||% ""),
                         old_code))) {
            successor <- cl$submissionValue %||% NA_character_
            break
          }
          # 3. New codelist name starts with old (RACE -> Race As Collected)
          if (nzchar(old_name) &&
              startsWith(tolower(cl$name %||% ""), tolower(old_name))) {
            successor <- cl$submissionValue %||% NA_character_
            break
          }
        }
      }
      pkgs[[nm]][["deprecated_in"]]  <- latest_pkg
      pkgs[[nm]][["superseded_by"]]  <- successor
    }
  }
  pkgs
}

# --- Write outputs and manifest ---------------------------------------------

ct_versions <- list()

for (key in names(pkgs_map)) {
  pk <- pkgs_map[[key]]
  pk$codelists <- mark_deprecations(pk$codelists, pk$package_href, pkg_key = key)
  output_path <- file.path(ct_dir, pk$file)
  n_depr <- sum(vapply(pk$codelists,
                       function(x) !is.null(x[["deprecated_in"]]),
                       logical(1)))
  n_ext  <- sum(vapply(pk$codelists,
                       function(x) isTRUE(x$extensible), logical(1)))
  n_terms <- sum(vapply(pk$codelists,
                        function(x) length(x$terms), integer(1)))
  jsonlite::write_json(
    pk$codelists, output_path,
    auto_unbox = TRUE, null = "null", na = "null", pretty = TRUE
  )
  cat(sprintf(
    "Wrote %s (%d codelists, %d terms, %d extensible, %d deprecated)\n",
    pk$file, length(pk$codelists), n_terms, n_ext, n_depr
  ))
  ct_versions[[key]] <- list(
    name            = pk$label,
    effective       = basename(pk$package_href),
    n_codelists     = length(pk$codelists),
    n_terms         = n_terms,
    n_extensible    = n_ext,
    n_deprecated    = n_depr
  )
}

manifest <- list(
  schema_version = 2L,
  terms_format   = "object",
  version        = format(Sys.Date(), "%Y-%m-%d"),
  source         = "CDISC Library CT packages (library.cdisc.org)",
  fetched        = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  packages       = ct_versions
)
manifest_path <- file.path(ct_dir, "ct-manifest.json")
jsonlite::write_json(
  manifest, manifest_path,
  auto_unbox = TRUE, null = "null", pretty = TRUE
)
cat(sprintf("Wrote ct-manifest.json (version: %s)\n\n", manifest$version))

# --- Spot-check a few well-known codelists ----------------------------------

cat("Spot-checks:\n")
sdtm_json_path <- file.path(ct_dir, "sdtm-ct.json")
if (file.exists(sdtm_json_path)) {
  j <- jsonlite::read_json(sdtm_json_path, simplifyVector = FALSE)
  for (k in c("NY", "SEX", "RACE", "ETHNIC", "AESEV", "AGEU")) {
    if (!is.null(j[[k]])) {
      first <- j[[k]]$terms[[1]]
      cat(sprintf(
        "  %-8s %s (%d terms) e.g. %s=%s [%s]%s\n",
        k,
        j[[k]]$codelist_code,
        length(j[[k]]$terms),
        first$submissionValue, first$conceptId, first$preferredTerm,
        if (!is.null(j[[k]][["deprecated_in"]]))
          sprintf(" DEPRECATED->%s", j[[k]][["superseded_by"]] %||% "?")
        else ""
      ))
    }
  }
}

cat("\nDone.\n")
