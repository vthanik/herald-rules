#!/usr/bin/env Rscript
# =============================================================================
# fetch-ig-variables.R -- Build variable -> codelist mapping from CDISC Library
# =============================================================================
#
# Walks SDTMIG v3.3 + v3.4 datasets and ADaMIG v1.1 + v1.2 datastructures on
# the CDISC Library API, extracts each variable's codelist reference, and
# writes a flat variable-keyed JSON asset. These are the IG versions heraldrules
# ships configs for; add ADaMIG 1.3 here only when a corresponding config is
# added.
#
# Usage:
#   Rscript inst/scripts/fetch-ig-variables.R               # all 4 IGs
#   Rscript inst/scripts/fetch-ig-variables.R --force       # ignore cache
#   Rscript inst/scripts/fetch-ig-variables.R --verbose     # log HTTP calls
#
# Output:
#   ct/variable-to-codelist.json
#     {
#       "SEX":    { "codelist": "SEX",    "code": "C66731",
#                    "igs": ["SDTMIG 3.3", "SDTMIG 3.4", "ADaMIG 1.2"] },
#       "AESEV":  { "codelist": "AESEV",  "code": "C66769",
#                    "igs": ["SDTMIG 3.3", "SDTMIG 3.4"] },
#       "STUDYID":{ "codelist": null,     "code": null,
#                    "igs": ["SDTMIG 3.3", ...] }
#     }
#
# Requirements:
#   - CDISC_API_KEY in env or .local/.env
#   - jsonlite
#   - Expects ct/sdtm-ct.json and ct/adam-ct.json to exist (built by fetch-ct.R)
#     for reverse C-code -> submissionValue lookup. Run fetch-ct.R first.
#
# =============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

args    <- commandArgs(trailingOnly = TRUE)
force   <- "--force"   %in% args
verbose <- "--verbose" %in% args

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
out_file  <- file.path(ct_dir, "variable-to-codelist.json")
dir.create(ct_dir,    recursive = TRUE, showWarnings = FALSE)
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

cat("=== Herald IG Variable -> Codelist Fetch ===\n\n")

# --- API key ----------------------------------------------------------------

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

# --- HTTP fetch with file cache ---------------------------------------------

fetch_json <- function(path) {
  cache <- file.path(
    cache_dir,
    paste0(gsub("[^A-Za-z0-9]+", "_", path), ".json")
  )
  if (file.exists(cache) && !force) {
    if (verbose) cat(sprintf("  CACHE %s\n", path))
    return(jsonlite::read_json(cache, simplifyVector = FALSE))
  }
  if (verbose) cat(sprintf("  GET   %s\n", path))
  con <- url(
    paste0(BASE_URL, path),
    headers = c("api-key" = API_KEY, "Accept" = "application/json")
  )
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  txt <- paste(readLines(con, warn = FALSE), collapse = "\n")
  data <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
  writeLines(jsonlite::toJSON(data, auto_unbox = TRUE), cache)
  data
}

# --- Reverse lookup: NCI C-code -> submission value -------------------------

load_ct_reverse_lookup <- function() {
  rev <- list()
  for (fn in c("sdtm-ct.json", "adam-ct.json")) {
    fpath <- file.path(ct_dir, fn)
    if (!file.exists(fpath)) {
      cat(sprintf("  WARN: %s missing -- run fetch-ct.R first\n", fn))
      next
    }
    j <- jsonlite::read_json(fpath, simplifyVector = FALSE)
    for (short in names(j)) {
      code <- j[[short]]$codelist_code
      if (!is.null(code) && nzchar(code) && is.null(rev[[code]])) {
        rev[[code]] <- short
      }
    }
  }
  rev
}

CT_REV <- load_ct_reverse_lookup()
cat(sprintf("Reverse lookup loaded: %d NCI codes -> submission values\n\n",
            length(CT_REV)))

# --- Variable codelist extractor --------------------------------------------

