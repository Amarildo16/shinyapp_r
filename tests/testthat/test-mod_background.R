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
      expect_match(as.character(output$dirty_badge$html), "Ke ndryshime pa Save")
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
      expect_match(as.character(output$modal_fs_title$html), "Media Library – Global")
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

test_that("ngarkimi: fotot e vlefshme te storage/images, të pavlefshmet refuzohen (Q22)", {
  with_clean_bg({
    good <- png_bytes(tempfile(fileext = ".png"))
    fake <- tempfile(fileext = ".jpg"); writeLines("nuk jam foto", fake)
    testServer(mod_background_server, {
      session$flushReact()
      session$setInputs(media_upload = data.frame(
        name = c("nova foto.png", "rreme.jpg"), size = c(28, 13), type = c("image/png", "image/jpeg"),
        datapath = c(good, fake), stringsAsFactors = FALSE))
    })
    expect_true(file.exists(file.path(IMAGES_DIR, "nova_foto.png")))
    expect_false(file.exists(file.path(IMAGES_DIR, "rreme.jpg")))
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
