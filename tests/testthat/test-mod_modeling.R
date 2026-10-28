# mod_modeling: ETS dhe ARIMA nga model_store (P-07), grafiku me plot_ly (V-08), slider-i
# i horizontit për çdo seri (B-02), shënimi për h të madh (V-17 d) dhe mesazhet me validate().

agri_model <- function(vc = c("Production_ton", "Rainfall_mm")) {
  f <- "albania_agriculture_timeseries_1998_2024.csv"
  d <- read_data_safe(file.path(APP_ROOT, "data", "samples", f), f)
  prepare_series(list(file = f, data = d, time_col = "Year", value_cols = vc))
}

test_that("model_fits: modelet e model_store, progresi vetëm kur s'janë në cache", {
  s <- agri_model()
  fits <- model_store()
  calls <- 0
  progress <- function(f) { calls <<- calls + 1; f(function(v) NULL) }

  x <- model_fits(s$data, "Production_ton", fits, progress)
  y <- series_ts(validate_ts_ready(s$data, "Production_ton", FREQ_POLICY, min_n = 20L)$data)
  expect_true(x$ok)
  expect_equal(x$fit_ets$par, fit_ets(y)$par)
  expect_equal(stats::coef(x$fit_arima), stats::coef(fit_arima(y)))
  expect_equal(calls, 1)
  model_fits(s$data, "Production_ton", fits, progress)
  expect_equal(calls, 1)   # e dyta nga cache-i, pa progres

  fc <- model_forecasts(x, 5L)
  expect_equal(fc$time, 2025:2029)
  expect_equal(fc$ets, as.numeric(forecast::forecast(x$fit_ets, h = 5)$mean))

  bad <- model_fits(data.frame(Time = 2001:2010, v = 1:10), "v", fits)
  expect_false(bad$ok)
  expect_equal(bad$msg, "Seria ka shumë pak vëzhgime të vlefshme për këtë analizë.")
})

test_that("grafiku: tri vija, legjenda, boshtet dhe hover-i si te ggplotly (Q27)", {
  s <- agri_model()
  x <- model_fits(s$data, "Production_ton", model_store())
  b <- plotly::plotly_build(model_compare_plot(x, model_forecasts(x, 5L), "Production_ton", s$data$Time, s$meta))$x
  # Vlerat e ggplotly-t në 3dded11.
  expect_equal(vapply(b$data, `[[`, "", "name"), c("ARIMA", "ETS", "Vëzhguar"))
  expect_equal(vapply(b$data, function(t) t$line$color, ""), c("rgba(255,59,48,1)", "rgba(10,132,255,1)", "rgba(255,255,255,1)"))
  expect_equal(b$data[[1]]$line$width, 4.15748, tolerance = 1e-5)
  expect_equal(b$data[[3]]$text[1], "Viti: 1998<br>Vëzhguar: 5 832 128,00")
  expect_equal(b$data[[1]]$text[1], "Viti: 2025<br>ARIMA: 9 967 249,65")
  expect_equal(b$layout$xaxis$range, c(1996.45, 2030.55))
  expect_equal(b$layout$yaxis$range, c(5591448.89783144, 10886389.1455398))
  expect_equal(b$layout$yaxis$ticktext, c("6 mln", "7 mln", "8 mln", "9 mln", "10 mln"))
  expect_equal(unlist(b$layout$margin[c("t", "r", "b", "l")]),
               c(t = 45.3565795, r = 8.6342881, b = 44.0348692, l = 71.6645911), tolerance = 1e-7)
  expect_true(b$layout$showlegend)
  expect_equal(b$layout$legend$borderwidth, 2.2333572, tolerance = 1e-7)
  expect_equal(b$layout$legend$title$font$size, 0)
  expect_equal(b$layout$title$text, "<b> Krahasimi i parashikimeve – Production ton </b>")
})

test_that("grafiku me datë: boshti X si scale_x_date", {
  f <- "Digjitalizimi_Financiar_Shqiperi_data.csv"
  d <- read_data_safe(file.path(APP_ROOT, "data", "samples", f), f)
  s <- prepare_series(list(file = f, data = d, time_col = "Data", value_cols = "Internet_Pct"))
  x <- model_fits(s$data, "Internet_Pct", model_store())
  b <- plotly::plotly_build(model_compare_plot(x, model_forecasts(x, 5L), "Internet_Pct", s$data$Time, s$meta))$x
  expect_equal(b$layout$xaxis$ticktext, c("2022", "2024", "2026"))
  expect_equal(b$layout$xaxis$tickvals, c(18993, 19723, 20454))
  expect_equal(b$data[[2]]$text[1], "Data: 2025-10-01<br>ETS: 75,41")
})

