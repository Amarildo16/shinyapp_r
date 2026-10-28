# Etiketat dhe formatimi i numrave e i kohës.

make_label <- function(x) {
  s <- gsub("_", " ", x)
  s <- gsub("\\s+", " ", s)
  trimws(s)
}

build_meta <- function(value_cols) {
  meta <- lapply(value_cols, function(v) list(label = make_label(v), unit = ""))
  names(meta) <- value_cols
  meta
}

var_meta <- function(var, meta = NULL) {
  if (!is.null(meta) && !is.null(meta[[var]])) return(meta[[var]])
  list(label = make_label(var), unit = "")
}

# "Etiketa (njësia)", ose vetëm etiketa kur s'ka njësi.
var_display_label <- function(var, meta = NULL) {
  m <- var_meta(var, meta)
  if (!is.null(m$unit) && nzchar(m$unit)) paste0(m$label, " (", m$unit, ")") else m$label
}

# Shenjat e numrave sipas gjuhës (V-09): shqip 1 234,56 + mijë/mln/mld, anglisht 1,234.56 + K/M/B.
number_style <- function(lang = current_lang()) {
  if (identical(lang, "en")) {
    list(big = ",", dec = ".", suffix = c(bn = "B", mn = "M", k = "K"))
  } else {
    list(big = " ", dec = ",", suffix = c(bn = " mld", mn = " mln", k = " mijë"))
  }
}

fmt_fixed <- function(x, digits = 2) {
  ns <- number_style()
  ifelse(
    is.na(x),
    NA_character_,
    format(
      round(x, digits),
      nsmall = digits,
      big.mark = ns$big,
      decimal.mark = ns$dec,
      scientific = FALSE,
      trim = TRUE
    )
  )
}

fmt_compact <- function(x, digits = 1) {
  ns <- number_style()
  trailing_zeros <- paste0(if (ns$dec == ".") "\\." else ns$dec, "0+$")

  out <- vapply(x, function(v) {
    if (is.na(v)) return(NA_character_)
    av <- abs(v)

    if (av >= 1e9) { val <- v / 1e9; suf <- ns$suffix[["bn"]]
    } else if (av >= 1e6) { val <- v / 1e6; suf <- ns$suffix[["mn"]]
    } else if (av >= 1e3) { val <- v / 1e3; suf <- ns$suffix[["k"]]
    } else { val <- v; suf <- "" }

    s <- format(
      round(val, digits),
      nsmall = digits,
      big.mark = ns$big,
      decimal.mark = ns$dec,
      scientific = FALSE,
      trim = TRUE
    )

    s <- sub(trailing_zeros, "", s)
    paste0(s, suf)
  }, character(1))

  out
}

fmt_by_series <- function(x, for_axis = TRUE) {
  if (all(is.na(x))) return(rep(NA_character_, length(x)))
  rng <- range(x, na.rm = TRUE)
  span <- abs(rng[2] - rng[1])

  if (for_axis) {
    if (max(abs(rng), na.rm = TRUE) >= 1e3) return(fmt_compact(x, digits = 1))
    if (span < 1) return(fmt_fixed(x, digits = 3))
    if (span < 10) return(fmt_fixed(x, digits = 2))
    if (span < 100) return(fmt_fixed(x, digits = 1))
    return(fmt_fixed(x, digits = 0))
  } else {
    if (span < 1) return(fmt_fixed(x, digits = 4))
    if (span < 10) return(fmt_fixed(x, digits = 2))
    return(fmt_fixed(x, digits = 2))
  }
}

fmt_unit <- function(x, var, meta = NULL) {
  m <- var_meta(var, meta)
  u <- m$unit %||% ""
  if (nzchar(u)) paste0(fmt_by_series(x, for_axis = FALSE), " ", u)
  else fmt_by_series(x, for_axis = FALSE)
}

time_axis_label <- function(Time) {
  if (inherits(Time, "Date")) return(tr("time.axis.date"))
  if (is.numeric(Time) && all(Time >= 1500 & Time <= 3000, na.rm = TRUE)) return(tr("time.axis.year"))
  tr("time.axis.other")
}

fmt_time <- function(x) {
  if (inherits(x, "Date")) return(format(x, "%Y-%m-%d"))
  as.character(x)
}


# Formatimi i vlerave të veçanta në tabela (B-01). fmt_by_series() mat hapësirën
# e një serie: për një vlerë të vetme hapësira është 0 dhe dilnin gjithmonë 4 decimale.
# Këtu shkalla është madhësia e vlerës: |x| < 1 -> 4 decimale, përndryshe 2.
fmt_table_value <- function(x) {
  x <- as.numeric(x)
  digits <- ifelse(!is.na(x) & abs(x) < 1, 4L, 2L)
  vapply(seq_along(x), function(i) fmt_fixed(x[i], digits = digits[i]), character(1))
}
