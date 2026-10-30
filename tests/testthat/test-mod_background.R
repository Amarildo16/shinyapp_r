# mod_background_server() me shiny::testServer mbi storage-in e sandbox-it: Save (Q20, Q21),
# galeria (V-22 a, B-08), fshirja (Q23) dhe ngarkimi (Q22).

with_clean_bg <- function(code) {
  old_state <- if (file.exists(BG_STATE_FILE)) readLines(BG_STATE_FILE, warn = FALSE) else NULL
  old_imgs  <- list.files(IMAGES_DIR)
  on.exit({
    if (is.null(old_state)) unlink(BG_STATE_FILE) else writeLines(old_state, BG_STATE_FILE)
    unlink(file.path(IMAGES_DIR, setdiff(list.files(IMAGES_DIR), old_imgs)))
  })
  force(code)
}
png_bytes <- function(path) {
  writeBin(c(as.raw(c(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)), as.raw(1:20)), path)
  path
}

test_that("UI: ID me namespace, kushtet e panelit dhe ngjyra e ruajtur", {
  st <- default_bg_state()
  st$active_mode <- "color"
  st$modes$color$value <- "#ef4444"
  html <- as.character(mod_background_ui("bg", st))
  expect_match(html, 'id="bg-mode"')
  expect_match(html, 'data-display-if="input.mode == &#39;image&#39;" data-ns-prefix="bg-"', fixed = TRUE)
  expect_match(html, 'id="bg-color" type="color" value="#ef4444"', fixed = TRUE)
  expect_match(html, 'value="color" checked')

  modals <- as.character(mod_background_modals_ui("bg"))
  expect_match(modals, 'id="bg-modal_fs"')
  expect_match(modals, 'id="bg-delete_modal"')
})

test_that("Save: ngjyra dhe fotoja për faqe ruhen te state-i (Q20, Q21)", {
  with_clean_bg({
    write_bg_state(default_bg_state())
    testServer(mod_background_server, {
      session$setInputs(mode = "color", color = "#ef4444")
      session$setInputs(save = 1)
      st <- read_bg_state()
      expect_equal(st$active_mode, "color")
      expect_equal(st$modes$color$value, "#ef4444")

      session$setInputs(mode = "image", scope = "custom", blur_on = TRUE, blur = 6)
      session$setInputs(edit__tab_overview = 1)
      session$setInputs(media_pick = "images/image5.jpeg")
      session$setInputs(btn_use = 1)
      expect_match(as.character(output$dirty_badge$html), "Ke ndryshime të paruajtura")
      session$setInputs(save = 2)
      st <- read_bg_state()
      expect_equal(st$active_mode, "image")
      expect_equal(st$modes$image$blur$amount, 6L)
      expect_equal(st$modes$image$scopes$custom$per_tab$tab_overview, "images/image5.jpeg")
      expect_null(output$dirty_badge$html)

      # Heqja e fotos aktive dhe Save.
      session$setInputs(edit__tab_overview = 2)
      session$setInputs(media_clear_active = "images/image5.jpeg")
      session$setInputs(save = 3)
      expect_null(read_bg_state()$modes$image$scopes$custom$per_tab$tab_overview)
    })
  })
})

test_that("galeria: defaultet pa butonin e fshirjes, emri me ' kalon si JSON (V-22 a, B-08)", {
  with_clean_bg({
    png_bytes(file.path(IMAGES_DIR, "foto e Ana's.png"))
    testServer(mod_background_server, {
      session$flushReact()   # si në browser: flush-i i parë para klikimit (ignoreInit)
      session$setInputs(edit_global_btn = 1)
      html <- as.character(output$media_gallery$html)
      expect_equal(lengths(regmatches(html, gregexpr('class="media-card', html))), 13)
      expect_equal(lengths(regmatches(html, gregexpr("media-delete-btn", html))), 1)
      expect_match(html, "Shiny.setInputValue(&quot;proxy1-media_pick&quot;, &quot;user-images/foto e Ana&#39;s.png&quot;", fixed = TRUE)
      expect_match(html, '<img src="user-images/foto e Ana&#39;s.png"/>', fixed = TRUE)
      expect_match(as.character(output$modal_fs_title$html), "Galeria e fotove – Globale")
    })
  })
})

