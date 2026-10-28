# Përkthimet e UI-së (V-09, R26): i18n/sq.json dhe i18n/en.json me çelësa të sheshtë.
# Gjuha ruhet te storage/state/settings.json; app-i e vendos me set_lang() kur niset.

.i18n <- new.env(parent = emptyenv())

load_translations <- function(dir = I18N_DIR) {
  out <- list()
  for (lang in names(LANGS)) {
    f <- file.path(dir, paste0(lang, ".json"))
    out[[lang]] <- if (file.exists(f)) jsonlite::fromJSON(f, simplifyVector = FALSE) else list()
  }
  out
}

translations <- function() {
  if (is.null(.i18n$all)) .i18n$all <- load_translations()
  .i18n$all
}

current_lang <- function() {
  lang <- getOption("app.lang", DEFAULT_LANG)
  if (length(lang) == 1 && lang %in% names(LANGS)) lang else DEFAULT_LANG
}

set_lang <- function(lang) {
  if (length(lang) != 1 || !lang %in% names(LANGS)) lang <- DEFAULT_LANG
  options(app.lang = lang)
  invisible(lang)
}

# tr("cel.es", n = 3): "{n}" në tekst zëvendësohet me 3. Çelësi që mungon kthehet
# vetë, që të duket menjëherë (test-i18n.R kontrollon që të mos ndodhë).
# Argumenti quhet .key: me `key`, parametri `k = 3` përputhej pjesërisht me të.
tr <- function(.key, ..., lang = current_lang()) {
  all <- translations()
  val <- all[[lang]][[.key]] %||% all[[DEFAULT_LANG]][[.key]] %||% .key
  args <- list(...)
  for (n in names(args)) {
    val <- gsub(paste0("{", n, "}"), as.character(args[[n]]), val, fixed = TRUE)
  }
  val
}