test_that("tabela e saktësisë: vlerat e accuracy(), NA kur modeli mungon", {
  s <- agri_model()
  x <- model_fits(s$data, "Production_ton", model_store())
  t <- model_accuracy_table(x, "Production_ton", s$meta)
  expect_equal(names(t), c("Modeli", "RMSE", "MAE", "MAPE"))
  expect_equal(t$RMSE, c("249 461,85", "235 813,82"))
  expect_equal(t$MAPE, c("2,55", "2,26"))

  na <- model_accuracy_table(list(ok = FALSE), "Production_ton", s$meta)
  expect_equal(na$Modeli, c("ETS", "ARIMA"))
  expect_true(all(is.na(unlist(na[-1]))))
})

test_that("B-02: kufijtë e horizontit rillogariten për çdo seri", {
  d <- data.frame(Time = 1998:2024, Plote = seq_len(27), Shkurter = c(1:8, rep(NA, 19)))
  full <- h_slider_state(d, "Plote", NULL)
  expect_equal(full[c("min", "max", "value")], list(min = 1L, max = 10L, value = 5L))
  expect_equal(full$label, "Horizonti i parashikimit (vite)")

  # Vlera e serisë së mëparshme (10) kufizohet te maksimumi i serisë së shkurtër (7).
  short <- h_slider_state(d, "Shkurter", 10L)
  expect_equal(short[c("min", "max", "value")], list(min = 2L, max = 7L, value = 7L))
  expect_true(short$enabled)
})

test_that("UI: grafiku animohet, ID me namespace", {
  html <- as.character(mod_modeling_ui("modeling"))
  tag <- regmatches(html, regexpr('<div[^>]*id="modeling-plot"[^>]*>', html))
  expect_match(tag, 'class="[^"]*\\banim-plot\\b')
  for (id in c("modeling-series", "modeling-h", "modeling-acc_tbl", "modeling-note")) {
    expect_match(html, sprintf('id="%s"', id), info = id)
  }
  expect_match(html, "Modelimi i serive kohore")
})

test_that("mod_modeling_server: titulli, tabela, shënimi për h të madh dhe mesazhet", {
  sv <- reactiveVal(agri_model())
  testServer(mod_modeling_server, args = list(series = sv, fits = model_store()), {
    session$setInputs(series = "Production_ton", h = 5)
    session$elapse(1000)
    expect_match(output$plot, "Krahasimi i parashikimeve – Production ton")
    expect_equal(output$cap_plot, "Krahasim ETS vs ARIMA për Production ton (h = 5).")
    expect_equal(output$note, "")
    expect_match(output$acc_tbl, "249 461,85", fixed = TRUE)

    session$setInputs(h = 14)   # n = 27: h > 13
    session$elapse(1000)
    expect_equal(output$note, "Kujdes: h është i madh krahasuar me të dhënat (h > n/2).")

    session$setInputs(series = "Mungon")
    expect_error(output$plot, class = "shiny.silent.error")
  })

  few <- list(data = data.frame(Time = 2001:2010, v = c(3, 1, 4, 1, 5, 9, 2, 6, 5, 3)), value_cols = "v", meta = build_meta("v"))
  testServer(mod_modeling_server, args = list(series = reactive(few), fits = model_store()), {
    session$setInputs(series = "v", h = 2)
    expect_error(output$plot, "Seria ka shumë pak vëzhgime të vlefshme për këtë analizë.")
    expect_match(output$acc_tbl, "<td class='NA'> NA </td>", fixed = TRUE)
    expect_equal(output$note, "")
  })

  idx <- list(data = data.frame(Time = 1:30, v = cumsum(1:30 %% 4)), value_cols = "v", meta = build_meta("v"))
  testServer(mod_modeling_server, args = list(series = reactive(idx), fits = model_store()), {
    session$setInputs(series = "v", h = 2)
    expect_error(output$plot, "YYYY-MM-DD ose YYYYQ#", fixed = TRUE)
  })
})
