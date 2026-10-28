# Llogaritjet e Përmbledhjes dhe të EDA-s: funksione të pastra, pa Shiny.
# Të njëjtat hapa si render-at e server_plots.R (976dce0); Q30 i krahason me referencën.

# Statistikat përmbledhëse për çdo seri (vlerat numerike, para formatimit).
summary_stats <- function(d, vc) {
  safe_stat <- function(x, fun) {
    x <- x[!is.na(x)]
    if (length(x) == 0) return(NA_real_)
    fun(x)
  }

  safe_sd <- function(x) {
    x <- x[!is.na(x)]
    if (length(x) < 2) return(NA_real_)
    stats::sd(x)
  }

  data.frame(
    variable    = vc,
    mean        = vapply(vc, function(v) safe_stat(d[[v]], base::mean), numeric(1)),
    sd          = vapply(vc, function(v) safe_sd(d[[v]]), numeric(1)),
    min         = vapply(vc, function(v) safe_stat(d[[v]], base::min), numeric(1)),
    max         = vapply(vc, function(v) safe_stat(d[[v]], base::max), numeric(1)),
    n           = vapply(vc, function(v) sum(!is.na(d[[v]])), integer(1)),
    missing_pct = vapply(vc, function(v) round(100 * mean(is.na(d[[v]])), 2), numeric(1)),
    row.names   = NULL,
    stringsAsFactors = FALSE
  )
}

# Mesatarja lëvizëse e djathtë me dritare k. k përshtatet në [2, n_jo-NA − 1].
# ok = FALSE kur seria ka < 3 vlera reale.
rolling_mean <- function(d, series, k) {
  n_non_na <- sum(!is.na(d[[series]]))

  k <- as.integer(k)
  if (length(k) != 1 || is.na(k)) k <- 5L
  k <- max(2L, k)

  if (n_non_na < 3) return(list(ok = FALSE, n_non_na = n_non_na))

  k_max <- max(2L, n_non_na - 1L)
  k_adjusted <- k > k_max
  if (k_adjusted) k <- k_max

  d <- d[order(d$Time), , drop = FALSE]
  d$roll_mean <- zoo::rollapply(
    d[[series]],
    width = k,
    FUN = function(z) if (all(is.na(z))) NA_real_ else mean(z, na.rm = TRUE),
    fill = NA,
    align = "right",
    partial = FALSE
  )

  list(ok = TRUE, k = k, k_adjusted = k_adjusted, n_non_na = n_non_na, data = d)
}

# Histograma (densitet) dhe dendësia kernel e shpërndarjes, si geom_histogram(bins = 18)
# + geom_density() i ggplot2 4.0: kolonat qendrohen te minimumi e maksimumi, intervalet
# mbyllen djathtas, dendësia me bw.nrd0 në 512 pika mbi [min, max]. Vlerat NA hiqen.
hist_density <- function(y, bins = 18L) {
  x <- y[is.finite(y)]
  if (length(x) == 0) return(NULL)
  rng <- range(x)

  if (scales::zero_range(rng)) {
    width <- 0.1
    boundary <- width / 2
  } else {
    width <- (rng[2] - rng[1]) / (bins - 1)
    boundary <- rng[1] - width / 2
    if (any(rng %% width == boundary %% width)) width <- (rng[2] - rng[1]) / bins
  }
  origin <- boundary + floor((rng[1] - boundary) / width) * width
  breaks <- seq(origin, rng[2] + (1 - 1e-08) * width, width)
  if (length(breaks) == 1) breaks <- c(breaks, breaks + width)

  fuzz <- 1e-08 * stats::median(diff(breaks))
  if (!is.finite(fuzz)) fuzz <- .Machine$double.eps * 1000
  fuzzy <- breaks + c(-fuzz, rep.int(fuzz, length(breaks) - 1))
  idx <- cut(x, fuzzy, right = TRUE, include.lowest = TRUE)
  count <- as.numeric(tapply(rep(1, length(x)), idx, sum, na.rm = TRUE))
  count[is.na(count)] <- 0
  widths <- diff(breaks)

  bars <- data.frame(
    x       = (breaks[-length(breaks)] + breaks[-1]) / 2,
    width   = widths,
    density = count / widths / sum(abs(count))
  )

  dens <- NULL
  if (length(x) >= 2) {
    k <- stats::density(x, weights = rep(1 / length(x), length(x)), bw = stats::bw.nrd0(x),
                        kernel = "gaussian", n = 512, from = rng[1], to = rng[2])
    dens <- data.frame(x = k$x, density = k$y)
  }
  list(bars = bars, density = dens)
}

# Regresioni linear y ~ x mbi pikat e fundme. reason: "few_points" | "no_x_variation" | "ok".
# line = NULL kur modeli nuk ka koeficientë të fundëm (pikat vizatohen pa vijë).
relation_fit <- function(d, x, y) {
  d$xval <- d[[x]]
  d$yval <- d[[y]]
  d <- d[is.finite(d$xval) & is.finite(d$yval), , drop = FALSE]

  if (nrow(d) <= 1) return(list(ok = FALSE, reason = "few_points", n = nrow(d)))
  if (length(unique(d$xval)) <= 1) return(list(ok = FALSE, reason = "no_x_variation", n = nrow(d)))

  fit <- tryCatch(stats::lm(yval ~ xval, data = d), error = function(e) NULL)

  line <- NULL
  if (!is.null(fit) && all(is.finite(stats::coef(fit)))) {
    xs <- seq(min(d$xval), max(d$xval), length.out = 100)
    line <- data.frame(xval = xs)
    line$yhat <- as.numeric(stats::predict(fit, newdata = line))
  }

  list(ok = TRUE, reason = "ok", n = nrow(d), data = d,
       coef = if (is.null(line)) NULL else stats::coef(fit), line = line)
}

# Korrelacioni Pearson (pairwise) i serive numerike, pa Time.
# Maksimumi 20 kolona (truncated = TRUE); hiqen kolonat me sd = 0.
# reason: "few_cols" | "few_cols_after_sd" | "ok".
correlation_matrix <- function(d) {
  num <- d[, vapply(d, is.numeric, logical(1)) & names(d) != "Time", drop = FALSE]

  if (ncol(num) < 2) return(list(ok = FALSE, reason = "few_cols"))

  truncated <- ncol(num) > 20
  if (truncated) num <- num[, 1:20, drop = FALSE]

  keep <- vapply(num, function(x) {
    s <- stats::sd(x, na.rm = TRUE)
    is.finite(s) && s > 0
  }, logical(1))
  num <- num[, keep, drop = FALSE]

  if (ncol(num) < 2) return(list(ok = FALSE, reason = "few_cols_after_sd", truncated = truncated))

  list(ok = TRUE, reason = "ok", truncated = truncated,
       corr = stats::cor(num, use = "pairwise.complete.obs"))
}
