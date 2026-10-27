test_that("is_path_inside_dir pranon vetëm shtigje brenda folderit", {
  base <- file.path(TEST_SANDBOX, "base")
  dir.create(base, showWarnings = FALSE)

  expect_true(is_path_inside_dir(file.path(base, "a.csv"), base))
  expect_true(is_path_inside_dir(base, base))
  expect_false(is_path_inside_dir(file.path(base, "..", "x.csv"), base))
  expect_false(is_path_inside_dir(paste0(base, "2/x.csv"), base))
  expect_false(is_path_inside_dir(file.path(TEST_SANDBOX, "other.csv"), base))
})

test_that("sanitize_filename heq shtigjet dhe karakteret e rrezikshme", {
  expect_equal(sanitize_filename("../../etc/passwd"), "passwd.csv")
  expect_equal(sanitize_filename("my file (1).csv"), "my_file_1_.csv")
  expect_equal(sanitize_filename("data"), "data.csv")
  expect_equal(sanitize_filename("foto e zyshës.jpg", "jpg"), "foto_e_zysh_s.jpg")
  expect_match(sanitize_filename("'"), "^dataset_\\d{8}_\\d{6}\\.csv$")
  expect_match(sanitize_filename(NULL), "^dataset_\\d{8}_\\d{6}\\.csv$")
})

test_that("resolve_saved_dataset_path lejon vetëm dataset-et e ruajtura te DATA_DIR", {
  file.create(file.path(DATA_DIR, "ok.csv"))
  on.exit(unlink(file.path(DATA_DIR, "ok.csv")), add = TRUE)

  r <- resolve_saved_dataset_path("ok.csv")
  expect_true(r$ok)
  expect_equal(r$path, normalize_app_path(file.path(DATA_DIR, "ok.csv")))

  expect_false(resolve_saved_dataset_path("../ok.csv")$ok)
  expect_false(resolve_saved_dataset_path("mungon.csv")$ok)
  expect_false(resolve_saved_dataset_path(NULL)$ok)
  expect_false(resolve_saved_dataset_path("")$ok)
  expect_false(resolve_saved_dataset_path(file.path(DATA_DIR, "ok.csv"))$ok)
})

test_that("resolve_media_image_path lejon vetëm www/images/", {
  expect_true(resolve_media_image_path("images/x.jpg", TEST_SANDBOX)$ok)
  expect_false(resolve_media_image_path("../secret.jpg", TEST_SANDBOX)$ok)
  expect_false(resolve_media_image_path("images/../../x.jpg", TEST_SANDBOX)$ok)
  expect_false(resolve_media_image_path("C:/Windows/x.jpg", TEST_SANDBOX)$ok)
  expect_false(resolve_media_image_path("/etc/passwd", TEST_SANDBOX)$ok)
  expect_false(resolve_media_image_path("css/x.css", TEST_SANDBOX)$ok)
  expect_false(resolve_media_image_path(NA, TEST_SANDBOX)$ok)
})

test_that("validate_bg_upload_file kontrollon formatin, MIME, madhësinë dhe magic bytes (R19)", {
  write_raw <- function(bytes, ext) {
    f <- tempfile(fileext = paste0(".", ext))
    writeBin(as.raw(bytes), f)
    f
  }
  jpg  <- write_raw(c(0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0), "jpg")
  png  <- write_raw(c(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0), "png")
  webp <- write_raw(c(charToRaw("RIFF"), as.raw(c(0, 0, 0, 0)), charToRaw("WEBP")), "webp")
  fake <- tempfile(fileext = ".jpg"); writeLines("nuk jam foto", fake)

  expect_true(validate_bg_upload_file(jpg, "foto.jpg", "image/jpeg")$ok)
  expect_true(validate_bg_upload_file(png, "foto.png", "image/png")$ok)
  expect_true(validate_bg_upload_file(webp, "foto.webp", "")$ok)

  expect_false(validate_bg_upload_file(fake, "foto.jpg", "image/jpeg")$ok)
  expect_false(validate_bg_upload_file(jpg, "foto.gif", "image/gif")$ok)
  expect_false(validate_bg_upload_file(jpg, "foto.jpg", "image/png")$ok)
  expect_false(validate_bg_upload_file(jpg, "foto.jpg", "image/jpeg", size = 6 * 1024^2)$ok)
  expect_false(validate_bg_upload_file(file.path(TEST_SANDBOX, "mungon.jpg"), "mungon.jpg")$ok)
})
