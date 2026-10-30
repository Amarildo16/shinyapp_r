# Media Library e background-it (Faza 6): fotot default vijnë me kodin (www/images/,
# "images/..."), fotot e ngarkuara jetojnë te storage/images/ ("user-images/...").
# V-22: defaultet nuk fshihen; fotot e vjetra te www/images/ kopjohen te
# storage/images/ dhe origjinalet mbeten aty, jashtë galerisë.

BG_IMAGE_PATTERN     <- "\\.(png|jpe?g|webp|gif|svg)$"
BG_UPLOAD_MAX_BYTES  <- 5 * 1024^2

# recycle0: pa foto, asnjë rresht (B-31); paste0() do të jepte "user-images/".
bg_user_src <- function(name) paste0(USER_IMAGES_PREFIX, "/", name, recycle0 = TRUE)

bg_is_default <- function(src) {
  is.character(src) && length(src) == 1 && !is.na(src) &&
    identical(src, paste0("images/", basename(src))) && basename(src) %in% DEFAULT_BG_IMAGES
}

# Fotot e galerisë: defaultet që ekzistojnë dhe fotot e ngarkuara, sipas emrit (si më parë).
bg_image_list <- function(default_dir = BG_DEFAULT_DIR, user_dir = IMAGES_DIR) {
  defaults <- DEFAULT_BG_IMAGES[file.exists(file.path(default_dir, DEFAULT_BG_IMAGES))]
  user <- if (dir.exists(user_dir)) list.files(user_dir, pattern = BG_IMAGE_PATTERN, ignore.case = TRUE) else character(0)
  src <- c(paste0("images/", defaults), bg_user_src(user))
  src[order(basename(src))]
}

# Shtegu në disk i një fote të ngarkuar; defaultet dhe çdo shteg tjetër refuzohen.
resolve_user_image_path <- function(src, user_dir = IMAGES_DIR) {
  bad <- function(msg) list(ok = FALSE, src = NULL, path = NULL, msg = msg)

  if (is.null(src) || length(src) != 1 || is.na(src) || !nzchar(as.character(src))) {
    return(bad(tr("bg.err_path")))
  }
  src <- gsub("\\\\", "/", as.character(src))
  if (bg_is_default(src)) return(bad(tr("bg.err_default")))

  prefix <- paste0(USER_IMAGES_PREFIX, "/")
  if (!startsWith(src, prefix)) return(bad(tr("bg.err_outside")))

  path <- normalize_app_path(file.path(user_dir, substring(src, nchar(prefix) + 1)))
  if (!is_path_inside_dir(path, normalize_app_path(user_dir))) return(bad(tr("bg.err_outside")))

  list(ok = TRUE, src = src, path = path, msg = NULL)
}

# Fotot që përdor state-i i ruajtur (globale ose për faqe): nuk fshihen.
bg_images_in_use <- function(st) {
  g  <- st$modes$image$scopes$global$global %||% ""
  pt <- st$modes$image$scopes$custom$per_tab %||% list()
  x  <- c(g, if (is.list(pt)) unlist(pt, use.names = FALSE))
  unique(x[!is.na(x) & nzchar(x)])
}

bg_safe_name <- function(x) {
  x <- gsub("[^A-Za-z0-9_-]+", "_", x)
  gsub("^_+|_+$", "", x)
}

# Ruan një foto të ngarkuar te dest_dir pas validimit (R19). Emri pastrohet; kur
# ekziston, merr datën dhe një numër. Kthen list(ok, msg, src); msg = NULL kur kopjimi dështon.
# Mesazhi i validimit i paraprihet nga emri i file-it (si më parë), ai i shtegut jo.
bg_store_upload <- function(datapath, name, mime = NULL, size = NULL, dest_dir = IMAGES_DIR) {
  chk <- validate_bg_upload_file(path = datapath, filename = name, mime = mime, size = size,
                                 max_bytes = BG_UPLOAD_MAX_BYTES)
  if (!isTRUE(chk$ok)) return(list(ok = FALSE, msg = paste0(basename(name), ": ", chk$msg), src = NULL))

  if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE)
  base <- bg_safe_name(tools::file_path_sans_ext(name))
  if (is.na(base) || !nzchar(base)) base <- paste0("img_", format(Sys.time(), "%Y%m%d_%H%M%S"))

  out_name <- paste0(base, ".", chk$ext)
  suffix <- 0L
  while (file.exists(file.path(dest_dir, out_name))) {
    suffix <- suffix + 1L
    out_name <- paste0(base, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", suffix, ".", chk$ext)
  }

  out_abs <- normalize_app_path(file.path(dest_dir, out_name))
  if (!is_path_inside_dir(out_abs, normalize_app_path(dest_dir))) {
    return(list(ok = FALSE, msg = tr("bg.err_name"), src = NULL))
  }
  if (!isTRUE(file.copy(datapath, out_abs, overwrite = FALSE))) {
    return(list(ok = FALSE, msg = NULL, src = NULL))
  }
  list(ok = TRUE, msg = NULL, src = bg_user_src(out_name))
}

