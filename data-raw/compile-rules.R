## data-raw/compile-rules.R
## Run this script to regenerate the package data objects in data/
## Usage: Rscript data-raw/compile-rules.R
## Must be run from the herald-rules repo root.

root <- if (file.exists("herald-master-rules.csv")) "." else stop(
  "Run from herald-rules repo root", call. = FALSE
)

message("Compiling hr_rules from herald-master-rules.csv ...")
hr_rules <- read.csv(
  file.path(root, "herald-master-rules.csv"),
  stringsAsFactors = FALSE,
  check.names      = FALSE,
  na.strings       = c("", "NA")
)
message(sprintf("  %d rules loaded", nrow(hr_rules)))

message("Compiling hr_configs from configs/*.json ...")
cfg_files <- list.files(file.path(root, "configs"), pattern = "\\.json$",
                        full.names = TRUE)
hr_configs <- lapply(cfg_files, function(f) {
  parsed <- jsonlite::fromJSON(f, simplifyVector = TRUE)
  # Config JSON structure: { "rules": ["ID1", "ID2", ...], ... }
  # Also handle flat arrays
  if (is.character(parsed)) return(parsed)
  if (!is.null(parsed[["rules"]])) return(parsed[["rules"]])
  if (!is.null(parsed[["rule_ids"]])) return(parsed[["rule_ids"]])
  # Flatten any nested list of IDs
  unlist(parsed, use.names = FALSE)
})
names(hr_configs) <- tools::file_path_sans_ext(basename(cfg_files))
message(sprintf("  %d configs loaded: %s",
                length(hr_configs), paste(names(hr_configs), collapse = ", ")))

message("Compiling hr_ct from herald-controlled-terminology.csv ...")
hr_ct <- read.csv(
  file.path(root, "herald-controlled-terminology.csv"),
  stringsAsFactors = FALSE,
  check.names      = FALSE,
  na.strings       = c("", "NA")
)
message(sprintf("  %d CT terms loaded", nrow(hr_ct)))

message("Compiling hr_manifest from manifest.json ...")
hr_manifest <- jsonlite::fromJSON(
  file.path(root, "manifest.json"),
  simplifyVector = TRUE
)
message("  manifest loaded")

message("Saving data objects (xz compression) ...")
save(hr_rules,    file = "data/hr_rules.rda",    compress = "xz")
save(hr_configs,  file = "data/hr_configs.rda",  compress = "xz")
save(hr_ct,       file = "data/hr_ct.rda",        compress = "xz")
save(hr_manifest, file = "data/hr_manifest.rda",  compress = "xz")

sizes <- vapply(
  list.files("data", full.names = TRUE),
  function(f) file.size(f) / 1024,
  numeric(1L)
)
total_kb <- sum(sizes)
message(sprintf("\nData file sizes:"))
for (nm in names(sizes)) message(sprintf("  %-30s %6.1f KB", basename(nm), sizes[nm]))
message(sprintf("  %-30s %6.1f KB", "TOTAL", total_kb))
if (total_kb > 4096) warning("Total data size exceeds 4 MB — review before CRAN submission")
message("\nDone. Run devtools::document() then devtools::check().")
