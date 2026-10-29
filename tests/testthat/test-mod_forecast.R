# mod_forecast: SES/Holt/ARIMA (ARIMA nga model_store, P-07), grafiku me plot_ly (V-08) me
# parashikimin të kuq (B-04), hover-i për çdo vijë (B-05, V-21 a), slider-i (B-02),
# shënimi për h të madh (V-17 d) dhe mesazhet me validate() (B-06).

sample_series <- function(f, time_col, vc) {
  d <- read_data_safe(file.path(APP_ROOT, "data", "samples", f), f)
  prepare_series(list(file = f, data = d, time_col = time_col, value_cols = vc))
}
agri_fc <- function() sample_series("albania_agriculture_timeseries_1998_2024.csv", "Year", c("Production_ton", "Rainfall_mm"))
digj_fc <- function() sample_series("Digjitalizimi_Financiar_Shqiperi_data.csv", "Data", "Internet_Pct")

test_that("forecast_data: seria e rregullt, mesazhet për seri konstante ose të pavlefshme", {
  s <- agri_fc()
  x <- forecast_data(s$data, "Production_ton")
  expect_true(x$ok)
  expect_equal(nrow(x$dd), 27)

  const <- forecast_data(data.frame(Time = 2001:2010, v = rep(5, 10)), "v")
  expect_equal(const$msg, "Seria është (pothuaj) konstante — parashikimi s’ka kuptim.")
  idx <- forecast_data(data.frame(Time = 1:30, v = cumsum(1:30 %% 4)), "v")
  expect_match(idx$msg, "YYYY-MM-DD ose YYYYQ#", fixed = TRUE)
})

test_that("forecast_run: të njëjtat thirrje si forecast_method(); ARIMA nga cache-i", {
  s <- agri_fc()
  dd <- forecast_data(s$data, "Production_ton")$dd
  fits <- model_store()
  r <- forecast_run(dd, "holt", 5L, fits)
  expect_equal(as.numeric(r$fc$mean), as.numeric(forecast_method(series_ts(dd), "holt", 5L)$mean))

  arima_short <- forecast_run(dd, "arima", 5L, fits)
  expect_false(arima_short$ok)
  expect_equal(arima_short$msg, "Për ARIMA rekomandohen ≥ 30 pika reale. Zgjidh SES/Holt ose shto të dhëna.")
  expect_equal(forecast_run(dd, "x", 5L, fits)$msg, "Metodë e panjohur. Lejohen: ses, holt, arima.")

  dg <- forecast_data(digj_fc()$data, "Internet_Pct")$dd
  calls <- 0
  progress <- function(f) { calls <<- calls + 1; f(function(v) NULL) }
  a <- forecast_run(dg, "arima", 5L, fits, progress)
  expect_true(a$ok)
  expect_equal(stats::coef(a$fc$model), stats::coef(fit_arima(series_ts(dg))))
  forecast_run(dg, "arima", 10L, fits, progress)
  expect_equal(calls, 1)   # horizonti i ri nuk e rindërton modelin
})

test_that("grafiku: boshtet si te ggplotly, parashikimi i kuq, hover-i i formatuar bashkë (Q27, B-04, V-21)", {
  s <- agri_fc()
  dd <- forecast_data(s$data, "Production_ton")$dd
  fc <- forecast_run(dd, "holt", 5L, model_store())$fc
  b <- plotly::plotly_build(forecast_plot(dd, fc, "holt", "Production_ton", s$meta))$x
  # Boshtet, margjinat dhe trashësitë: vlerat e ggplotly-t në ac84f0a.
  expect_equal(b$layout$xaxis$range, c(1996.45, 2030.55))
  expect_equal(b$layout$yaxis$range, c(5553602.92154348, 11681154.647587))
  expect_equal(b$layout$yaxis$ticktext, c("6 mln", "8 mln", "10 mln"))
  expect_equal(b$layout$yaxis$gridcolor, "rgba(255,255,255,0.1216)")
  expect_equal(unlist(b$layout$margin[c("t", "r", "b", "l")]),
               c(t = 45.3565795, r = 8.6342881, b = 44.0348692, l = 71.6645911), tolerance = 1e-7)
  expect_equal(vapply(b$data, function(t) t$line$width, 0), c(3.7795276, 1.8897638, 4.5354331), tolerance = 1e-7)
  expect_equal(b$layout$title$text, "<b> Parashikimi – Production ton (HOLT) </b>")

  # B-04 (V-17 b, V-21 b): e vëzhguara e bardhë, parashikimi dhe intervali të kuq.
  expect_equal(vapply(b$data, function(t) t$line$color, ""), c("rgba(255,255,255,1)", "transparent", "rgba(255,59,48,1)"))
  expect_equal(b$data[[2]]$fillcolor, "rgba(255,59,48,0.12)")
  # Intervali si poligon: kufiri i poshtëm, ana e djathtë, kufiri i sipërm mbrapsht.
  expect_equal(as.vector(b$data[[2]]$y)[c(1, 5, 6, 7, 12)],
               c(9642938.03641217, 9888796.50895403, 9888796.50895403, 11402629.5691305, 9642938.03641217))

  # V-21 a: vlerat formatohen bashkë (2 decimale, si te faqet e tjera).
  expect_equal(b$data[[1]]$text[1], "Viti: 1998<br>Production ton: 5 832 128,00")
  expect_equal(b$data[[3]]$text[1], "Viti: 2025<br>Parashikimi: 9 989 322,33<br>Intervali 80%: [9 642 938,04 ; 10 335 706,61]")
})

