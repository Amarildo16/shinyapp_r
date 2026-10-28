# mod_stationarity: diferenca e parë, ACF/PACF me plot_ly (V-08), ADF me numrat sipas
# gjuhës (V-19 a) dhe p-vlerën e prerë "< 0,0100" (V-17 c), mesazhet me validate() (B-06).

agri_stat <- function(vc = c("Production_ton", "Rainfall_mm")) {
  f <- "albania_agriculture_timeseries_1998_2024.csv"
  d <- read_data_safe(file.path(APP_ROOT, "data", "samples", f), f)
  prepare_series(list(file = f, data = d, time_col = "Year", value_cols = vc))
}
ready_of <- function(s, v, n) validate_ts_ready(s$data, v, FREQ_POLICY, min_n = n)$data

test_that("diferenca e parë: boshtet, vija dhe hover-i si te ggplotly (Q27)", {
  s <- agri_stat()
  fd <- first_difference(ready_of(s, "Production_ton", 3L))
  b <- plotly::plotly_build(stat_diff_plot(fd, "Production_ton", s$data$Time, s$meta))$x
  # Vlerat e ggplotly-t në e47e4e2.
  expect_equal(b$layout$yaxis$ticktext, c("-250 mijë", "0", "250 mijë", "500 mijë"))
  expect_equal(b$layout$yaxis$range, c(-374100.9, 739360.9))
  expect_equal(b$layout$xaxis$range, c(1997.75, 2025.25))
  expect_equal(unlist(b$layout$margin[c("t", "r", "b", "l")]), c(t = 60, r = 20, b = 60, l = 70))
  expect_equal(b$layout$title$text, "<b> Diferenca e parë – Production ton </b>")
  expect_equal(b$data[[1]]$line$width, 4.5354, tolerance = 1e-4)
  expect_equal(b$data[[1]]$line$color, "rgba(10,132,255,1)")
  expect_equal(b$data[[1]]$text[1], "Viti: 1999<br>Diferenca: 466 527,00")
})

test_that("ACF/PACF: dy panele, kufijtë ±1,96/√n dhe hover-i si te ggplotly (Q27)", {
  s  <- agri_stat()
  ap <- acf_pacf_data(ready_of(s, "Production_ton", 6L))
  b  <- plotly::plotly_build(stat_acf_plot(ap, "Production_ton", s$meta))$x
  expect_equal(b$layout$yaxis$domain, c(0.5350768, 1), tolerance = 1e-6)
  expect_equal(b$layout$yaxis2$domain, c(0, 0.4649232), tolerance = 1e-6)
  expect_equal(b$layout$yaxis$range, c(-0.4228, 0.4228), tolerance = 1e-3)
  expect_equal(b$layout$xaxis$range, c(-0.035, 15.035))
  expect_equal(b$layout$xaxis$anchor, "y2")
  ann <- b$layout$annotations
  expect_equal(vapply(ann, `[[`, "", "text"), c("Vonesa (lag)", "Korrelacioni", "ACF", "PACF"))
  expect_equal(ann[[1]]$yshift, -26.6999, tolerance = 1e-5)
  expect_equal(ann[[2]]$xshift, -41.3117, tolerance = 1e-5)
  expect_equal(b$layout$shapes[[1]]$y1, 27.6297, tolerance = 1e-5)
  expect_equal(b$data[[1]]$marker$color, "rgba(10,132,255,0.7451)")
  expect_equal(b$data[[1]]$text[1], "Vonesa:  1<br />Vlera:  0.0597035206")
  # Shtyllat negative: baza = vlera, lartësia = |vlera|.
  i <- which(ap$acf$value < 0)[1]
  expect_equal(b$data[[1]]$base[i], ap$acf$value[i])
  expect_equal(b$data[[1]]$y[i], -ap$acf$value[i])
  expect_equal(as.vector(b$data[[3]]$y), c(-ap$conf, -ap$conf, NA, ap$conf, ap$conf))
  expect_equal(b$data[[4]]$yaxis, "y2")
})

