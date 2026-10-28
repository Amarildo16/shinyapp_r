# I përkohshëm (zhduket në Fazën 5). Merr series() dhe active() nga app.R (V-04):
# koha, seritë dhe dublikatat/frekuenca vijnë të gatshme nga prepare_series().
# Llogaritjet jetojnë te stats_eda.R / ts_models.R; modelet vijnë nga `fits` (model_store).
server_plots <- function(input, output, session, series, active, fits) {
  need     <- shiny::need
  validate <- shiny::validate

  value_cols <- reactive({
    req(series())
    series()$value_cols
  })

  meta <- reactive({
    req(series())
    series()$meta
  })

  df_dyn <- reactive({
    req(series())
    series()$data
  })

  # =========================================================
  # Slider DINAMIK: model_h (Modelimi) + h (Parashikimi)
  # =========================================================


  .slider_once <- reactiveValues(model_h = FALSE, h = FALSE)

  # priority = 1: rivendoset para observer-ave të slider-ave, si me df() e vjetër.
  observeEvent(active(), {
    .slider_once$model_h <- FALSE
    .slider_once$h       <- FALSE
  }, ignoreInit = TRUE, priority = 1)

  # -------- model_h dinamik (Modelimi) --------
  observeEvent(list(df_dyn(), input$model_series), {
    d0 <- df_dyn()
    if (is.null(d0) || nrow(d0) == 0) return()

    ser <- input$model_series %||% NULL
    if (is.null(ser) || !nzchar(ser) || !(ser %in% names(d0))) return()

    y <- d0[[ser]]
    n_real <- sum(!is.na(y))

    b <- h_bounds(n_real, d0$Time)
    unit <- time_step_unit(d0$Time)

    cur <- isolate(input$model_h)
    if (is.null(cur) || is.na(cur)) cur <- min(5L, b$max)
    val <- max(b$min, min(as.integer(cur), b$max))

    if (isTRUE(.slider_once$model_h)) return()
      updateSliderInput(
        session, "model_h",
        label = paste0("Horizonti i parashikimit (", unit, ")"),
        min = b$min,
        max = b$max,
        value = val,
        step = 1
      )
    .slider_once$model_h <- TRUE

    if (n_real < 2L) shinyjs::disable("model_h") else shinyjs::enable("model_h")
  }, ignoreInit = FALSE)


  # -------- h dinamik (Parashikimi) --------
  observeEvent(list(df_dyn(), input$forecast_series), {
    d0 <- df_dyn()
    if (is.null(d0) || nrow(d0) == 0) return()

    ser <- input$forecast_series %||% NULL
    if (is.null(ser) || !nzchar(ser) || !(ser %in% names(d0))) return()

    y <- d0[[ser]]
    n_real <- sum(!is.na(y))

    b <- h_bounds(n_real, d0$Time)
    unit <- time_step_unit(d0$Time)

    cur <- isolate(input$h)
    if (is.null(cur) || is.na(cur)) cur <- min(5L, b$max)
    val <- max(b$min, min(as.integer(cur), b$max))

    if (isTRUE(.slider_once$h)) return()
      updateSliderInput(
        session, "h",
        label = paste0("Horizonti i parashikimit (", unit, ")"),
        min = b$min,
        max = b$max,
        value = val,
        step = 1
      )
    .slider_once$h <- TRUE

    if (n_real < 2L) shinyjs::disable("h") else shinyjs::enable("h")
  }, ignoreInit = FALSE)


  # =========================
  # Captions
  # =========================

  output$cap_model_plot <- renderText({
    req(input$model_series, input$model_h)
    m <- var_meta(input$model_series, meta())
    paste0("Krahasim ETS vs ARIMA për ", m$label, " (h = ", input$model_h, ").")
  })

  output$cap_forecast_plot <- renderText({
    req(input$forecast_series, input$method, input$h)
    m <- var_meta(input$forecast_series, meta())
    paste0("Parashikim me metodën ", toupper(input$method), " për ", m$label, " (h = ", input$h, ").")
  })

  
  # =========================
  # Modelimi – ETS & ARIMA
  # =========================

  model_h_db <- shiny::debounce(reactive({input$model_h}), millis = 350)

  .model_fits <- reactive({
    req(df_dyn(), input$model_series)

    d0 <- df_dyn()

    ts_ok <- validate_ts_ready(d0, input$model_series, FREQ_POLICY, min_n = 20L)
    if (!isTRUE(ts_ok$ok)) {
      return(list(ok = FALSE, msg = ts_ok$message %||% ts_msg("incomplete")))
    }

    dd <- ts_ok$data

    n <- nrow(dd)
    if (n < 20) {
      return(list(ok = FALSE, msg = "Për ETS/ARIMA rekomandohen ≥ 20 pika reale (jo-NA)."))
    }

    y_raw <- as.numeric(dd$y)
    y_mod <- series_ts(dd)

    # Progresi shfaqet vetëm kur modelet nuk janë ende në cache (si më parë).
    fit_both <- function(step = function(v) NULL) {
      step(0.2)
      e <- fits$get("ets", y_mod)
      step(0.55)
      a <- fits$get("arima", y_mod)
      step(0.95)
      list(ets = e, arima = a)
    }
    ff <- if (fits$has("ets", y_mod) && fits$has("arima", y_mod)) {
      fit_both()
    } else {
      shiny::withProgress(message = "Duke ndërtu ETS & ARIMA...", value = 0,
                          fit_both(shiny::incProgress))
    }

    if (is.null(ff$ets) || is.null(ff$arima)) {
      return(list(ok = FALSE, msg = "Modelimi dështoi për ETS ose ARIMA (kontrollo NA / seri konstante / freq)."))
    }

    list(
      ok = TRUE,
      dd = dd,
      y_raw = y_raw,
      fit_ets = ff$ets,
      fit_arima = ff$arima,
      xlab = time_axis_label(d0$Time),
      m = var_meta(input$model_series, meta())
    )
  })

  output$model_plot <- renderPlotly({
    req(df_dyn(), input$model_series)

    x <- .model_fits()
    validate(need(!is.null(x) && isTRUE(x$ok), x$msg %||% "Modelimi s’u krijua."))

    h0 <- model_h_db()
    if (is.null(h0)) h0 <- input$model_h
    h <- as.integer(h0)
    if (is.na(h) || h < 1) h <- 1

    n <- nrow(x$dd)
    if (h > floor(n/2)) {
      showNotification("Kujdes: h është i madh krahasuar me të dhënat (h > n/2).", type = "message")
    }

    fc_ets   <- forecast::forecast(x$fit_ets,   h = h)
    fc_arima <- forecast::forecast(x$fit_arima, h = h)

    future_time <- make_future_time(x$dd$Time, h)

    obs_df <- data.frame(
      Time  = x$dd$Time,
      Vlera = x$y_raw,
      Tipi  = "Vëzhguar",
      stringsAsFactors = FALSE
    )

    ets_df <- data.frame(
      Time  = future_time,
      Vlera = as.numeric(fc_ets$mean),
      Tipi  = "ETS",
      stringsAsFactors = FALSE
    )

    arima_df <- data.frame(
      Time  = future_time,
      Vlera = as.numeric(fc_arima$mean),
      Tipi  = "ARIMA",
      stringsAsFactors = FALSE
    )

    plot_df <- rbind(obs_df, ets_df, arima_df) %>%
      dplyr::mutate(
        hover = paste0(
          x$xlab, ": ", fmt_time(Time),
          "<br>", Tipi, ": ", fmt_unit(Vlera, input$model_series, meta())
        )
      )

    p <- ggplot(plot_df, aes(x = Time, y = Vlera, color = Tipi, group = Tipi)) +
      geom_line(linewidth = 1.1) +
      scale_color_manual(values = c(
        "Vëzhguar" = "white",
        "ETS"      = "#0a84ff",
        "ARIMA"    = "#ff3b30"
      )) +
      labs(
        title = paste0("Krahasimi i parashikimeve – ", x$m$label),
        x = x$xlab,
        y = if (nzchar(x$m$unit)) paste0(x$m$label, " (", x$m$unit, ")") else x$m$label
      ) +
      scale_y_continuous(labels = function(z) fmt_by_series(z, for_axis = TRUE)) +
      theme_minimal(base_size = 13) +
      theme(
        plot.background   = element_rect(fill = "transparent", color = NA),
        panel.background  = element_rect(fill = "transparent", color = NA),
        panel.grid.major  = element_line(color = scales::alpha("white", 0.18)),
        panel.grid.minor  = element_blank(),
        text              = element_text(color = "white"),
        plot.title        = element_text(color = "white", face = "bold"),
        axis.title        = element_text(color = "white"),
        axis.text         = element_text(color = "white"),
        legend.title      = element_blank(),
        legend.text       = element_text(color = "white"),
        legend.background = element_rect(fill = "transparent", color = NA),
        legend.key        = element_rect(fill = "transparent", color = NA)
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        font  = list(color = "white"),
        xaxis = list(gridcolor = "rgba(255,255,255,0.15)"),
        yaxis = list(gridcolor = "rgba(255,255,255,0.15)")
      )

    by_type <- split(plot_df$hover, plot_df$Tipi)
    for (i in seq_along(pl$x$data)) {
      nm <- pl$x$data[[i]]$name %||% ""
      if (nm %in% names(by_type)) {
        pl$x$data[[i]]$text <- by_type[[nm]]
        pl$x$data[[i]]$hoverinfo <- "text"
      }
    }

    plotly_cfg(pl)
  })

  output$model_acc_tbl <- renderTable({
    req(df_dyn(), input$model_series)

    x <- .model_fits()
    if (is.null(x) || !isTRUE(x$ok)) {
      return(data.frame(
        Modeli = c("ETS", "ARIMA"),
        RMSE = NA_character_,
        MAE  = NA_character_,
        MAPE = NA_character_,
        check.names = FALSE
      ))
    }

    m <- x$m

    acc_ets   <- training_accuracy(forecast::accuracy(x$fit_ets))
    acc_arima <- training_accuracy(forecast::accuracy(x$fit_arima))

    get_metric <- function(acc, metric) as.numeric(acc[[metric]])

    add_unit <- function(txt) {
      u <- m$unit %||% ""
      if (nzchar(u)) paste0(txt, " ", u) else txt
    }

    rmse_vals <- c(get_metric(acc_ets, "RMSE"), get_metric(acc_arima, "RMSE"))
    mae_vals  <- c(get_metric(acc_ets, "MAE"),  get_metric(acc_arima, "MAE"))
    mape_vals <- c(get_metric(acc_ets, "MAPE"), get_metric(acc_arima, "MAPE"))

    data.frame(
      Modeli = c("ETS", "ARIMA"),
      RMSE   = vapply(rmse_vals, function(v) add_unit(fmt_table_value(v)), character(1)),
      MAE    = vapply(mae_vals,  function(v) add_unit(fmt_table_value(v)), character(1)),
      MAPE   = fmt_fixed(mape_vals, digits = 2),
      check.names = FALSE
    )
  })

  # =========================================================
  # Parashikimi
  # =========================================================

  series_dat <- reactive({
    req(df_dyn(), input$forecast_series)

    d0 <- df_dyn()

    if (!(input$forecast_series %in% names(d0))) {
      showNotification("Seria e zgjedhur s’gjendet në dataset.", type = "error")
      return(NULL)
    }

    ts_ok <- validate_ts_ready(d0, input$forecast_series, FREQ_POLICY, min_n = 2L)
    validate(need(isTRUE(ts_ok$ok), ts_ok$message))

    dd <- ts_ok$data

    if (stats::sd(dd$y, na.rm = TRUE) < 1e-12) {
      showNotification("Seria është (pothuaj) konstante — parashikimi s’ka kuptim.", type = "warning")
      return(NULL)
    }

    dd
  })

  fc_ts <- reactive({
    req(series_dat())
    series_ts(series_dat())
  })

  h_db <- shiny::debounce(reactive({input$h}), millis = 350)

  arima_fit <- reactive({
    req(fc_ts(), series_dat())

    if ((input$method %||% "") != "arima") return(NULL)

    y  <- fc_ts()
    dd <- series_dat()

    n_real <- sum(!is.na(dd$y))
    if (n_real < 30) {
      return(list(ok = FALSE, msg = "Për ARIMA rekomandohen ≥ 30 pika reale. Zgjidh SES/Holt ose shto të dhëna."))
    }

    # I njëjti model si te Modelimi kur seria është e njëjta (P-07).
    fit <- if (fits$has("arima", y)) {
      fits$get("arima", y)
    } else {
      shiny::withProgress(message = "Duke ndërtu ARIMA...", value = 0, {
        shiny::incProgress(0.2)
        f <- fits$get("arima", y)
        shiny::incProgress(0.95)
        f
      })
    }

    if (is.null(fit)) {
      return(list(ok = FALSE, msg = "ARIMA dështoi (kontrollo të dhënat / missing / seri konstante / freq)."))
    }

    list(ok = TRUE, fit = fit)
  })

  forecast_obj <- reactive({
    req(fc_ts(), series_dat(), input$method)

    y  <- fc_ts()
    dd <- series_dat()

    h0 <- h_db()
    if (is.null(h0)) h0 <- input$h
    h <- as.integer(h0)
    if (is.na(h) || h < 1) h <- 1

    n_real <- sum(!is.na(dd$y))
    if (h > floor(n_real / 2)) {
      showNotification("Kujdes: h është i madh krahasuar me të dhënat (h > n/2).", type = "message")
    }

    if (!(input$method %in% c("ses", "holt", "arima"))) {
      showNotification("Metodë e panjohur. Lejohen: ses, holt, arima.", type = "error")
      return(NULL)
    }

    if (input$method != "arima") return(forecast_method(y, input$method, h))

    af <- arima_fit()
    if (is.null(af) || !isTRUE(af$ok)) {
      msg <- if (is.null(af)) "ARIMA s’u krijua." else (af$msg %||% "ARIMA s’u krijua.")
      showNotification(msg, type="error")
      return(NULL)
    }

    forecast_method(y, "arima", h, af$fit)
  })

  # =========================================================
  # Grafiku i parashikimit
  # =========================================================

  output$forecast_plot <- renderPlotly({
    req(series_dat(), input$forecast_series, input$method)

    dd <- series_dat()
    fc <- forecast_obj()
    validate(need(!is.null(fc), "Nuk u krijua parashikimi (kontrollo kushtet / të dhënat)."))

    m  <- var_meta(input$forecast_series, meta())
    xlab <- time_axis_label(dd$Time)

    obs_df <- data.frame(
      Time  = dd$Time,
      Vlera = as.numeric(dd$y),
      stringsAsFactors = FALSE
    )

    h0 <- h_db()
    if (is.null(h0)) h0 <- input$h
    h <- as.integer(h0)
    if (is.na(h) || h < 1) h <- 1

    fut_time <- make_future_time(obs_df$Time, h)

    fc_mean <- as.numeric(fc$mean)

    lev <- NULL
    if (!is.null(fc$lower)) {
      cn <- colnames(fc$lower)
      if (!is.null(cn) && length(cn) >= 1) lev <- cn[1]
    }

    low <- up <- rep(NA_real_, length(fc_mean))
    if (!is.null(lev) && !is.null(fc$lower) && !is.null(fc$upper) &&
        lev %in% colnames(fc$lower) && lev %in% colnames(fc$upper)) {
      low <- as.numeric(fc$lower[, lev])
      up  <- as.numeric(fc$upper[, lev])
    }

    fc_df <- data.frame(
      Time      = fut_time,
      Mesatarja = fc_mean,
      PoshtëCI  = low,
      SipërCI   = up,
      stringsAsFactors = FALSE
    )

    obs_df$hover <- vapply(seq_len(nrow(obs_df)), function(i) {
      paste0(
        xlab, ": ", fmt_time(obs_df$Time[i]),
        "<br>", m$label, ": ", fmt_unit(obs_df$Vlera[i], input$forecast_series, meta())
      )
    }, character(1))

    lev_txt <- if (is.null(lev) || !nzchar(lev)) "Intervali" else paste0("Intervali ", lev)

    fc_df$hover <- vapply(seq_len(nrow(fc_df)), function(i) {
      paste0(
        xlab, ": ", fmt_time(fc_df$Time[i]),
        "<br>Parashikimi: ", fmt_unit(fc_df$Mesatarja[i], input$forecast_series, meta()),
        "<br>", lev_txt, ": [",
        fmt_unit(fc_df$PoshtëCI[i], input$forecast_series, meta()),
        " ; ",
        fmt_unit(fc_df$SipërCI[i], input$forecast_series, meta()),
        "]"
      )
    }, character(1))

    p <- ggplot() +
      geom_line(
        data = obs_df,
        aes(x = Time, y = Vlera),
        color = "white",
        linewidth = 1
      ) +
      geom_ribbon(
        data = fc_df,
        aes(x = Time, ymin = PoshtëCI, ymax = SipërCI),
        fill = "white",
        alpha = 0.12
      ) +
      geom_line(
        data = fc_df,
        aes(x = Time, y = Mesatarja),
        color = "white",
        linewidth = 1.2,
        linetype = "solid"
      ) +
      labs(
        title = paste0("Parashikimi – ", m$label, " (", toupper(input$method), ")"),
        x = xlab,
        y = if (nzchar(m$unit)) paste0(m$label, " (", m$unit, ")") else m$label
      ) +
      scale_y_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
      theme_minimal(base_size = 13) +
      theme(
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = scales::alpha("white", 0.12)),
        panel.grid.minor = element_blank(),
        text        = element_text(color = "white"),
        plot.title  = element_text(color = "white", face = "bold"),
        axis.title  = element_text(color = "white"),
        axis.text   = element_text(color = "white")
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        font = list(color = "white")
      )

    line_idx <- find_traces(pl, function(tr) {
      (tr$type %||% "") == "scatter" && grepl("lines", tr$mode %||% "") && is.null(tr$fill)
    })

    if (length(line_idx) > 0) {
      for (i in line_idx) {
        nx <- length(pl$x$data[[i]]$x %||% list())
        if (nx == nrow(obs_df)) {
          pl <- set_trace_text(pl, i, obs_df$hover)
        } else if (nx == nrow(fc_df)) {
          pl <- set_trace_text(pl, i, fc_df$hover)
        }
      }
    }

    plotly_cfg(pl)
  })

  # =========================================================
  # Saktësia e parashikimit
  # =========================================================

  acc_obj <- reactive({
    req(input$forecast_series)

    fc <- forecast_obj()
    if (is.null(fc)) return(NULL)

    tryCatch(
      forecast::accuracy(fc),
      error = function(e) NULL
    )
  })

  output$forecast_metrics <- renderUI({
    req(input$forecast_series)

    fc  <- forecast_obj()
    acc <- acc_obj()

    if (is.null(fc)) {
      return(div(
        class = "section-box",
        h4("Saktësia në setin e trajnimit"),
        p("Nuk u llogarit saktësia sepse modeli nuk u krijua. Shkak i mundshëm: seri shumë e shkurtër, shumë NA, seri konstante, ose ARIMA e refuzuar nga kushtet.")
      ))
    }

    if (is.null(acc)) {
      return(div(
        class = "section-box",
        h4("Saktësia në setin e trajnimit"),
        p("Saktësia nuk u llogarit. Shkak i mundshëm: seri shumë e shkurtër, shumë NA, seri konstante, ose model i dështuar.")
      ))
    }

    div(
      class = "section-box",
      h4("Saktësia në setin e trajnimit"),
      tableOutput("acc_tbl")
    )
  })

  output$acc_tbl <- renderTable({
    req(input$forecast_series)

    acc <- acc_obj()

    if (is.null(acc) || nrow(acc) == 0) {
      return(data.frame(
        Treguesi = c(
          "Gabimi mesatar (ME)",
          "Gabimi mesatar absolut (MAE)",
          "Rrënja e gabimit mesatar katror (RMSE)",
          "Gabimi mesatar absolut përqindor (MAPE)"
        ),
        Vlera = rep("NA", 4),
        check.names = FALSE
      ))
    }

    row_name <- if ("Training set" %in% rownames(acc)) "Training set" else rownames(acc)[1]

    metrics <- c("ME", "MAE", "RMSE", "MAPE")
    vals <- setNames(rep(NA_real_, length(metrics)), metrics)

    for (mt in metrics) {
      if (mt %in% colnames(acc)) {
        vals[mt] <- suppressWarnings(as.numeric(acc[row_name, mt]))
      }
    }

    if (!is.finite(vals["MAPE"])) vals["MAPE"] <- NA_real_

    m  <- var_meta(input$forecast_series, meta())
    u  <- m$unit %||% ""
    add_unit <- function(x_chr) if (nzchar(u)) paste0(x_chr, " ", u) else x_chr

    data.frame(
      Treguesi = c(
        "Gabimi mesatar (ME)",
        "Gabimi mesatar absolut (MAE)",
        "Rrënja e gabimit mesatar katror (RMSE)",
        "Gabimi mesatar absolut përqindor (MAPE)"
      ),
      Vlera = c(
        add_unit(fmt_table_value(vals["ME"])),
        add_unit(fmt_table_value(vals["MAE"])),
        add_unit(fmt_table_value(vals["RMSE"])),
        if (is.na(vals["MAPE"])) "NA" else paste0(fmt_fixed(vals["MAPE"], digits = 2), " %")
      ),
      check.names = FALSE
    )
  }, striped = FALSE, bordered = TRUE, spacing = "s")
}
