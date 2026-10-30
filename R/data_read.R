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

# E njëjta mënyrë leximi për gjithë skedarin, për pamjen e vogël dhe për numërimin (V-33).
read_delim_text <- function(path, delim = detect_csv_delim(path), ...) {
  readr::read_delim(
    file = path,
    delim = delim,
    show_col_types = FALSE,
    na = c("", "NA", "N/A", "null", "NULL"),
    col_types = readr::cols(.default = readr::col_character()),
    trim_ws = TRUE,
    ...
  )
}

read_data_safe <- function(path, filename = NULL, n_max = Inf) {
  if (!file.exists(path)) {
    stop(tr("err.ds_path_missing", path = normalizePath(path, winslash = "/", mustWork = FALSE)))
  }

  nm <- if (!is.null(filename) && nzchar(filename)) filename else path
  ext <- tolower(tools::file_ext(nm))

  if (ext == "tsv") {
    d <- read_delim_text(path, delim = "\t", n_max = n_max)

  } else if (ext %in% c("xlsx", "xls")) {
    has_readxl <- requireNamespace("readxl", quietly = TRUE)
    if (!has_readxl) stop(tr("err.readxl"))

    d <- readxl::read_excel(path, .name_repair = "unique_quiet", n_max = n_max)
    d <- dplyr::as_tibble(d)
    d <- dplyr::mutate(d, dplyr::across(dplyr::everything(), as.character))

  } else {
    d <- read_delim_text(path, n_max = n_max)
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

# Numri i saktë i rreshtave pa lexuar vlerat: readr ndërton vetëm indeksin (2 000 000 rreshta
# në rreth 0,1 s). gc(): në Windows indeksi e mban skedarin hapur derisa të lirohet.
count_csv_rows <- function(path) {
  d <- read_delim_text(path, lazy = TRUE)
  n <- nrow(d)
  rm(d)
  gc(verbose = FALSE)
  n
}

# "albania_agriculture_1998-2024.csv" -> "Albania Agriculture 1998 2024".
csv_title <- function(name) {
  s <- make_label(gsub("[-.]+", "_", tools::file_path_sans_ext(enc2utf8(name))))
  gsub("(^| )(\\p{L})", "\\1\\U\\2", s, perl = TRUE)
}

# Pamja e vogël pas ngarkimit (V-33): lexon vetëm fillimin, ndaj del menjëherë edhe me 2
# milionë rreshta. Një skedar pa rreshta jep të njëjtin gabim si leximi i plotë.
csv_glance <- function(path, filename) {
  d <- read_data_safe(path, filename, n_max = PREVIEW_ROWS)
  list(title = csv_title(filename), rows = count_csv_rows(path), cols = ncol(d),
       size = file.size(path), head = d[seq_len(min(ncol(d), PREVIEW_COLS))])
}