codelist_from_variable <- function(v) {
  links <- v[["_links"]]
  if (is.null(links)) return(list(id = NA_character_, code = NA_character_))
  cl_refs <- links[["codelist"]]
  if (is.null(cl_refs) || length(cl_refs) == 0) {
    return(list(id = NA_character_, code = NA_character_))
  }
  first <- if (is.list(cl_refs) && !is.null(cl_refs$href)) cl_refs else cl_refs[[1]]
  href <- first$href %||% NA_character_
  if (is.na(href) || !nzchar(href)) {
    return(list(id = NA_character_, code = NA_character_))
  }
  code <- sub(".*/", "", href)
  short <- CT_REV[[code]] %||% NA_character_
  list(id = short, code = code)
}

# --- Variable extraction from a dataset/datastructure payload ---------------

extract_variables <- function(ds_json, ig_name, ds_title = NA_character_) {
  vars <- ds_json$datasetVariables %||% ds_json$variables %||% list()
  if (length(vars) == 0 && !is.null(ds_json$analysisVariableSets)) {
    flat <- list()
    for (avs in ds_json$analysisVariableSets) {
      flat <- c(flat, avs$analysisVariables %||% list())
    }
    vars <- flat
  }
  out <- list()
  for (v in vars) {
    name <- v$name %||% v$variableName %||% NULL
    if (is.null(name) || !nzchar(name)) next
    cl <- codelist_from_variable(v)
    out[[length(out) + 1L]] <- list(
      name     = toupper(name),
      label    = v$label %||% v$description %||% NA_character_,
      codelist = cl$id,
      code     = cl$code,
      ig       = ig_name,
      dataset  = ds_title,
      core     = v$core %||% NA_character_
    )
  }
  out
}

# --- Walk an SDTMIG version -------------------------------------------------

walk_sdtmig <- function(version_slug, ig_name) {
  cat(sprintf("  %s: listing datasets...\n", ig_name))
  idx <- tryCatch(
    fetch_json(sprintf("/mdr/sdtmig/%s/datasets", version_slug)),
    error = function(e) { cat(sprintf("    ERROR: %s\n", conditionMessage(e))); NULL }
  )
  if (is.null(idx)) return(list())
  datasets <- idx[["_links"]][["datasets"]] %||% idx$datasets %||% list()
  collected <- list()
  for (d in datasets) {
    href  <- d$href %||% NULL
    title <- d$title %||% sub(".*/", "", href %||% "?")
    if (is.null(href)) next
    ds <- tryCatch(fetch_json(href), error = function(e) {
      cat(sprintf("    skip %s: %s\n", title, conditionMessage(e))); NULL
    })
    if (is.null(ds)) next
    vars <- extract_variables(ds, ig_name, ds_title = title)
    if (verbose) cat(sprintf("    %-6s %3d variables\n", title, length(vars)))
    collected <- c(collected, vars)
  }
  cat(sprintf("    %s: %d variables collected\n", ig_name, length(collected)))
  collected
}

# --- Walk an ADaMIG version -------------------------------------------------

walk_adamig <- function(version_slug, ig_name) {
  cat(sprintf("  %s: listing datastructures...\n", ig_name))
  idx <- tryCatch(
    fetch_json(sprintf("/mdr/adam/%s/datastructures", version_slug)),
    error = function(e) { cat(sprintf("    ERROR: %s\n", conditionMessage(e))); NULL }
  )
  if (is.null(idx)) return(list())
  structures <- idx[["_links"]][["dataStructures"]] %||%
                idx[["_links"]][["datastructures"]] %||%
                idx$dataStructures %||%
                idx$datastructures %||% list()
  collected <- list()
  for (s in structures) {
    href  <- s$href %||% NULL
    title <- s$title %||% sub(".*/", "", href %||% "?")
    if (is.null(href)) next
    ds <- tryCatch(fetch_json(href), error = function(e) {
      cat(sprintf("    skip %s: %s\n", title, conditionMessage(e))); NULL
    })
    if (is.null(ds)) next
    vars <- extract_variables(ds, ig_name, ds_title = title)
    if (verbose) cat(sprintf("    %-8s %3d variables\n", title, length(vars)))
    collected <- c(collected, vars)
  }
  cat(sprintf("    %s: %d variables collected\n", ig_name, length(collected)))
  collected
}

