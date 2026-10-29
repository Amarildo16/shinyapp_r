# mod_eda_ts: slider-i (B-02), grafikët plot_ly (V-08) dhe moduli me shiny::testServer.

agri_series <- function(vc = c("Production_ton", "Area_ha")) {
  f <- "albania_agriculture_timeseries_1998_2024.csv"
  d <- read_data_safe(file.path(APP_ROOT, "data", "samples", f), f)
  prepare_series(list(file = f, data = d, time_col = "Year", value_cols = vc))
}

test_that("roll_slider_state: kufijtë sipas serisë, vlera brenda tyre (B-02)", {
  d <- data.frame(Time = 2000:2029, a = 1:30, b = c(1:6, rep(NA, 24)))   # max: 5 dhe 3

  sa <- roll_slider_state(d, "a", 12)
  sb <- roll_slider_state(d, "b", 12)
  expect_equal(sa[c("min", "max")], roll_bounds(30, d$Time))
  expect_equal(sb[c("min", "max")], roll_bounds(6, d$Time))
  expect_false(identical(sa$max, sb$max))      # seria tjetër, maksimum tjetër
  expect_equal(sa$value, min(12, sa$max))
  expect_equal(sb$value, sb$max)                # 12 përshtatet te maksimumi i serisë b
  expect_equal(roll_slider_state(d, "a", NULL)$value, 5)
  expect_equal(sa$label, "Dritarja lëvizëse (vite)")
  expect_true(sa$enabled)
  expect_false(roll_slider_state(data.frame(Time = 1:5, a = c(1, 2, NA, NA, NA)), "a", 3)$enabled)
})

test_that("grafiku i serisë: margjinat dhe boshtet si te ggplotly (Q27)", {
  s <- agri_series()
  b <- plotly::plotly_build(eda_ts_raw_plot(s$data, "Production_ton", s$meta))$x
  # Vlerat e ggplotly-t në 0724fcb për të njëjtën seri.
  expect_equal(unlist(b$layout$margin[c("t", "r", "b", "l")]),
               c(t = 40.8402, r = 7.3059, b = 37.2603, l = 60.6393), tolerance = 1e-5)
  expect_equal(b$layout$yaxis$ticktext, c("6 mln", "7 mln", "8 mln", "9 mln", "10 mln"))
  expect_equal(b$layout$xaxis$range, c(1996.7, 2025.3))
  expect_equal(b$layout$title$text, "Seria kohore e vëzhguar – Production ton")
  expect_equal(b$data[[1]]$line$width, 3.7795, tolerance = 1e-4)
  expect_equal(b$config$displayModeBar, FALSE)
})

test_that("mesatarja lëvizëse mban NA-të në fillim; shpërndarja ka 18 kolona", {
  s <- agri_series()
  rm <- rolling_mean(s$data, "Production_ton", 3)
  r <- plotly::plotly_build(eda_ts_roll_plot(rm, "Production_ton", s$meta))$x
  expect_length(r$data[[2]]$y, nrow(s$data))
  expect_true(all(is.na(r$data[[2]]$y[1:2])))
  expect_equal(r$layout$title$text, "<b> Mesatarja lëvizëse (k = 3) </b>")
  expect_equal(r$layout$hovermode, "x unified")

  h <- plotly::plotly_build(eda_ts_dist_plot(s$data, "Production_ton", s$meta))$x
  expect_length(h$data[[1]]$x, 18)
  expect_length(h$data[[2]]$x, 2 * 512 + 2)
  expect_equal(h$data[[2]]$hoverinfo, "skip")
})

test_that("UI: grafikët kanë klasën anim-plot dhe ID me namespace", {
  html <- as.character(mod_eda_ts_ui("eda_ts"))
  for (id in c("eda_ts-raw", "eda_ts-roll", "eda_ts-dist")) {
    tag <- regmatches(html, regexpr(sprintf('<div[^>]*id="%s"[^>]*>', id), html))
    expect_match(tag, 'class="[^"]*\\banim-plot\\b[^"]*"', info = id)
  }
  # Klasa është vetëm atribut, jo tekst i dukshëm në faqe.
  expect_equal(lengths(regmatches(html, gregexpr("anim-plot", html))), 3L)
  expect_false(grepl(">\\s*anim-plot\\s*<", html))
})

test_that("mod_eda_ts_server: grafikët, titujt dhe seria e dataset-it tjetër", {
  sv <- reactiveVal(agri_series())
  testServer(mod_eda_ts_server, args = list(series = sv), {
    session$setInputs(series = "Production_ton", roll_k = 3)
    expect_match(output$raw, "Seria kohore e vëzhguar")
    expect_match(output$roll, "Mesatarja lëvizëse \\(k = 3\\)")
    expect_match(output$dist, "Shpërndarja")
    expect_equal(output$cap_raw, "Seria origjinale për Production ton.")
    expect_equal(output$cap_roll, "Mesatare lëvizëse (k = 3) për Production ton.")
    expect_equal(output$cap_dist, "Shpërndarja e vlerave për Production ton.")
    expect_equal(output$roll_note, "")

    # Seria e zgjedhur nuk është te dataset-i i ri: asnjë error, grafiku pret.
    session$setInputs(series = "Mungon")
    expect_error(output$raw, class = "shiny.silent.error")
  })
})

test_that("B-06: pak pika -> validate(); k e përshtatur -> shënim nën grafik", {
  few <- list(data = data.frame(Time = 2000:2004, v = c(1, 2, NA, NA, NA)), value_cols = "v",
              meta = build_meta("v"))
  testServer(mod_eda_ts_server, args = list(series = reactive(few)), {
    session$setInputs(series = "v", roll_k = 3)
    expect_error(output$roll, "Seria ka shumë pak vlera reale \\(jo-NA\\) për mesataren lëvizëse.")
  })

  three <- list(data = data.frame(Time = 2000:2002, v = c(1, 2, 4)), value_cols = "v",
                meta = build_meta("v"))
  testServer(mod_eda_ts_server, args = list(series = reactive(three)), {
    session$setInputs(series = "v", roll_k = 3)
    expect_equal(output$roll_note, "Dritarja u përshtat automatikisht në k=2 (seria ka 3 vlera jo-NA).")
    expect_match(output$roll, "k = 2")
  })
})
