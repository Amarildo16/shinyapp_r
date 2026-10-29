# Leximi i dataset-eve (CSV/TSV/Excel).

detect_csv_delim <- function(path) {
  lines <- readLines(path, n = 50, warn = FALSE, encoding = "UTF-8")
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) == 0) return(",")

  lines <- lines[1:min(10, length(lines))]

  cands <- c(";", ",", "\t")

  score_one <- function(d) {
    lens <- vapply(strsplit(lines, d, fixed = TRUE), length, integer(1))

    if (max(lens) <= 1) return(-Inf)

    med <- stats::median(lens)
    sdv <- stats::sd(lens)

    penalty <- 0
    if (is.finite(med) && med > 80) penalty <- (med - 80) * 0.25

    (med - sdv) - penalty
  }

  scores <- vapply(cands, score_one, numeric(1))

  if (!any(is.finite(scores))) return(",")
  cands[which.max(scores)]
}

read_data_safe <- function(path, filename = NULL) {
  if (!file.exists(path)) {
    stop(tr("err.ds_path_missing", path = normalizePath(path, winslash = "/", mustWork = FALSE)))
  }

  nm <- if (!is.null(filename) && nzchar(filename)) filename else path
  ext <- tolower(tools::file_ext(nm))

  char_cols <- readr::cols(.default = readr::col_character())

  if (ext == "csv") {
    delim <- detect_csv_delim(path)

    d <- readr::read_delim(
      file = path,
      delim = delim,
      show_col_types = FALSE,
      na = c("", "NA", "N/A", "null", "NULL"),
      col_types = char_cols,
      trim_ws = TRUE
    )

  } else if (ext == "tsv") {
    d <- readr::read_tsv(
      file = path,
      show_col_types = FALSE,
      na = c("", "NA", "N/A", "null", "NULL"),
      col_types = char_cols,
      trim_ws = TRUE
    )

  } else if (ext %in% c("xlsx", "xls")) {
    has_readxl <- requireNamespace("readxl", quietly = TRUE)
    if (!has_readxl) stop(tr("err.readxl"))

    d <- readxl::read_excel(path, .name_repair = "unique_quiet")
    d <- dplyr::as_tibble(d)
    d <- dplyr::mutate(d, dplyr::across(dplyr::everything(), as.character))

  } else {
    delim <- detect_csv_delim(path)

    d <- readr::read_delim(
      file = path,
      delim = delim,
      show_col_types = FALSE,
      na = c("", "NA", "N/A", "null", "NULL"),
      col_types = char_cols,
      trim_ws = TRUE
    )
  }

  d <- as.data.frame(d, stringsAsFactors = FALSE)

  if (nrow(d) == 0) {
    stop(tr("err.ds_empty"))
  }

  if (ncol(d) == 0 || length(names(d)) == 0 || all(!nzchar(trimws(names(d))))) {
    stop(tr("err.ds_no_cols"))
  }

  d
}