test_that("ADF: vlerat nga run_adf(), p-vlera sipas gjuhës dhe kufiri i prerë", {
  s <- agri_stat()
  a <- adf_summary(s$data, "Rainfall_mm")
  r <- run_adf(ready_of(s, "Rainfall_mm", 20L)$y)
  expect_true(a$ok)
  expect_equal(a$statistic, round(c(r$level$statistic, r$diff$statistic), 4))
  expect_equal(a$p_lvl, r$level$p_value)
  expect_equal(a$p_bound, c("lower", "lower"))

  expect_equal(adf_p_text(c(0.50312, 0.01, 0.99), c(NA, "lower", "upper"), ","),
               c("0,5031", "< 0,0100", "> 0,9900"))
  expect_equal(adf_p_text(0.01, "lower", "."), "< 0.0100")

  bad <- adf_summary(data.frame(Time = 2001:2010, v = 1:10), "v")
  expect_false(bad$ok)
  expect_equal(bad$method, rep("Seria ka shumë pak vëzhgime të vlefshme për këtë analizë.", 2))
  expect_true(is.numeric(adf_table(bad)[[3]]))   # si më parë: kolona numerike NA
})

test_that("UI: të dy grafikët animohen, ID me namespace", {
  html <- as.character(mod_stationarity_ui("stationary"))
  for (id in c("stationary-diff", "stationary-acf")) {
    tag <- regmatches(html, regexpr(sprintf('<div[^>]*id="%s"[^>]*>', id), html))
    expect_match(tag, 'class="[^"]*\\banim-plot\\b', info = id)
  }
  expect_match(html, 'id="stationary-adf_tbl"')
  expect_match(html, "Stacionariteti dhe transformimet")
})

test_that("mod_stationarity_server: tabela, interpretimi dhe titujt", {
  sv <- reactiveVal(agri_stat())
  testServer(mod_stationarity_server, args = list(series = sv), {
    session$setInputs(series = "Production_ton")
    expect_match(output$diff, "Diferenca e parë – Production ton")
    expect_match(output$acf, "ACF dhe PACF – Production ton")
    expect_match(output$adf_tbl, "> -2,18 <", fixed = TRUE)
    expect_match(output$adf_tbl, "> 0,5031 <", fixed = TRUE)
    note <- as.character(output$adf_note$html)
    expect_match(note, "&alpha; = 0,05: <br>• <b>Niveli</b> (p = 0,5031): nuk refuzohet hipoteza zero", fixed = TRUE)
    expect_equal(output$cap_diff, "Diferenca e parë (Δyₜ = yₜ − yₜ₋₁) për Production ton.")
    expect_equal(output$cap_acf, "ACF/PACF mbi diferencën e parë të Production ton.")

    session$setInputs(series = "Rainfall_mm")
    expect_match(output$adf_tbl, "&lt; 0,0100", fixed = TRUE)
    expect_match(as.character(output$adf_note$html), "(p < 0,0100): refuzohet hipoteza zero", fixed = TRUE)

    session$setInputs(series = "Mungon")
    expect_error(output$diff, class = "shiny.silent.error")
  })
})

test_that("B-06 / B-09: mesazhet e serive të pavlefshme dalin me validate()", {
  few <- list(data = data.frame(Time = 2001:2005, v = c(3, 1, 4, 1, 5)), value_cols = "v", meta = build_meta("v"))
  testServer(mod_stationarity_server, args = list(series = reactive(few)), {
    session$setInputs(series = "v")
    expect_match(output$diff, "Diferenca e parë – v")
    expect_error(output$acf, "Seria ka shumë pak vëzhgime të vlefshme për këtë analizë.")
  })

  idx <- list(data = data.frame(Time = 1:30, v = cumsum(1:30 %% 4)), value_cols = "v", meta = build_meta("v"))
  testServer(mod_stationarity_server, args = list(series = reactive(idx)), {
    session$setInputs(series = "v")
    expect_error(output$diff, "YYYY-MM-DD ose YYYYQ#", fixed = TRUE)
    expect_match(as.character(output$adf_note$html), "nuk janë vite")
  })
})
