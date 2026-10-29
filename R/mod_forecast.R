# Parashikimi: SES, Holt ose ARIMA me intervalin e pasigurisë dhe saktësia në setin e trajnimit.
# ARIMA vjen nga model_store (P-07), e njëjta si te Modelimi. Grafiku me plot_ly direkt (V-08):
# parashikimi i kuq dhe intervali i kuq i tejdukshëm (B-04, V-17 b), hover për çdo vijë (B-05).

FORECAST_METHODS <- c("ses", "holt", "arima")
FORECAST_RED <- "rgba(255,59,48,1)"

mod_forecast_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "glass-divider"),

    sidebarLayout(
      position = "left",

      sidebarPanel(
        h4(tr("fc.settings")),

        selectInput(ns("series"), tr("fc.series"), choices = character(0)),

        selectInput(
          ns("method"),
          tr("fc.method"),
          choices = setNames(FORECAST_METHODS, c(tr("fc.m_ses"), tr("fc.m_holt"), "ARIMA"))
        ),

        sliderInput(
          ns("h"),
          tr("fc.h"),
          min = 1,
          max = 1,
          value = 1,
          step = 1
        ),

        hr(),
        p(tr("fc.side_note"))
      ),

      mainPanel(
        div(
          class = "section-box",
          h4(tr("fc.plot_box")),
          div(
            class = "plot-wrap",
            anim_plotly_output(ns("plot"), height = "520px")
          ),
          tags$small(textOutput(ns("cap_plot"))),
          tags$small(textOutput(ns("note")))
        ),

        div(class = "glass-divider"),

        div(
          class = "section-box",
          h4(tr("fc.acc_box")),
          div(
            class = "table-wrap",
            uiOutput(ns("metrics"))
          )
        )
      )
    )
  )
}

# ---- Llogaritjet (funksione të pastra) ------------------------------------------

# Seria e rregullt (≥ 2 pika) dhe jo konstante. ok = FALSE me mesazhin përkatës.
forecast_data <- function(d, series) {
  v <- validate_ts_ready(d, series, FREQ_POLICY, min_n = 2L)
  if (!isTRUE(v$ok)) return(list(ok = FALSE, msg = v$message))
  if (stats::sd(v$data$y, na.rm = TRUE) < 1e-12) return(list(ok = FALSE, msg = tr("fc.constant")))
  list(ok = TRUE, dd = v$data)
}

# ARIMA nga cache-i `fits` (≥ 30 pika reale). progress(f): progresi kur s'është ende në cache.
forecast_arima_fit <- function(dd, fits, progress = NULL) {
  if (sum(!is.na(dd$y)) < 30) return(list(ok = FALSE, msg = tr("fc.arima_need30")))

  y <- series_ts(dd)
  get_fit <- function(step = function(v) NULL) {
    step(0.2)
    f <- fits$get("arima", y)
    step(0.95)
    f
  }
  fit <- if (is.null(progress) || fits$has("arima", y)) get_fit() else progress(get_fit)

  if (is.null(fit)) return(list(ok = FALSE, msg = tr("fc.arima_failed")))
  list(ok = TRUE, fit = fit)
}

# Parashikimi me metodën dhe horizontin e zgjedhur. ok = FALSE kur ARIMA s'mund të ndërtohet.
forecast_run <- function(dd, method, h, fits, progress = NULL) {
  if (!method %in% FORECAST_METHODS) return(list(ok = FALSE, msg = tr("fc.unknown_method")))

  y <- series_ts(dd)
  if (method != "arima") return(list(ok = TRUE, fc = forecast_method(y, method, h)))

  af <- forecast_arima_fit(dd, fits, progress)
  if (!isTRUE(af$ok)) return(af)
  list(ok = TRUE, fc = forecast_method(y, "arima", h, af$fit))
}

forecast_accuracy <- function(fc) {
  if (is.null(fc)) return(NULL)
  tryCatch(forecast::accuracy(fc), error = function(e) NULL)
}