# --- Main walk --------------------------------------------------------------

all_vars <- list()
all_vars <- c(all_vars, walk_sdtmig("3-3",        "SDTMIG 3.3"))
all_vars <- c(all_vars, walk_sdtmig("3-4",        "SDTMIG 3.4"))
all_vars <- c(all_vars, walk_adamig("adamig-1-1", "ADaMIG 1.1"))
all_vars <- c(all_vars, walk_adamig("adamig-1-2", "ADaMIG 1.2"))

cat(sprintf("\nTotal variable-entries: %d (across IGs)\n", length(all_vars)))

# --- Merge by variable name -------------------------------------------------

var_map <- list()

for (v in all_vars) {
  nm  <- v$name
  cl  <- if (is.null(v$codelist) || is.na(v$codelist) || !nzchar(v$codelist)) {
    NA_character_
  } else v$codelist
  code <- if (is.null(v$code) || is.na(v$code) || !nzchar(v$code)) {
    NA_character_
  } else v$code
  core_key <- paste(v$ig, v$dataset %||% "")
  existing <- var_map[[nm]]
  core_val <- if (is.null(v$core) || is.na(v$core) || !nzchar(v$core)) {
    NA_character_
  } else v$core
  if (is.null(existing)) {
    core_map <- list()
    if (!is.na(core_val)) core_map[[core_key]] <- core_val
    var_map[[nm]] <- list(
      codelist = cl,
      code     = code,
      label    = v$label,
      igs      = list(v$ig),
      core     = core_map
    )
  } else {
    if (is.na(existing$codelist) && !is.na(cl)) {
      existing$codelist <- cl
      existing$code     <- code
    }
    existing$igs <- c(existing$igs, list(v$ig))
    if (!is.na(core_val)) existing$core[[core_key]] <- core_val
    var_map[[nm]] <- existing
  }
}

# Collapse duplicate IGs and sort
for (nm in names(var_map)) {
  igs <- unique(unlist(var_map[[nm]]$igs))
  var_map[[nm]]$igs <- as.list(sort(igs))
}

# --- Stats ------------------------------------------------------------------

n_total     <- length(var_map)
n_with_cl   <- sum(vapply(var_map,
                          function(x) !is.na(x$codelist), logical(1)))
n_no_cl     <- n_total - n_with_cl

cat(sprintf(
  "\nUnique variables: %d  (%d with codelist, %d without)\n",
  n_total, n_with_cl, n_no_cl
))

# --- Write output -----------------------------------------------------------

# Wrap with schema header and metadata
output <- list(
  `_schema_version` = 1L,
  `_source`         = "CDISC Library (SDTMIG 3.3/3.4 + ADaMIG 1.1/1.2)",
  `_fetched`        = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  `_igs`            = c("SDTMIG 3.3", "SDTMIG 3.4",
                        "ADaMIG 1.1", "ADaMIG 1.2"),
  variables         = var_map
)

jsonlite::write_json(
  output, out_file,
  auto_unbox = TRUE, null = "null", na = "null", pretty = TRUE
)

cat(sprintf("Wrote %s\n", out_file))

# --- Spot-checks ------------------------------------------------------------

cat("\nSpot-checks:\n")
for (nm in c("SEX", "AESEV", "STUDYID", "RACE", "AGE", "DTHDTC")) {
  if (!is.null(var_map[[nm]])) {
    ent <- var_map[[nm]]
    cat(sprintf("  %-8s codelist=%s code=%s (%d IGs)\n",
                nm,
                ent$codelist %||% "NULL",
                ent$code %||% "NULL",
                length(ent$igs)))
  } else {
    cat(sprintf("  %-8s (not found)\n", nm))
  }
}

cat("\nDone.\n")
