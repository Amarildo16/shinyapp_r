# Ndihmës të vegjël të përgjithshëm.

`%||%` <- function(a, b) {
  if (is.null(a)) return(b)
  if (length(a) == 0) return(b)

  if (is.character(a) && length(a) == 1) {
    if (!nzchar(a) || is.na(a)) return(b)
  }
  a
}