# Tabela e saktësisë: ME, MAE, RMSE me njësinë e serisë, MAPE në %.
forecast_accuracy_table <- function(acc, series, meta) {
  labels <- c(tr("fc.me"), tr("fc.mae"), tr("fc.rmse"), tr("fc.mape"))
  as_table <- function(values) {
    out <- data.frame(labels, values, check.names = FALSE)
    names(out) <- c(tr("fc.col_metric"), tr("fc.col_value"))
    out
  }
  if (is.null(acc) || nrow(acc) == 0) return(as_table(rep("NA", 4)))

  row_name <- if ("Training set" %in% rownames(acc)) "Training set" else rownames(acc)[1]
  metrics <- c("ME", "MAE", "RMSE", "MAPE")
  vals <- setNames(rep(NA_real_, length(metrics)), metrics)
  for (mt in metrics) {
    if (mt %in% colnames(acc)) vals[mt] <- suppressWarnings(as.numeric(acc[row_name, mt]))
  }
  if (!is.finite(vals["MAPE"])) vals["MAPE"] <- NA_real_

  u <- var_meta(series, meta)$unit %||% ""
  with_unit <- function(txt) if (nzchar(u)) paste0(txt, " ", u) else txt

  as_table(c(
    with_unit(fmt_table_value(vals["ME"])),
    with_unit(fmt_table_value(vals["MAE"])),
    with_unit(fmt_table_value(vals["RMSE"])),
    if (is.na(vals["MAPE"])) "NA" else paste0(fmt_fixed(vals["MAPE"], digits = 2), " %")
  ))
}

# ---- Grafiku ------------------------------------------------------------------------

# Intervali i parë i forecast-it (80%): emri dhe kufijtë; NA kur mungon.
forecast_interval <- function(fc) {
  n <- length(fc$mean)
  lev <- NULL
  if (!is.null(fc$lower)) {
    cn <- colnames(fc$lower)
    if (!is.null(cn) && length(cn) >= 1) lev <- cn[1]
  }
  low <- up <- rep(NA_real_, n)
  if (!is.null(lev) && !is.null(fc$upper) && lev %in% colnames(fc$lower) && lev %in% colnames(fc$upper)) {
    low <- as.numeric(fc$lower[, lev])
    up  <- as.numeric(fc$upper[, lev])
  }
  list(level = lev, lower = low, upper = up)
}

# dd: seria e validuar; fc: objekti i forecast-it. Vija e vëzhguar (e bardhë), intervali
# si poligon i mbyllur dhe parashikimi (të kuq, B-04); radha e gjurmëve si te ggplotly.
forecast_plot <- function(dd, fc, method, series, meta) {
  sz <- glass_sizes(13)
  m  <- var_meta(series, meta)
  xlab <- time_axis_label(dd$Time)
  y  <- as.numeric(dd$y)
  mu <- as.numeric(fc$mean)
  n <- length(y); h <- length(mu)
  ft <- make_future_time(dd$Time, h)
  ci <- forecast_interval(fc)

  # V-21 a: vlerat e hover-it formatohen bashkë, si te faqet e tjera.
  vals <- fmt_unit(c(y, mu, ci$lower, ci$upper), series, meta)
  part <- function(k) vals[n + (k - 1) * h + seq_len(h)]
  lev_txt <- if (is.null(ci$level) || !nzchar(ci$level)) tr("fc.interval") else paste0(tr("fc.interval"), " ", ci$level)
  hover_obs <- paste0(xlab, ": ", fmt_time(dd$Time), "<br>", m$label, ": ", vals[seq_len(n)])
  hover_fc  <- paste0(xlab, ": ", fmt_time(ft), "<br>", tr("fc.hover_forecast"), ": ", part(1),
                      "<br>", lev_txt, ": [", part(2), " ; ", part(3), "]")

  with_frame <- function(tr) c(tr, list(frame = NA))
  tx <- as.numeric(ft)
  traces <- list(with_frame(line_trace(as.numeric(dd$Time), y, hover_obs, 1, GLASS_WHITE)))
  if (any(is.finite(ci$lower)) && any(is.finite(ci$upper))) {
    traces[[2]] <- list(
      x = c(tx, tx[h], rev(tx), tx[1]),
      y = c(ci$lower, ci$lower[h], rev(ci$upper), ci$lower[1]),
      text = "", type = "scatter", mode = "lines",
      line = list(width = 0.5 * PX_PER_MM, color = "transparent", dash = "solid"),
      fill = "toself", fillcolor = "rgba(255,59,48,0.12)",   # V-21 b: tejdukshmëria si më parë
      hoveron = "points", showlegend = FALSE, xaxis = "x", yaxis = "y", hoverinfo = "text", frame = NA
    )
  }
  traces[[length(traces) + 1]] <- with_frame(line_trace(tx, mu, hover_fc, 1.2, FORECAST_RED))

  grid <- gg_color("white", 0.12)
  all_time <- c(dd$Time, ft)
  xaxis <- modifyList(model_axis(gg_ticks(all_time, date = inherits(all_time, "Date")), xlab, sz, "y"),
                      list(gridcolor = grid))
  yaxis <- modifyList(model_axis(gg_ticks(c(y, mu, ci$lower, ci$upper), labels = function(z) fmt_by_series(z, for_axis = TRUE)),
                                 var_display_label(series, meta), sz, "x"),
                      list(gridcolor = grid))

  layout <- glass_layout(paste0("<b> ", tr("fc.plot_title", label = m$label, method = toupper(method)), " </b>"),
                         sz, xaxis, yaxis, margin = gg_margin(sz, xaxis, yaxis))
  layout$shapes <- list()
  layout$legend <- gg_legend(GLASS_WHITE, sz)
  glass_figure(traces, layout)
}

