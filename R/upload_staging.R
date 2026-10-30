# Pritja e ngarkimeve të FilePond-it (V-29, V-33): skedarët mbërrijnë drejt e te adresa e
# sesionit (session$registerDataObj) dhe presin te stg$dir (tempdir) derisa përdoruesi t'i
# ruajë. Fotot: media_library.R; CSV-ja: csv_stage_add() këtu poshtë.

stage_new <- function(dir = tempfile("staging_")) {
  stg <- new.env(parent = emptyenv())
  stg$dir <- dir
  stg$files <- list()
  stg$n <- 0L
  stg
}

# read_chunk() kthen raw() bosh kur mbaron trupi i kërkesës. Kthen list(ok, id, path, size);
# skedari mbi kufirin hiqet dhe kthen ok = FALSE.
stage_write <- function(stg, read_chunk, ext, max_bytes) {
  if (!dir.exists(stg$dir)) dir.create(stg$dir, recursive = TRUE)
  stg$n <- stg$n + 1L
  id <- sprintf("f%04d", stg$n)
  path <- file.path(stg$dir, paste0(id, ".", ext))

  con <- file(path, "wb")
  size <- 0
  too_big <- FALSE
  repeat {
    buf <- read_chunk()
    if (!length(buf)) break
    size <- size + length(buf)
    if (size > max_bytes) { too_big <- TRUE; break }
    writeBin(buf, con)
  }
  close(con)
  if (too_big) {
    unlink(path)
    return(list(ok = FALSE))
  }
  list(ok = TRUE, id = id, path = path, size = size)
}

stage_remove <- function(stg, id) {
  if (!is.character(id) || length(id) != 1 || is.null(stg$files[[id]])) return(FALSE)
  unlink(stg$files[[id]]$path)
  stg$files[[id]] <- NULL
  TRUE
}

stage_discard <- function(stg) {
  for (f in stg$files) unlink(f$path)
  stg$files <- list()
  invisible(TRUE)
}

# CSV-ja pret vetëm derisa përdoruesi të shtypë "Ruaj" te konfigurimi (V-33).
csv_stage_add <- function(stg, read_chunk, name, max_bytes = UPLOAD_MAX_MB * 1024^2) {
  name <- basename(name %||% "")
  if (tolower(tools::file_ext(name)) != "csv") return(list(ok = FALSE, msg = tr("ds.only_csv")))

  w <- stage_write(stg, read_chunk, "csv", max_bytes)
  if (!isTRUE(w$ok)) return(list(ok = FALSE, msg = tr("pond.too_large")))

  stg$files[[w$id]] <- list(path = w$path, name = name, size = w$size)
  list(ok = TRUE, id = w$id)
}

# Filtri i registerDataObj: X-Pond-Op "process" (trupi = skedari) ose "revert" (trupi = id).
# add(read_chunk, name, mime) kthen list(ok, id | msg). Një skedar i refuzuar kthehet me 200
# dhe X-Pond-Status "error" (mesazhi në trup): me një status 4xx browser-i e shkruan si gabim
# te console, edhe pse është përgjigje e pritur.
pond_handler <- function(stg, add) {
  text <- function(status, body, error = FALSE) {
    httpResponse(status, "text/plain; charset=UTF-8", enc2utf8(body),
                 headers = list(`X-Pond-Status` = if (error) "error" else "ok"))
  }
  function(data, req) {
    if (!identical(req$REQUEST_METHOD, "POST")) return(text(405L, "POST", TRUE))
    op <- req$HTTP_X_POND_OP %||% ""
    if (identical(op, "process")) {
      r <- add(function() req$rook.input$read(2^20),
               utils::URLdecode(req$HTTP_X_FILE_NAME %||% ""), req$HTTP_X_FILE_TYPE)
      return(if (isTRUE(r$ok)) text(200L, r$id) else text(200L, r$msg, TRUE))
    }
    if (identical(op, "revert")) {
      stage_remove(stg, trimws(rawToChar(req$rook.input$read())))   # id e panjohur: s'ka çfarë të hiqet
      return(text(200L, "ok"))
    }
    text(400L, "op", TRUE)
  }
}
