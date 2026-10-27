# Ndihmës për Plotly.

plotly_cfg <- function(p) {
  config(p, displayModeBar = FALSE, responsive = TRUE)
}

find_traces <- function(pl, predicate) {
  idx <- integer(0)
  for (i in seq_along(pl$x$data)) {
    tr <- pl$x$data[[i]]
    if (isTRUE(predicate(tr))) idx <- c(idx, i)
  }
  idx
}

set_trace_text <- function(pl, trace_index, text_vec) {
  if (length(trace_index) == 0 || is.na(trace_index)) return(pl)
  pl$x$data[[trace_index]]$text <- text_vec
  pl$x$data[[trace_index]]$hoverinfo <- "text"
  pl
}

skip_trace_hover <- function(pl, idx) {
  if (length(idx) == 0) return(pl)
  for (i in idx) {
    pl$x$data[[i]]$hoverinfo <- "skip"
  }
  pl
}

