# Media Library: fotot default dhe ato të ngarkuara, shtegu i sigurt, ngarkimi (R19),
# fotot në përdorim (Q23) dhe migrimi i fotove të vjetra të www/images/ (V-22).

fake_png <- function(path, extra = 1:20) {
  writeBin(c(as.raw(c(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)), as.raw(extra)), path)
  path
}
new_dir <- function() {
  d <- normalizePath(tempfile("media_"), winslash = "/", mustWork = FALSE)
  dir.create(d, recursive = TRUE)
  d
}
bg_state_with <- function(global = NULL, per_tab = list()) {
  st <- default_bg_state()
  st$modes$image$scopes$global$global <- global
  st$modes$image$scopes$custom$per_tab <- per_tab
  st
}

test_that("bg_is_default njeh vetëm 12 fotot default te images/", {
  expect_true(bg_is_default("images/image0.jpeg"))
  expect_true(bg_is_default("images/image11.jpeg"))
  expect_false(bg_is_default("images/image12.jpeg"))
  expect_false(bg_is_default("user-images/image0.jpeg"))
  expect_false(bg_is_default("images/sub/image0.jpeg"))
  expect_false(bg_is_default(NA_character_))
})

test_that("bg_image_list: defaultet e kodit dhe fotot e ngarkuara, sipas emrit", {
  user <- new_dir()
  fake_png(file.path(user, "foto e Ana's.png"))
  fake_png(file.path(user, "zz.png"))
  writeLines("x", file.path(user, "shenim.txt"))
  imgs <- bg_image_list(file.path(APP_ROOT, "www", "images"), user)
  expect_equal(head(imgs, 2), c("user-images/foto e Ana's.png", "images/image0.jpeg"))
  expect_equal(tail(imgs, 1), "user-images/zz.png")
  expect_length(imgs, 14)
})

test_that("B-31: pa foto të ngarkuara, vetëm 12 fotot default", {
  imgs <- bg_image_list(file.path(APP_ROOT, "www", "images"), new_dir())
  expect_length(imgs, 12)
  expect_false("user-images/" %in% imgs)
  expect_length(bg_user_src(character(0)), 0)
  expect_equal(bg_user_src("a.png"), "user-images/a.png")
})

test_that("resolve_user_image_path lejon vetëm storage/images/ dhe jo defaultet", {
  user <- new_dir()
  r <- resolve_user_image_path("user-images/x.png", user)
  expect_true(r$ok)
  expect_equal(r$path, normalize_app_path(file.path(user, "x.png")))

  expect_equal(resolve_user_image_path("images/image3.jpeg", user)$msg, "Fotot default nuk fshihen.")
  expect_equal(resolve_user_image_path("images/x.jpg", user)$msg, "S’lejohet fshirja jashtë images/.")
  expect_false(resolve_user_image_path("user-images/../../x.png", user)$ok)
  expect_false(resolve_user_image_path("C:/Windows/x.png", user)$ok)
  expect_false(resolve_user_image_path("/etc/passwd", user)$ok)
  expect_equal(resolve_user_image_path(NA, user)$msg, "Shtegu i fotos nuk lejohet.")
})

test_that("bg_images_in_use: fotoja globale dhe ato të faqeve", {
  st <- bg_state_with("images/image1.jpeg", list(tab_overview = "user-images/a.png", tab_eda_ts = ""))
  expect_setequal(bg_images_in_use(st), c("images/image1.jpeg", "user-images/a.png"))
  expect_length(bg_images_in_use(default_bg_state()), 0)
})

test_that("bg_store_upload: validimi, emri i pastruar dhe emri i zënë (Q22)", {
  user <- new_dir()
  src <- fake_png(tempfile(fileext = ".png"))
  r <- bg_store_upload(src, "foto e Ana's.png", "image/png", dest_dir = user)
  expect_true(r$ok)
  expect_equal(r$src, "user-images/foto_e_Ana_s.png")
  expect_true(file.exists(file.path(user, "foto_e_Ana_s.png")))

  again <- bg_store_upload(src, "foto e Ana's.png", "image/png", dest_dir = user)
  expect_match(again$src, "^user-images/foto_e_Ana_s_[0-9]{8}_[0-9]{6}_1\\.png$")

  fake <- tempfile(fileext = ".jpg"); writeLines("nuk jam foto", fake)
  bad <- bg_store_upload(fake, "rreme.jpg", "image/jpeg", dest_dir = user)
  expect_false(bad$ok)
  expect_equal(bad$msg, "rreme.jpg: Përmbajtja e file-it nuk duket si foto e vlefshme.")
  big <- bg_store_upload(src, "e_madhe.png", "image/png", size = 6 * 1024^2, dest_dir = user)
  expect_equal(big$msg, "e_madhe.png: Foto është shumë e madhe. Limiti është 5 MB.")
  expect_length(list.files(user), 2)
})

test_that("migrimi: fotot e vjetra kopjohen, state-i drejtohet te kopjet, origjinalet mbeten (V-22 b)", {
  legacy <- new_dir(); user <- new_dir(); state_dir <- new_dir()
  state_file <- file.path(state_dir, "background_state.json")

  file.copy(file.path(APP_ROOT, "www", "images", "image1.jpeg"), legacy)
  fake_png(file.path(legacy, "foto_e_zyshes.png"), 1:30)
  fake_png(file.path(legacy, "foto e Ana's.png"), 1:40)
  fake_png(file.path(user, "foto_e_zyshes.png"), 50:60)   # emër i zënë nga një foto tjetër
  write_bg_state(bg_state_with("images/image1.jpeg",
                               list(tab_overview = "images/foto_e_zyshes.png", tab_eda_ts = "images/foto e Ana's.png")),
                 state_file)
  md5_before <- tools::md5sum(list.files(legacy, full.names = TRUE))

  r <- migrate_legacy_images(legacy, user, state_file, state_dir)
  expect_true(r$state_changed)
  expect_setequal(basename(r$copied), c("foto_e_zyshes_1.png", "foto e Ana's.png"))
  expect_false(file.exists(file.path(user, "image1.jpeg")))     # defaultet nuk kopjohen

  st <- read_bg_state(state_file)
  expect_equal(st$modes$image$scopes$global$global, "images/image1.jpeg")
  expect_equal(st$modes$image$scopes$custom$per_tab$tab_overview, "user-images/foto_e_zyshes_1.png")
  expect_equal(st$modes$image$scopes$custom$per_tab$tab_eda_ts, "user-images/foto e Ana's.png")
  expect_equal(unname(tools::md5sum(file.path(user, "foto_e_zyshes_1.png"))),
               unname(tools::md5sum(file.path(legacy, "foto_e_zyshes.png"))))

  # Origjinalet dhe fotoja e zënë nuk preken; kopja rezervë e state-it ekziston.
  expect_equal(tools::md5sum(list.files(legacy, full.names = TRUE)), md5_before)
  expect_equal(readBin(file.path(user, "foto_e_zyshes.png"), "raw", 30)[9:19], as.raw(50:60))
  expect_length(list.files(state_dir, pattern = "^backup-images-"), 1)

  # E dyta herë: asgjë e re.
  again <- migrate_legacy_images(legacy, user, state_file, state_dir)
  expect_length(again$copied, 0)
  expect_false(again$state_changed)
})

test_that("migrimi pa foto të vjetra nuk prek asgjë", {
  r <- migrate_legacy_images(file.path(new_dir(), "mungon"), new_dir(), tempfile(), new_dir())
  expect_length(r$copied, 0)
  expect_false(r$state_changed)
})