test_that("B-05: secila vijë merr hover-in e vet edhe kur h = n", {
  dd <- data.frame(Time = 2001:2010, y = c(3, 5, 4, 6, 8, 7, 9, 11, 10, 12))
  fc <- forecast::ses(stats::ts(dd$y, start = 2001), h = 10)
  b <- plotly::plotly_build(forecast_plot(dd, fc, "ses", "y", build_meta("y")))$x
  expect_length(b$data[[1]]$text, 10)
  expect_length(b$data[[3]]$text, 10)
  expect_match(b$data[[1]]$text[1], "^Viti: 2001<br>y: ")
  expect_match(b$data[[3]]$text[1], "^Viti: 2011<br>Parashikimi: .*<br>Intervali 80%: \\[")
})

test_that("grafiku me datë dhe ARIMA", {
  s <- digj_fc()
  dd <- forecast_data(s$data, "Internet_Pct")$dd
  fc <- forecast_run(dd, "arima", 5L, model_store())$fc
  b <- plotly::plotly_build(forecast_plot(dd, fc, "arima", "Internet_Pct", s$meta))$x
  expect_equal(b$layout$title$text, "<b> Parashikimi – Internet Pct (ARIMA) </b>")
  expect_equal(b$data[[3]]$text[1], "Data: 2025-10-01<br>Parashikimi: 75,41<br>Intervali 80%: [75,40 ; 75,42]")
})

test_that("tabela e saktësisë: vlerat e accuracy(), NA kur mungon", {
  s <- agri_fc()
  dd <- forecast_data(s$data, "Production_ton")$dd
  acc <- forecast_accuracy(forecast_run(dd, "holt", 5L, model_store())$fc)
  t <- forecast_accuracy_table(acc, "Production_ton", s$meta)
  expect_equal(names(t), c("Treguesi", "Vlera"))
  expect_equal(t$Vlera, c("-26 505,92", "198 278,11", "249 461,85", "2,55 %"))
  expect_equal(forecast_accuracy_table(NULL, "Production_ton", s$meta)$Vlera, rep("NA", 4))
  expect_null(forecast_accuracy(NULL))
})

test_that("UI: grafiku animohet, ID me namespace, metodat", {
  html <- as.character(mod_forecast_ui("forecast"))
  tag <- regmatches(html, regexpr('<div[^>]*id="forecast-plot"[^>]*>', html))
  expect_match(tag, 'class="[^"]*\\banim-plot\\b')
  for (id in c("forecast-series", "forecast-method", "forecast-h", "forecast-metrics", "forecast-note")) {
    expect_match(html, sprintf('id="%s"', id), info = id)
  }
  expect_match(html, '<option value="ses" selected>SES (sheshim eksponencial i thjeshtë)</option>', fixed = TRUE)
  expect_match(html, '<option value="arima">ARIMA</option>', fixed = TRUE)
})

test_that("mod_forecast_server: titulli, saktësia, shënimi për h të madh dhe mesazhet", {
  testServer(mod_forecast_server, args = list(series = reactiveVal(agri_fc()), fits = model_store()), {
    session$setInputs(series = "Production_ton", method = "holt", h = 5)
    session$elapse(1000)
    expect_match(output$plot, "Parashikimi – Production ton (HOLT)", fixed = TRUE)
    expect_equal(output$cap_plot, "Parashikim me metodën HOLT për Production ton (h = 5).")
    expect_equal(output$note, "")
    expect_match(as.character(output$metrics$html), 'id="proxy1-acc_tbl"', fixed = TRUE)
    expect_match(output$acc_tbl, "249 461,85", fixed = TRUE)

    session$setInputs(h = 14)   # n = 27: h > 13
    session$elapse(1000)
    expect_equal(output$note, "Kujdes: h është i madh krahasuar me të dhënat (h > n/2).")

    # B-06: ARIMA me 27 pika -> mesazhi te grafiku, jo njoftim.
    session$setInputs(method = "arima", h = 5)
    session$elapse(1000)
    expect_error(output$plot, "Për ARIMA rekomandohen ≥ 30 pika reale.", fixed = TRUE)
    expect_match(as.character(output$metrics$html), "Nuk u llogarit saktësia sepse modeli nuk u krijua.", fixed = TRUE)
    expect_equal(output$note, "")

    session$setInputs(series = "Mungon")
    expect_error(output$plot, class = "shiny.silent.error")
  })

  const <- list(data = data.frame(Time = 2001:2010, v = rep(5, 10)), value_cols = "v", meta = build_meta("v"))
  testServer(mod_forecast_server, args = list(series = reactive(const), fits = model_store()), {
    session$setInputs(series = "v", method = "ses", h = 2)
    expect_error(output$plot, "Seria është (pothuaj) konstante — parashikimi s’ka kuptim.", fixed = TRUE)
  })
})