test_that("fshirja: fotoja në përdorim bllokohet, e lira fshihet, defaultet jo (Q23)", {
  with_clean_bg({
    png_bytes(file.path(IMAGES_DIR, "ne_perdorim.png"))
    png_bytes(file.path(IMAGES_DIR, "e_lire.png"))
    st <- default_bg_state()
    st$modes$image$scopes$custom$per_tab <- list(tab_overview = "user-images/ne_perdorim.png")
    write_bg_state(st)

    testServer(mod_background_server, {
      session$flushReact()
      session$setInputs(media_delete = "user-images/ne_perdorim.png")
      expect_match(as.character(output$delete_modal_body$html), "Do ta fshish këtë foto? ne_perdorim.png", fixed = TRUE)
      session$setInputs(delete_confirm = 1)
      expect_true(file.exists(file.path(IMAGES_DIR, "ne_perdorim.png")))

      session$setInputs(media_delete = "user-images/e_lire.png")
      session$setInputs(delete_confirm = 2)
      expect_false(file.exists(file.path(IMAGES_DIR, "e_lire.png")))

      session$setInputs(media_delete = "images/image7.jpeg")
      session$setInputs(delete_confirm = 3)
      expect_true(file.exists(file.path(BG_DEFAULT_DIR, "image7.jpeg")))
    })
  })
})

# Kërkesa e FilePond-it te adresa e registerDataObj (V-29), pa server HTTP.
pond_req <- function(op, body = raw(), name = NULL, type = NULL, method = "POST") {
  done <- FALSE
  list(REQUEST_METHOD = method, HTTP_X_POND_OP = op,
       HTTP_X_FILE_NAME = if (!is.null(name)) utils::URLencode(name, reserved = TRUE),
       HTTP_X_FILE_TYPE = type,
       rook.input = list(read = function(n = -1L) { if (done) return(raw()); done <<- TRUE; body }))
}
file_reader <- function(path) {
  x <- readBin(path, "raw", file.info(path)$size); done <- FALSE
  function() { if (done) return(raw()); done <<- TRUE; x }
}

test_that("V-29: pritja e fotove: shto, refuzo, hiq, ruaj, anulo (Q22)", {
  with_clean_bg({
    stg <- bg_staging(tempfile("stg_"))
    good <- png_bytes(tempfile(fileext = ".png"))
    fake <- tempfile(fileext = ".jpg"); writeLines("nuk jam foto", fake)

    r1 <- bg_stage_add(stg, file_reader(good), "nova foto.png", "image/png")
    expect_true(r1$ok); expect_equal(r1$id, "f0001")
    r2 <- bg_stage_add(stg, file_reader(good), "e dyta.png", "image/png")
    expect_true(r2$ok)
    expect_equal(bg_stage_add(stg, file_reader(fake), "rreme.jpg", "image/jpeg")$msg, tr("bg.err_content"))
    expect_equal(bg_stage_add(stg, file_reader(good), "shenime.txt")$msg, tr("bg.err_format"))
    expect_equal(bg_stage_add(stg, file_reader(good), "e madhe.png", "image/png", max_bytes = 10)$msg, tr("bg.err_too_big"))
    expect_length(list.files(stg$dir), 2)          # të refuzuarat nuk mbeten në pritje
    expect_length(setdiff(list.files(IMAGES_DIR), "foto.png"), length(setdiff(list.files(IMAGES_DIR), "foto.png")))

    expect_true(bg_stage_remove(stg, r2$id))
    expect_false(bg_stage_remove(stg, r2$id))
    expect_false(bg_stage_remove(stg, "../../x"))
    expect_false(file.exists(file.path(IMAGES_DIR, "nova_foto.png")))   # para "Ruaj fotot", Galeria e paprekur

    res <- bg_stage_commit(stg)
    expect_equal(res$n, 1L)
    expect_true(file.exists(file.path(IMAGES_DIR, "nova_foto.png")))
    expect_false(file.exists(file.path(IMAGES_DIR, "e_dyta.png")))
    expect_length(list.files(stg$dir), 0)

    bg_stage_add(stg, file_reader(good), "e treta.png", "image/png")
    bg_stage_discard(stg)                           # "Anulo"
    expect_length(list.files(stg$dir), 0)
    expect_false(file.exists(file.path(IMAGES_DIR, "e_treta.png")))
  })
})

