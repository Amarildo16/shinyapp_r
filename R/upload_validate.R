# Validimi i ngarkimeve (fotot e background-it).

validate_bg_upload_file <- function(path, filename, mime = NULL, size = NULL, max_bytes = 5 * 1024^2) {
  bad <- function(msg) list(ok = FALSE, ext = NULL, msg = msg)

  if (is.null(path) || length(path) != 1 || is.na(path) || !nzchar(as.character(path)) || !file.exists(path)) {
    return(bad("File-i i ngarkuar s’u gjet."))
  }

  ext <- tolower(tools::file_ext(filename %||% ""))
  allowed_ext <- c("jpg", "jpeg", "png", "webp")
  if (!ext %in% allowed_ext) {
    return(bad("Lejohen vetëm foto JPG, PNG ose WEBP."))
  }

  fsz <- suppressWarnings(as.numeric(size %||% NA_real_))
  if (length(fsz) != 1 || is.na(fsz)) {
    fsz <- suppressWarnings(as.numeric(file.info(path)$size))
  }
  if (length(fsz) != 1 || is.na(fsz) || fsz <= 0) {
    return(bad("Madhësia e file-it nuk u verifikua."))
  }
  if (fsz > max_bytes) {
    return(bad("Foto është shumë e madhe. Limiti është 5 MB."))
  }

  mime <- tolower(trimws(as.character(mime %||% "")))
  generic_mime <- c("", "application/octet-stream", "binary/octet-stream")
  allowed_mime <- switch(
    ext,
    "jpg"  = c("image/jpeg", "image/pjpeg"),
    "jpeg" = c("image/jpeg", "image/pjpeg"),
    "png"  = c("image/png", "image/x-png"),
    "webp" = c("image/webp"),
    character(0)
  )
  if (!mime %in% generic_mime && !mime %in% allowed_mime) {
    return(bad("Tipi MIME i fotos nuk përputhet me formatin e lejuar."))
  }

  hdr <- tryCatch(readBin(path, "raw", n = 12), error = function(e) raw())
  magic_ok <- FALSE
  if (ext %in% c("jpg", "jpeg")) {
    magic_ok <- length(hdr) >= 3 && identical(as.integer(hdr[1:3]), c(255L, 216L, 255L))
  } else if (ext == "png") {
    magic_ok <- length(hdr) >= 8 && identical(as.integer(hdr[1:8]), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
  } else if (ext == "webp") {
    magic_ok <- length(hdr) >= 12 &&
      identical(rawToChar(hdr[1:4]), "RIFF") &&
      identical(rawToChar(hdr[9:12]), "WEBP")
  }

  if (!isTRUE(magic_ok)) {
    return(bad("Përmbajtja e file-it nuk duket si foto e vlefshme."))
  }

  list(ok = TRUE, ext = ext, msg = NULL)
}