# ---- Moduli ------------------------------------------------------------------------

mod_forecast_server <- function(id, series, fits) {
  moduleServer(id, function(input, output, session) {
    pick_choice <- function(cur, choices, fallback) {
      if (!is.null(cur) && length(cur) == 1 && nzchar(cur) && cur %in% choices) cur else fallback
    }

    observeEvent(series(), {
      choices <- series()$value_cols
      if (length(choices) == 0) return()
      updateSelectInput(session, "series", choices = choices,
                        selected = pick_choice(isolate(input$series), choices, choices[1]))
    })

    # Seria e zgjedhur, vetëm kur i përket dataset-it aktual.
    sel <- reactive({
      s <- series()
      req(s, input$series, input$series %in% s$value_cols)
      input$series
    })

    # B-02: kufijtë rillogariten për çdo seri dhe çdo dataset; vlera ruhet brenda tyre.
    observeEvent(list(series(), input$series), {
      s <- series()
      req(s, input$series %in% s$value_cols)
      st <- h_slider_state(s$data, input$series, isolate(input$h))
      updateSliderInput(session, "h", label = st$label, min = st$min, max = st$max,
                        value = st$value, step = 1)
      if (st$enabled) shinyjs::enable("h") else shinyjs::disable("h")
    })

    # B-06: seria e pavlefshme ose konstante ndalon grafikun me validate(), me të njëjtin tekst.
    data <- reactive({
      x <- forecast_data(series()$data, sel())
      shiny::validate(shiny::need(isTRUE(x$ok), x$msg))
      x$dd
    })

    h_db <- shiny::debounce(reactive(input$h), millis = 350)
    h_now <- reactive({
      h <- suppressWarnings(as.integer(h_db() %||% input$h))
      if (length(h) != 1 || is.na(h) || h < 1) 1L else h
    })

    run <- reactive({
      req(input$method)
      progress <- function(f) shiny::withProgress(message = tr("fc.progress"), value = 0, f(shiny::incProgress))
      forecast_run(data(), input$method, h_now(), fits, progress)
    })

    acc <- reactive({
      r <- run()
      if (isTRUE(r$ok)) forecast_accuracy(r$fc) else NULL
    })

    output$plot <- renderPlotly({
      r <- run()
      shiny::validate(shiny::need(isTRUE(r$ok), r$msg))
      forecast_plot(data(), r$fc, input$method, sel(), series()$meta)
    })

    # V-17 d: paralajmërimi për h të madh shfaqet nën grafik, jo si njoftim.
    output$note <- renderText({
      if (isTRUE(run()$ok) && h_now() > floor(sum(!is.na(data()$y)) / 2)) tr("model.h_large") else ""
    })

    output$cap_plot <- renderText({
      req(input$method, input$h)
      tr("fc.cap_plot", method = toupper(input$method), label = var_meta(sel(), series()$meta)$label, h = input$h)
    })

    output$metrics <- renderUI({
      box <- function(...) div(class = "section-box", h4(tr("fc.acc_title")), ...)
      if (!isTRUE(run()$ok)) return(box(p(tr("fc.acc_no_model"))))
      if (is.null(acc())) return(box(p(tr("fc.acc_failed"))))
      box(tableOutput(session$ns("acc_tbl")))
    })

    output$acc_tbl <- renderTable(forecast_accuracy_table(acc(), sel(), series()$meta),
                                  striped = FALSE, bordered = TRUE, spacing = "s")
  })
}
