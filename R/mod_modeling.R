# Modelimi: krahasimi i parashikimeve ETS dhe ARIMA dhe saktësia në setin e trajnimit.
# Modelet vijnë nga model_store (P-07); grafiku me plot_ly direkt (V-08, plot_theme.R).
# Slider-i i horizontit rillogaritet për çdo seri (B-02).

mod_modeling_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "glass-divider"),

    div(
      class = "section-box",
      h3(tr("model.title")),
      p(tr("model.intro"))
    ),

    sidebarLayout(
      position = "left",

      sidebarPanel(
        selectInput(ns("series"), tr("model.series"), choices = character(0)),

        sliderInput(
          ns("h"),
          tr("model.h"),
          min = 1,
          max = 1,
          value = 1,
          step = 1
        )
      ),

      mainPanel(
        div(
          class = "section-box",
          h4(tr("model.plot_box")),
          div(
            class = "plot-wrap",
            anim_plotly_output(ns("plot"), height = "480px")
          ),
          tags$small(textOutput(ns("cap_plot"))),
          tags$small(textOutput(ns("note")))
        ),

        div(class = "glass-divider"),

        div(
          class = "section-box",
          h4(tr("model.acc_box")),
          div(
            class = "table-wrap",
            tableOutput(ns("acc_tbl"))
          )
        )
      )
    )
  )
}

# ---- Llogaritjet (funksione të pastra) ------------------------------------------

# ETS dhe ARIMA për serinë, nga cache-i `fits`. step(v): progresi (vetëm kur modelet
# s'janë ende në cache). ok = FALSE me mesazhin e validimit ose të dështimit.
model_fits <- function(d, series, fits, progress = NULL) {
  v <- validate_ts_ready(d, series, FREQ_POLICY, min_n = 20L)
  if (!isTRUE(v$ok)) return(list(ok = FALSE, msg = v$message %||% ts_msg("incomplete")))

  y <- series_ts(v$data)
  fit_both <- function(step = function(v) NULL) {
    step(0.2)
    e <- fits$get("ets", y)
    step(0.55)
    a <- fits$get("arima", y)
    step(0.95)
    list(ets = e, arima = a)
  }
  ff <- if (is.null(progress) || (fits$has("ets", y) && fits$has("arima", y))) fit_both() else progress(fit_both)

  if (is.null(ff$ets) || is.null(ff$arima)) return(list(ok = FALSE, msg = tr("model.fit_failed")))
  list(ok = TRUE, dd = v$data, fit_ets = ff$ets, fit_arima = ff$arima)
}

# Parashikimet me horizont h nga të dy modelet, me kohën e periudhave pasuese.
model_forecasts <- function(x, h) {
  list(
    time  = make_future_time(x$dd$Time, h),
    ets   = as.numeric(forecast::forecast(x$fit_ets,   h = h)$mean),
    arima = as.numeric(forecast::forecast(x$fit_arima, h = h)$mean)
  )
}

# Tabela e saktësisë: RMSE dhe MAE me njësinë e serisë, MAPE me 2 decimale.
model_accuracy_table <- function(x, series, meta) {
  col <- tr("model.col_model")
  if (!isTRUE(x$ok)) {
    out <- data.frame(c("ETS", "ARIMA"), RMSE = NA_character_, MAE = NA_character_,
                      MAPE = NA_character_, check.names = FALSE)
    names(out)[1] <- col
    return(out)
  }

  u <- var_meta(series, meta)$unit %||% ""
  # B-23 (V-25 a): për seri konstante forecast::ets() kthen objekt vetëm "ets", pa metodë
  # accuracy(); rreshti i atij modeli del NA, si kur modeli mungon.
  model_acc <- function(fit) tryCatch(training_accuracy(forecast::accuracy(fit)), error = function(e) NULL)
  acc <- list(model_acc(x$fit_ets), model_acc(x$fit_arima))
  missing <- vapply(acc, is.null, logical(1))
  metric <- function(name) vapply(acc, function(a) if (is.null(a)) NA_real_ else as.numeric(a[[name]]), numeric(1))
  with_unit <- function(v) {
    txt <- fmt_table_value(v)
    if (nzchar(u)) txt <- paste0(txt, " ", u)
    ifelse(missing, NA_character_, txt)
  }

  out <- data.frame(c("ETS", "ARIMA"), RMSE = with_unit(metric("RMSE")), MAE = with_unit(metric("MAE")),
                    MAPE = ifelse(missing, NA_character_, fmt_fixed(metric("MAPE"), digits = 2)),
                    check.names = FALSE)
  names(out)[1] <- col
  out
}

