# State-i i background-it: background_state.json.

default_bg_state <- function() {
  list(
    active_mode = "image",
    version     = 0L,
    modes = list(
      none  = list(),
      color = list(value = "#0b1c24"),
      image = list(
        active_scope = "custom",
        blur = list(on = TRUE, amount = 10L),
        scopes = list(
          custom = list(per_tab = setNames(list(), character())),
          global = list(global = NULL)
        )
      )
    )
  )
}

normalize_per_tab <- function(x) {
  if (is.null(x)) return(setNames(list(), character()))
  if (!is.list(x)) return(setNames(list(), character()))
  if (length(x) == 0 && is.null(names(x))) return(setNames(list(), character()))
  x
}

migrate_bg_state_if_needed <- function(st) {
  if (!is.null(st$mode) && is.null(st$active_mode)) {
    d <- default_bg_state()

    active_mode <- st$mode %||% d$active_mode
    if (!active_mode %in% c("image","color","none")) active_mode <- "image"

    d$active_mode <- active_mode
    d$version     <- as.integer(st$version %||% d$version)
    d$modes$color$value <- st$color %||% d$modes$color$value
    d$modes$image$active_scope <- st$scope %||% d$modes$image$active_scope
    if (!d$modes$image$active_scope %in% c("custom","global")) d$modes$image$active_scope <- "custom"

    d$modes$image$blur$on     <- isTRUE(st$blur_on %||% d$modes$image$blur$on)
    d$modes$image$blur$amount <- as.integer(st$blur %||% d$modes$image$blur$amount)

    d$modes$image$scopes$global$global <- st$global %||% NULL
    d$modes$image$scopes$custom$per_tab <- normalize_per_tab(st$per_tab)

    return(d)
  }

  st
}

read_bg_state <- function(path = BG_STATE_FILE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Mungon paketa 'jsonlite'. Instalo: install.packages('jsonlite')")
  }

  d <- default_bg_state()
  if (!file.exists(path)) return(d)

  raw <- tryCatch(
    paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
    error = function(e) ""
  )
  if (!nzchar(trimws(raw))) return(d)

  st <- tryCatch(
    jsonlite::fromJSON(raw),
    error = function(e) {
      ts <- format(Sys.time(), "%Y%m%d_%H%M%S")
      bak <- paste0(path, ".", ts, ".bak")
      try(file.copy(path, bak, overwrite = TRUE), silent = TRUE)
      try(file.remove(path), silent = TRUE)
      d
    }
  )

  if (is.null(st) || !is.list(st)) return(d)

  st <- tryCatch(
    migrate_bg_state_if_needed(st),
    error = function(e) d
  )

  st$active_mode <- st$active_mode %||% d$active_mode
  if (!st$active_mode %in% c("image","color","none")) st$active_mode <- d$active_mode

  st$version <- as.integer(st$version %||% d$version)

  if (is.null(st$modes) || !is.list(st$modes)) st$modes <- d$modes
  if (is.null(st$modes$none) || !is.list(st$modes$none)) st$modes$none <- d$modes$none
  if (is.null(st$modes$color) || !is.list(st$modes$color)) st$modes$color <- d$modes$color
  st$modes$color$value <- st$modes$color$value %||% d$modes$color$value

  if (is.null(st$modes$image) || !is.list(st$modes$image)) st$modes$image <- d$modes$image
  st$modes$image$active_scope <- st$modes$image$active_scope %||% d$modes$image$active_scope
  if (!st$modes$image$active_scope %in% c("custom","global")) st$modes$image$active_scope <- d$modes$image$active_scope
  if (is.null(st$modes$image$blur) || !is.list(st$modes$image$blur)) st$modes$image$blur <- d$modes$image$blur
  st$modes$image$blur$on     <- isTRUE(st$modes$image$blur$on %||% d$modes$image$blur$on)
  st$modes$image$blur$amount <- as.integer(st$modes$image$blur$amount %||% d$modes$image$blur$amount)
  if (is.null(st$modes$image$scopes) || !is.list(st$modes$image$scopes)) st$modes$image$scopes <- d$modes$image$scopes
  if (is.null(st$modes$image$scopes$custom) || !is.list(st$modes$image$scopes$custom)) st$modes$image$scopes$custom <- d$modes$image$scopes$custom
  if (is.null(st$modes$image$scopes$global) || !is.list(st$modes$image$scopes$global)) st$modes$image$scopes$global <- d$modes$image$scopes$global

  st$modes$image$scopes$custom$per_tab <- normalize_per_tab(st$modes$image$scopes$custom$per_tab)
  st$modes$image$scopes$global$global  <- st$modes$image$scopes$global$global %||% NULL

  st
}

write_bg_state <- function(st, path = BG_STATE_FILE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Mungon paketa 'jsonlite'. Instalo: install.packages('jsonlite')")
  }

  st$version <- as.integer(Sys.time())

  if (!is.null(st$modes$image$scopes$custom$per_tab)) {
    st$modes$image$scopes$custom$per_tab <- normalize_per_tab(st$modes$image$scopes$custom$per_tab)
  }

  jsonlite::write_json(st, path, auto_unbox = TRUE, pretty = TRUE)
}

