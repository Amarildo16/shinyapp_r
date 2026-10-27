# Krijon referencën statistike nga kodi i commit-it 976dce0 (V-07).
#
# Ekzekutohet NJË herë, në Fazën 0, nga rrënja e projektit:
#   Rscript tests/reference/make_reference.R
#
# Nuk mbishkruan një referencë ekzistuese: referenca nuk rigjenerohet për ta bërë
# një test të kalojë (docs/ai/QUALITY.md). Një ndryshim i qëllimshëm rezultati
# kërkon vendim te docs/ai/DECISIONS.md.

REF_COMMIT  <- "976dce0"
LEGACY_CODE <- c("app.R", "helpers.R", "server_plots.R")
OUT_DIR     <- file.path("tests", "reference")

if (!file.exists("app.R") || !dir.exists(OUT_DIR)) {
  stop("Ekzekutoje nga rrënja e projektit (folderi me app.R).")
}

# Kodi duhet të jetë ai i 976dce0, pa ndryshime.
if (!all(file.exists(LEGACY_CODE))) {
  stop("Mungon kodi i vjetër (", paste(LEGACY_CODE, collapse = ", "), "): referenca krijohet vetëm nga ", REF_COMMIT, ".")
}
code_status <- system2("git", c("diff", "--quiet", REF_COMMIT, "--", LEGACY_CODE))
if (!identical(code_status, 0L)) {
  stop("Kodi ndryshon nga ", REF_COMMIT, ": referenca krijohet vetëm nga kodi origjinal.")
}

source(file.path(OUT_DIR, "compute_results.R"), encoding = "UTF-8")

targets <- file.path(OUT_DIR, paste0(names(REFERENCE_DATASETS), ".rds"))
existing <- targets[file.exists(targets)]
if (length(existing) > 0) {
  stop("Referenca ekziston dhe nuk mbishkruhet: ", paste(basename(existing), collapse = ", "))
}

pkgs <- c("shiny", "forecast", "tseries", "zoo", "dplyr", "readr", "plotly", "ggplot2", "stats")
info <- list(
  code_commit = REF_COMMIT,
  head_commit = system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE),
  created_at  = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  r_version   = R.version.string,
  packages    = vapply(pkgs, function(p) as.character(utils::packageVersion(p)), character(1)),
  session     = utils::sessionInfo()
)

for (i in seq_along(REFERENCE_DATASETS)) {
  ds <- REFERENCE_DATASETS[[i]]
  message("Referenca: ", ds$file)
  res <- compute_results(".", ds)
  res$info <- info
  saveRDS(res, targets[i])
  message("  -> ", targets[i])
}

message("Referenca u krijua nga ", REF_COMMIT, " me ", R.version.string, ".")
