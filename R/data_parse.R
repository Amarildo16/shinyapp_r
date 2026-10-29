# Parsimi i kohës dhe i numrave; zbulimi i kolonave.

# allow_index = TRUE (kolona e zgjedhur si kohë): numrat e thjeshtë 1, 2, 3… lexohen si kohë numerike
# (B-19, V-24 b); analizat statistikore e refuzojnë me mesazhin e B-09. Zbulimi i kolonave nuk e përdor.
parse_time_safe <- function(x, allow_index = FALSE) {
  require_time_values <- function(v) {
    if (sum(!is.na(v)) < 2) {
      stop(tr("err.time_min2"))
    }
    v
  }

  if (inherits(x, "Date")) return(require_time_values(x))
  if (inherits(x, "POSIXt")) return(require_time_values(as.Date(x)))
  if (is.numeric(x) || is.integer(x)) {
    xn  <- as.numeric(x)
    xn0 <- xn[!is.na(xn)]

    if (length(xn0) < 2) {
      stop(tr("err.time_min2"))
    }

    if (all(xn0 >= 1500 & xn0 <= 3000) &&
        mean(abs(xn0 - round(xn0)) < 1e-8) >= 0.95) {
      return(round(xn))
    }

    return(xn)
  }

  x0 <- trimws(as.character(x))
  x0[x0 == ""] <- NA_character_
  x_non_na <- x0[!is.na(x0)]

  if (length(x_non_na) < 2) {
    stop(tr("err.time_min2"))
  }

  if (all(grepl("^\\d{4}$", x_non_na))) return(as.numeric(x0))
  if (allow_index && all(grepl("^\\d+$", x_non_na))) return(as.numeric(x0))

  if (all(grepl("^\\d{4}-\\d{2}$", x_non_na))) {
    return(as.Date(paste0(x0, "-01")))
  }

  if (all(grepl("^\\d{4}Q[1-4]$", x_non_na))) {
    yr <- as.integer(substr(x0, 1, 4))
    q  <- as.integer(substr(x0, 6, 6))
    m  <- (q - 1) * 3 + 1
    return(as.Date(sprintf("%04d-%02d-01", yr, m)))
  }

  # Forma e plotë e çdo formati: as.Date() injoron karakteret e tepërta, prandaj
  # pa këtë kontroll "15-03-2021" lexohej me "%Y-%m-%d" si viti 15 (B-13, V-14).
  try_formats <- c(
    "%Y-%m-%d" = "^\\d{4}-\\d{1,2}-\\d{1,2}$",
    "%d/%m/%Y" = "^\\d{1,2}/\\d{1,2}/\\d{4}$",
    "%d-%m-%Y" = "^\\d{1,2}-\\d{1,2}-\\d{4}$",
    "%Y/%m/%d" = "^\\d{4}/\\d{1,2}/\\d{1,2}$",
    "%m/%d/%Y" = "^\\d{1,2}/\\d{1,2}/\\d{4}$"
  )
  ok_rate <- function(v) sum(!is.na(v)) / max(1, sum(!is.na(x0)))

  for (f in names(try_formats)) {
    t <- suppressWarnings(as.Date(x0, format = f))
    t[!grepl(try_formats[[f]], x0)] <- NA
    if (ok_rate(t) >= 0.95) return(t)
  }

  t <- suppressWarnings(as.Date(x0))
  if (ok_rate(t) >= 0.95) return(t)

  stop(tr("err.time_parse"))
}

to_numeric_safe <- function(x) {
  if (is.numeric(x))  return(as.numeric(x))
  if (is.integer(x))  return(as.numeric(x))

  s <- trimws(as.character(x))
  s[s == ""] <- NA_character_

  s <- gsub("^\\((.*)\\)$", "-\\1", s)

  s <- gsub("[^0-9., -]", "", s)

  s <- gsub("\\s+", "", s)

  s <- ifelse(is.na(s), NA_character_,
              paste0(ifelse(grepl("-", s, fixed = TRUE), "-", ""),
                     gsub("-", "", s, fixed = TRUE)))
  s <- ifelse(is.na(s), NA_character_, sub("^--+", "-", s))

  has_comma <- grepl(",", s, fixed = TRUE)
  has_dot   <- grepl("\\.", s)

  both <- has_comma & has_dot

  if (any(both, na.rm = TRUE)) {
    idx <- which(both & !is.na(s))

    for (i in idx) {
      si <- s[i]
      last_comma <- max(unlist(gregexpr(",", si, fixed = TRUE)))
      last_dot   <- max(unlist(gregexpr(".", si, fixed = TRUE)))

      if (last_comma > last_dot) {
        si <- gsub("\\.", "", si)
        si <- sub(",", ".", si, fixed = TRUE)
      } else {
        si <- gsub(",", "", si, fixed = TRUE)
      }
      s[i] <- si
    }
  }

  only_comma <- has_comma & !has_dot
  s[only_comma] <- sub(",", ".", s[only_comma], fixed = TRUE)

  has_multi_dot <- !is.na(s) & lengths(regmatches(s, gregexpr("\\.", s))) > 1
  if (any(has_multi_dot)) {
    idx <- which(has_multi_dot)
    for (i in idx) {
      si <- s[i]
      parts <- strsplit(si, "\\.", fixed = FALSE)[[1]]
      si2 <- paste0(paste(parts[-length(parts)], collapse = ""), ".", parts[length(parts)])
      s[i] <- si2
    }
  }

  suppressWarnings(as.numeric(s))
}

detect_time_candidates <- function(df) {
  nm <- names(df)
  scores <- rep(0, length(nm))

  for (i in seq_along(nm)) {
    col <- df[[i]]
    name_l <- tolower(nm[i])

    if (name_l %in% c("year","date","time","timestamp","period","month","quarter")) scores[i] <- scores[i] + 3
    if (grepl("date|time|year|month|quarter|period", name_l)) scores[i] <- scores[i] + 1

    ok <- tryCatch({
      t <- parse_time_safe(col)
      t0 <- t[!is.na(t)]
      if (length(t0) < 2) return(0)

      uniq_ratio <- length(unique(t0)) / length(t0)
      base_ok <- mean(!is.na(t))

      if (uniq_ratio < 0.85) base_ok <- base_ok - 0.25

      base_ok
    }, error = function(e) 0)


    if (ok >= 0.95) scores[i] <- scores[i] + 5
    else if (ok >= 0.70) scores[i] <- scores[i] + 2
  }

  out <- data.frame(
    col = nm,
    score = scores,
    stringsAsFactors = FALSE
  ) %>%
    arrange(desc(score))

  out
}


# Kolonat që lexohen si numerike në të paktën `threshold` të rreshtave (P-02).
# fallback_all = TRUE: nëse asnjë nuk kalon, kthehen të gjitha kolonat jashtë `exclude`.
detect_numeric_cols <- function(d, exclude = character(0), threshold = 0.70, fallback_all = TRUE) {
  cols <- setdiff(names(d), exclude)

  num_cols <- cols[vapply(d[cols], function(x) {
    xn <- to_numeric_safe(x)
    mean(!is.na(xn)) >= threshold
  }, logical(1))]

  if (fallback_all && length(num_cols) == 0) num_cols <- cols
  num_cols
}
