# Rillogarit rezultatet me kodin aktual dhe i krahason me referencën (V-07, Q30).
#
# Nga rrënja e projektit:
#   Rscript tests/reference/compare_reference.R
# ose në RStudio:
#   source("tests/reference/compare_reference.R")
#
# Tolerancat (docs/ai/QUALITY.md):
#   statistikat deterministe          all.equal(tolerance = 1e-10)
#   forma e modeleve (ARIMA, ETS)     identical()
#   koeficientët, parashikimet,
#   intervalet, saktësia              all.equal(tolerance = 1e-8)

TOL_DETERMINISTIC <- 1e-10
TOL_MODELS        <- 1e-8
REF_DIR           <- file.path("tests", "reference")

if (!file.exists("app.R") || !dir.exists(REF_DIR)) {
  stop("Ekzekutoje nga rrënja e projektit (folderi me app.R).")
}

source(file.path(REF_DIR, "compute_results.R"), encoding = "UTF-8")

compare_section <- function(label, ref, cur, check) {
  keys <- union(names(ref), names(cur))
  fails <- 0L
  for (k in keys) {
    msg <- if (!(k %in% names(ref))) {
      "mungon te referenca"
    } else if (!(k %in% names(cur))) {
      "mungon te rezultati aktual"
    } else {
      check(ref[[k]], cur[[k]])
    }
    ok <- isTRUE(msg)
    if (!ok) fails <- fails + 1L
    cat(sprintf("  [%s] %s$%s\n", if (ok) "OK  " else "FAIL", label, k))
    if (!ok) cat(paste0("         ", utils::head(as.character(msg), 5), collapse = "\n"), "\n")
  }
  fails
}

check_det    <- function(a, b) all.equal(a, b, tolerance = TOL_DETERMINISTIC)
check_values <- function(a, b) all.equal(a, b, tolerance = TOL_MODELS)
check_forms  <- function(a, b) if (identical(a, b)) TRUE else all.equal(a, b, tolerance = 0)

total_fails <- 0L

for (name in names(REFERENCE_DATASETS)) {
  ds <- REFERENCE_DATASETS[[name]]
  ref_file <- file.path(REF_DIR, paste0(name, ".rds"))
  if (!file.exists(ref_file)) stop("Mungon referenca: ", ref_file)

  ref <- readRDS(ref_file)
  cat("\n== ", ds$file, " (referenca nga ", ref$info$code_commit, ", ", ref$info$r_version, ")\n", sep = "")

  cur <- compute_results(".", ds)

  total_fails <- total_fails +
    compare_section("deterministic", ref$deterministic, cur$deterministic, check_det) +
    compare_section("forms",  ref$models$forms,  cur$models$forms,  check_forms) +
    compare_section("values", ref$models$values, cur$models$values, check_values)
}

cat("\n")
if (total_fails > 0L) {
  stop("Krahasimi me referencën DËSHTOI: ", total_fails, " pjesë jashtë tolerancës.")
}
cat("Krahasimi me referencën KALOI: të gjitha pjesët brenda tolerancave.\n")