# ---- Grafiku ------------------------------------------------------------------------

# Boshtet e theme_minimal(13) me grid-in e layout()-it të vjetër (0.15).
model_axis <- function(ticks, title, sz, anchor) {
  modifyList(
    glass_axis(ticks, title, sz, gridwidth = 13 / 22 * PX_PER_PT, anchor = anchor),
    list(tickcolor = NA, linecolor = NA, nticks = NA)
  )
}

# x: rezultati i model_fits(); fc: i model_forecasts(); time: koha e plotë (emri i boshtit).
# Tri vija me legjendë: ARIMA, ETS, e vëzhguara (radha e ggplotly-t të vjetër).
model_compare_plot <- function(x, fc, series, time, meta) {
  sz <- glass_sizes(13)
  m  <- var_meta(series, meta)
  xlab <- time_axis_label(time)
  y  <- as.numeric(x$dd$y)

  # Hover-i formatohet mbi të gjitha vlerat bashkë, si te kodi i vjetër.
  vals <- fmt_unit(c(y, fc$ets, fc$arima), series, meta)
  n <- length(y); h <- length(fc$ets)
  hover <- function(t, who, v) paste0(xlab, ": ", fmt_time(t), "<br>", who, ": ", v)
  observed <- tr("model.observed")

  trace <- function(t, v, txt, name, color) {
    modifyList(line_trace(as.numeric(t), v, txt, 1.1, color),
               list(name = name, legendgroup = name, showlegend = TRUE, frame = NA))
  }
  traces <- list(
    trace(fc$time, fc$arima, hover(fc$time, "ARIMA", vals[n + h + seq_len(h)]), "ARIMA", "rgba(255,59,48,1)"),
    trace(fc$time, fc$ets, hover(fc$time, "ETS", vals[n + seq_len(h)]), "ETS", "rgba(10,132,255,1)"),
    trace(x$dd$Time, y, hover(x$dd$Time, observed, vals[seq_len(n)]), observed, GLASS_WHITE)
  )

  all_time <- c(x$dd$Time, fc$time)
  xaxis <- model_axis(gg_ticks(all_time, date = inherits(all_time, "Date")), xlab, sz, "y")
  yaxis <- model_axis(gg_ticks(c(y, fc$ets, fc$arima), labels = function(z) fmt_by_series(z, for_axis = TRUE)),
                      var_display_label(series, meta), sz, "x")

  layout <- glass_layout(paste0("<b> ", tr("model.plot_title", label = m$label), " </b>"), sz, xaxis, yaxis,
                         margin = gg_margin(sz, xaxis, yaxis))
  layout$shapes <- list()
  layout$showlegend <- TRUE
  # Titulli i legjendës ("Tipi", emri i kolonës te ggplot) kishte madhësi 0: nuk shfaqet.
  layout$legend <- list(bgcolor = "transparent", bordercolor = "transparent", borderwidth = 13 / 22 * PX_PER_MM,
                        font = list(color = GLASS_WHITE, family = "", size = sz$tick),
                        title = list(text = "Tipi", font = list(color = NA, family = NA, size = 0)))
  glass_figure(traces, layout)
}

# ---- Moduli ------------------------------------------------------------------------

mod_modeling_server <- function(id, series, fits) {
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

    # Modelet nuk varen nga h: ndryshimi i horizontit vetëm rillogarit parashikimin (P-07).
    fitted <- reactive({
      progress <- function(f) shiny::withProgress(message = tr("model.progress"), value = 0, f(shiny::incProgress))
      model_fits(series()$data, sel(), fits, progress)
    })

    h_db <- shiny::debounce(reactive(input$h), millis = 350)
    h_now <- reactive({
      h <- suppressWarnings(as.integer(h_db() %||% input$h))
      if (length(h) != 1 || is.na(h) || h < 1) 1L else h
    })

    output$plot <- renderPlotly({
      x <- fitted()
      shiny::validate(shiny::need(isTRUE(x$ok), x$msg))
      model_compare_plot(x, model_forecasts(x, h_now()), sel(), series()$data$Time, series()$meta)
    })

    # V-17 d: paralajmërimi për h të madh shfaqet nën grafik, jo si njoftim.
    output$note <- renderText({
      x <- fitted()
      if (isTRUE(x$ok) && h_now() > floor(nrow(x$dd) / 2)) tr("model.h_large") else ""
    })

    output$cap_plot <- renderText({
      req(input$h)
      tr("model.cap_plot", label = var_meta(sel(), series()$meta)$label, h = input$h)
    })

    output$acc_tbl <- renderTable(model_accuracy_table(fitted(), sel(), series()$meta))
  })
}