test_that("V-29: adresa e FilePond-it: process, revert dhe përgjigjet e gabimit", {
  stg <- bg_staging(tempfile("stg_"))
  h <- bg_pond_handler(stg)
  good <- png_bytes(tempfile(fileext = ".png"))
  bytes <- readBin(good, "raw", file.info(good)$size)

  ok <- h(NULL, pond_req("process", bytes, "foto ime.png", "image/png"))
  expect_equal(ok$status, 200L)
  id <- ok$content
  expect_equal(stg$files[[id]]$name, "foto ime.png")
  expect_equal(file.info(stg$files[[id]]$path)$size, length(bytes))

  expect_equal(ok$headers$`X-Pond-Status`, "ok")
  bad <- h(NULL, pond_req("process", charToRaw("tekst"), "x.png", "image/png"))
  expect_equal(bad$status, 200L)                       # 200 + shenja e gabimit: pa gabim te console
  expect_equal(bad$headers$`X-Pond-Status`, "error")
  expect_equal(bad$content, enc2utf8(tr("bg.err_content")))

  expect_equal(h(NULL, pond_req("revert", charToRaw(id)))$status, 200L)
  expect_length(stg$files, 0)
  expect_equal(h(NULL, pond_req("revert", charToRaw(id)))$status, 200L)   # e dyta: s'ka çfarë të hiqet
  expect_equal(h(NULL, pond_req("process", bytes, "a.png", method = "GET"))$status, 405L)
  expect_equal(h(NULL, pond_req("tjeter"))$status, 400L)
  expect_length(stg$files, 0)
})

test_that("V-29: moduli: adresa te UI-ja, \"Ruaj fotot\" dhe \"Anulo\" (B-28)", {
  with_clean_bg({
    good <- png_bytes(tempfile(fileext = ".png"))
    bytes <- readBin(good, "raw", file.info(good)$size)
    testServer(mod_background_server, {
      session$flushReact()
      session$setInputs(edit_global_btn = 1)
      html <- as.character(output$modal_fs_body$html)
      expect_match(html, 'id="[a-z0-9]+-media_pond_host"')
      # MockShinySession$registerDataObj() kthen NULL: adresa e vërtetë provohet në browser.
      expect_match(html, 'data-max-mb="5"', fixed = TRUE)
      expect_false(grepl("media_upload", html, fixed = TRUE))

      h <- bg_pond_handler(staging)
      for (nm in c("e para.png", "e dyta.png", "e treta.png")) h(NULL, pond_req("process", bytes, nm, "image/png"))
      expect_length(staging$files, 3)                     # shumë foto njëherësh, pa u ruajtur ende
      expect_false(file.exists(file.path(IMAGES_DIR, "e_para.png")))
      session$setInputs(btn_save_upload = 1)
      expect_true(all(file.exists(file.path(IMAGES_DIR, c("e_para.png", "e_dyta.png", "e_treta.png")))))
      expect_length(staging$files, 0)

      h(NULL, pond_req("process", bytes, "anuluar.png", "image/png"))
      session$setInputs(btn_cancel_upload = 1)
      expect_length(staging$files, 0)
      expect_false(file.exists(file.path(IMAGES_DIR, "anuluar.png")))
    })
  })
})

test_that("bg_apply_save: fotoja globale dhe heqja e saj", {
  st <- bg_apply_save(default_bg_state(), "image", NULL, TRUE, 10, "global", "user-images/a.png", list())
  expect_equal(st$modes$image$scopes$global$global, "user-images/a.png")
  st2 <- bg_apply_save(st, "image", NULL, TRUE, 10, "global", BG_CLEAR, list())
  expect_null(st2$modes$image$scopes$global$global)
  st3 <- bg_apply_save(st, "none", NULL, NULL, NULL, NULL, NULL, list())
  expect_equal(st3$active_mode, "none")
  expect_equal(st3$modes$image$scopes$global$global, "user-images/a.png")
})

test_that("U-07: shenja e ndryshimeve zhduket kur kthehet zgjedhja e ruajtur", {
  with_clean_bg({
    st <- default_bg_state()
    st$active_mode <- "image"
    write_bg_state(st)
    testServer(mod_background_server, {
      session$setInputs(mode = "image", scope = "custom", blur_on = TRUE, blur = 10)
      expect_null(output$dirty_badge$html)
      session$setInputs(mode = "none")
      expect_match(as.character(output$dirty_badge$html), "Ke ndryshime të paruajtura")
      session$setInputs(mode = "image")
      expect_null(output$dirty_badge$html)
    })
  })
})