# ---- Migrimi i fotove të vjetra (V-22 b) -------------------------------------------
# Fotot e ngarkuara para Fazës 6 (te www/images/, jo defaultet) kopjohen te
# storage/images/ dhe state-i drejtohet te kopjet, me kopje rezervë të state-it.
# Origjinalet nuk preken. Kopja verifikohet me md5; kur emri është i zënë nga një
# foto tjetër, merr prapashtesën "_1", "_2"... Mund të thirret në çdo nisje.
migrate_legacy_images <- function(legacy_dir = LEGACY_IMAGES_DIR, user_dir = IMAGES_DIR,
                                  state_file = BG_STATE_FILE, state_dir = STATE_DIR) {
  none <- list(copied = character(0), remap = character(0), state_changed = FALSE)
  files <- if (dir.exists(legacy_dir)) list.files(legacy_dir, pattern = BG_IMAGE_PATTERN, ignore.case = TRUE) else character(0)
  files <- setdiff(files, DEFAULT_BG_IMAGES)
  if (length(files) == 0) return(invisible(none))
  if (!dir.exists(user_dir)) dir.create(user_dir, recursive = TRUE)

  md5 <- function(p) unname(tools::md5sum(p))
  copied <- character(0)
  remap  <- character(0)
  for (f in files) {
    from <- file.path(legacy_dir, f)
    name <- f
    k <- 0L
    while (file.exists(file.path(user_dir, name)) && !identical(md5(file.path(user_dir, name)), md5(from))) {
      k <- k + 1L
      name <- paste0(tools::file_path_sans_ext(f), "_", k, ".", tools::file_ext(f))
    }
    dest <- file.path(user_dir, name)
    if (!file.exists(dest)) {
      ok <- file.copy(from, dest, overwrite = FALSE, copy.date = TRUE)
      if (!isTRUE(ok) || !identical(md5(dest), md5(from))) {
        if (isTRUE(ok)) unlink(dest)  # vetëm kopja e sapokrijuar, kurrë origjinali
        stop("Kopjimi i fotos dështoi: ", from)
      }
      copied <- c(copied, dest)
    }
    remap[paste0("images/", f)] <- bg_user_src(name)
  }

  changed <- FALSE
  if (file.exists(state_file)) {
    st <- read_bg_state(state_file)
    swap <- function(v) if (is.character(v) && length(v) == 1 && v %in% names(remap)) unname(remap[[v]]) else v

    new <- st
    g <- st$modes$image$scopes$global$global
    if (!is.null(g)) new$modes$image$scopes$global$global <- swap(g)
    pt <- st$modes$image$scopes$custom$per_tab
    if (length(pt) > 0) new$modes$image$scopes$custom$per_tab <- lapply(pt, swap)

    if (!identical(new, st)) {
      backup <- file.path(state_dir, paste0("backup-images-", format(Sys.time(), "%Y%m%d-%H%M%S")))
      dir.create(backup, recursive = TRUE, showWarnings = FALSE)
      copy_missing_files(state_file, backup)
      write_bg_state(new, state_file)
      changed <- TRUE
    }
  }
  invisible(list(copied = copied, remap = remap, state_changed = changed))
}

# ---- Ngarkimi i fotove me FilePond, drejt e te serveri (V-29) ------------------
# FilePond-i i dërgon fotot një nga një te adresa e sesionit (session$registerDataObj).
# Ato presin te stg$dir (tempdir) derisa përdoruesi shtyp "Ruaj fotot"; "Anulo" dhe X-i
# i çdo fotoje i hedhin vetëm nga pritja. Galeria nuk preket para "Ruaj fotot".
# Pritja dhe filtri janë te upload_staging.R, të përbashkëta me CSV-në (V-33).
bg_stage_add <- function(stg, read_chunk, name, mime = NULL, max_bytes = BG_UPLOAD_MAX_BYTES) {
  name <- basename(name %||% "")
  ext <- tolower(tools::file_ext(name))
  if (!ext %in% c("jpg", "jpeg", "png", "webp")) return(list(ok = FALSE, msg = tr("bg.err_format")))

  w <- stage_write(stg, read_chunk, ext, max_bytes)
  if (!isTRUE(w$ok)) return(list(ok = FALSE, msg = tr("bg.err_too_big")))

  chk <- validate_bg_upload_file(w$path, name, mime = mime, size = w$size, max_bytes = max_bytes)
  if (!isTRUE(chk$ok)) {
    unlink(w$path)
    return(list(ok = FALSE, msg = chk$msg))
  }
  stg$files[[w$id]] <- list(path = w$path, name = name, mime = mime, size = w$size)
  list(ok = TRUE, id = w$id)
}

# "Ruaj fotot": çdo foto e pritjes kalon te dest_dir me bg_store_upload() (i njëjti kontroll
# dhe emër si ngarkimi i vjetër), pastaj pritja zbrazet.
bg_stage_commit <- function(stg, dest_dir = IMAGES_DIR) {
  res <- lapply(stg$files, function(f) bg_store_upload(f$path, f$name, mime = f$mime, size = f$size, dest_dir = dest_dir))
  stage_discard(stg)
  list(n = sum(vapply(res, function(r) isTRUE(r$ok), logical(1))),
       msgs = unlist(lapply(res, function(r) if (!isTRUE(r$ok)) r$msg)))
}

bg_pond_handler <- function(stg) {
  pond_handler(stg, function(read_chunk, name, mime) bg_stage_add(stg, read_chunk, name, mime = mime))
}
