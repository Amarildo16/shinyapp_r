server_plots <- function(input, output, session, df) {
  need     <- shiny::need
  validate <- shiny::validate
  # =========================================================
  # 0) Dynamic selectors
  # =========================================================

  time_col <- reactive({
    req(df())
    nm <- names(df())
    req(length(nm) > 0)

    tc <- input$data_time_col %||% NULL
    if (!is.null(tc) && tc %in% nm) return(tc)

    if ("Year" %in% nm) return("Year")

    cand <- tryCatch(detect_time_candidates(df()), error = function(e) data.frame(col = nm, score = 0))
    best <- cand$col[1] %||% NULL
    if (is.null(best) || is.na(best) || !(best %in% nm)) best <- nm[1]
    best
  })

  value_cols <- reactive({
    req(df())
    nm <- names(df())

    vc <- input$data_value_cols %||% NULL
    if (!is.null(vc)) {
      vc <- vc[vc %in% nm]
      if (length(vc) > 0) return(vc)
    }

    d <- df()
    tc <- time_col()

    cols <- setdiff(names(d), tc)

    num_candidates <- cols[vapply(d[cols], function(x) {
      xn <- to_numeric_safe(x)
      mean(!is.na(xn)) >= 0.70
    }, logical(1))]

    num_candidates
  })

  meta <- reactive({
    vc <- value_cols()
    if (is.null(vc) || length(vc) == 0) return(list())
    build_meta(vc)
  })

  df_dyn <- reactive({
    req(df(), time_col())
    d <- df()

    vc <- value_cols()
    req(length(vc) > 0)

    for (v in vc) d[[v]] <- to_numeric_safe(d[[v]])

    d <- make_df_dyn(d, time_col())
    d <- d[, c("Time", vc), drop = FALSE]
    dup <- input$data_dup %||% "mean"
    d <- apply_dup_policy(d, vc = vc, method = dup)
    fr <- input$data_freq %||% "auto"
    d <- apply_freq_policy(d, freq = fr, vc = vc)

    d
  })

  # =========================================================
  # Slider DINAMIK: roll_k (EDA) + model_h + h (Forecast)
  # =========================================================


  .h_step <- function(Time) {
    tt <- Time[!is.na(Time)]
    if (length(tt) < 2) return("period")

    info <- tryCatch(infer_step_from_time(tt), error = function(e) NULL)
    if (!is.null(info) && identical(info$type, "date")) {
      return(info$step)
    }

    if (is.numeric(tt) && all(tt >= 1500 & tt <= 3000, na.rm = TRUE)) return("year")

    "period"
  }

  .h_unit <- function(Time) {
    step <- .h_step(Time)
    switch(step,
      year    = "vite",
      quarter = "tremujor",
      month   = "muaj",
      week    = "javë",
      day     = "ditë",
      "periudha"
    )
  }

  .h_cap_by_step <- function(step) {
    switch(step,
      day     = 90L,
      week    = 26L,
      month   = 24L,
      quarter = 12L,
      year    = 10L,
      120L
    )
  }

  .h_bounds <- function(n_real, Time) {
    n_real <- as.integer(n_real)
    if (is.na(n_real) || n_real < 2L) return(list(min = 1L, max = 1L, step = "period"))

    step <- .h_step(Time)
    cap  <- .h_cap_by_step(step)

    hmax <- min(as.integer(n_real - 1L), cap)
    hmax <- max(1L, hmax)

    hmin <- if (hmax <= 8L) 2L else 1L
    hmin <- min(hmin, hmax)

    list(min = hmin, max = hmax, step = step)
  }

  .roll_cap_by_step <- function(step) {
    switch(step,
      day     = 30L,
      week    = 12L,
      month   = 12L,
      quarter = 8L,
      year    = 5L,
      60L
    )
  }

  .slider_once <- reactiveValues(roll_k = FALSE, model_h = FALSE, h = FALSE)

  observeEvent(df(), {
    .slider_once$roll_k  <- FALSE
    .slider_once$model_h <- FALSE
    .slider_once$h       <- FALSE
  }, ignoreInit = TRUE)

  observeEvent(list(df_dyn(), input$eda_series), {
    req(df_dyn(), input$eda_series)

    d0 <- df_dyn()
    if (is.null(d0) || nrow(d0) == 0) return()
    if (!(input$eda_series %in% names(d0))) return()

    y <- d0[[input$eda_series]]
    n_non_na <- sum(!is.na(y))

    step <- .h_step(d0$Time)
    unit <- .h_unit(d0$Time)

    k_min <- 3L

    capk <- .roll_cap_by_step(step)
    k_max_raw <- if (is.finite(n_non_na) && n_non_na >= 2L) as.integer(n_non_na - 1L) else k_min

    k_max <- min(k_max_raw, capk, max(k_min, as.integer(floor(n_non_na / 2))))
    k_max <- max(k_min, k_max)

    cur <- isolate(input$roll_k)
    if (is.null(cur) || is.na(cur)) cur <- min(5L, k_max)
    cur <- as.integer(cur)
    val <- max(k_min, min(cur, k_max))

    if (isTRUE(.slider_once$roll_k)) return()
      updateSliderInput(
        session,
        "roll_k",
        label = paste0("Dritarja lëvizëse (", unit, ")"),
        min = k_min,
        max = k_max,
        value = val,
        step = 1
      )
    .slider_once$roll_k <- TRUE

    if (n_non_na < 3) shinyjs::disable("roll_k") else shinyjs::enable("roll_k")
  }, ignoreInit = FALSE)


  # -------- model_h dinamik (Modelimi) --------
  observeEvent(list(df_dyn(), input$model_series, input$data_freq), {
    d0 <- df_dyn()
    if (is.null(d0) || nrow(d0) == 0) return()

    ser <- input$model_series %||% NULL
    if (is.null(ser) || !nzchar(ser) || !(ser %in% names(d0))) return()

    y <- d0[[ser]]
    n_real <- sum(!is.na(y))

    b <- .h_bounds(n_real, d0$Time)
    unit <- .h_unit(d0$Time)

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
  observeEvent(list(df_dyn(), input$forecast_series, input$data_freq), {
    d0 <- df_dyn()
    if (is.null(d0) || nrow(d0) == 0) return()

    ser <- input$forecast_series %||% NULL
    if (is.null(ser) || !nzchar(ser) || !(ser %in% names(d0))) return()

    y <- d0[[ser]]
    n_real <- sum(!is.na(y))

    b <- .h_bounds(n_real, d0$Time)
    unit <- .h_unit(d0$Time)

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


  time_range_txt <- reactive({
    req(df_dyn())
    tt <- df_dyn()$Time
    rng <- range(tt, na.rm = TRUE)
    paste0(fmt_time(rng[1]), " – ", fmt_time(rng[2]))
  })

  n_series_txt <- reactive({
    paste0(length(value_cols()))
  })

  # =========================================================
  # 1) Tabela – Përmbledhje
  # =========================================================

  output$data_info_tbl <- renderTable({
    req(df_dyn())

    d  <- df_dyn()
    tt <- d$Time

    data.frame(
      Element = c(
        paste0(time_axis_label(tt), " fillestare"),
        paste0(time_axis_label(tt), " përfundimtare"),
        "Numri i vrojtimeve",
        "Numri i serive numerike",
        "Burimi i të dhënave"
      ),
      Vlera = c(
        fmt_time(min(tt, na.rm = TRUE)),
        fmt_time(max(tt, na.rm = TRUE)),
        as.character(nrow(d)),
        n_series_txt(),
        input$data_source %||% "Përdoruesi (dataset i ngarkuar)"
      ),
      check.names = FALSE
    )
  })

  # =========================================================
  # 2) Lista e variablave
  # =========================================================

  output$variables_tbl <- renderTable({
    req(value_cols())

    vc <- value_cols()

    data.frame(
      Variabla = vapply(vc, function(v) {
        m <- var_meta(v, meta())
        if (nzchar(m$unit)) paste0(m$label, " (", m$unit, ")")
        else m$label
      }, character(1)),
      Përshkrimi = rep("Seri numerike e ngarkuar nga përdoruesi.", length(vc)),
      check.names = FALSE
    )
  })

  # =========================================================
  # 3) Tabela statistikore
  # =========================================================

  output$summary_tbl <- renderTable({
    req(df_dyn(), value_cols())

    d  <- df_dyn()
    vc <- value_cols()

    if (is.null(vc) || length(vc) == 0) {
      return(data.frame(Mesazh = "Zgjidh të paktën 1 seri numerike.", check.names = FALSE))
    }

    X <- setNames(lapply(vc, function(v) d[[v]]), vc)

    safe_stat <- function(x, fun) {
      x <- x[!is.na(x)]
      if (length(x) == 0) return(NA_real_)
      fun(x)
    }

    safe_sd <- function(x) {
      x <- x[!is.na(x)]
      if (length(x) < 2) return(NA_real_)
      stats::sd(x)
    }

    out <- data.frame(
      Variabla = vc,
      Mesatarja = vapply(vc, function(v) safe_stat(X[[v]], base::mean), numeric(1)),
      `Devijimi standard` = vapply(vc, function(v) safe_sd(X[[v]]), numeric(1)),
      Minimumi = vapply(vc, function(v) safe_stat(X[[v]], base::min), numeric(1)),
      Maksimumi = vapply(vc, function(v) safe_stat(X[[v]], base::max), numeric(1)),
      `N (jo-NA)` = vapply(vc, function(v) sum(!is.na(X[[v]])), integer(1)),
      `Missing %` = vapply(vc, function(v) round(100 * mean(is.na(X[[v]])), 2), numeric(1)),
      check.names = FALSE
    )

    out$Variabla <- vapply(vc, function(v) {
      m <- var_meta(v, meta())
      if (!is.null(m$unit) && nzchar(m$unit)) paste0(m$label, " (", m$unit, ")")
      else m$label
    }, character(1))

    mean_num <- out$Mesatarja
    sd_num   <- out$`Devijimi standard`
    min_num  <- out$Minimumi
    max_num  <- out$Maksimumi

    fmt_safe <- function(x) {
      if (is.na(x)) return(NA_character_)
      fmt_by_series(as.numeric(x), for_axis = FALSE)
    }

    out$Mesatarja <- vapply(mean_num, fmt_safe, character(1))
    out$`Devijimi standard` <- vapply(sd_num, fmt_safe, character(1))
    out$Minimumi  <- vapply(min_num, fmt_safe, character(1))
    out$Maksimumi <- vapply(max_num, fmt_safe, character(1))

    out
  })

  # =========================================================
  # 4) fmt_pct
  # =========================================================
  fmt_pct <- function(x) {
    if (is.na(x)) return("N/A")
    s <- fmt_fixed(abs(x), digits = 2)  # kjo ta bën me presje
    if (x > 0)  return(paste0("+", s, "% / vit"))
    if (x < 0)  return(paste0("-", s, "% / vit"))
    "0,00% / vit"
  }

  # =========================
  # Captions
  # =========================

  output$cap_eda_ts_raw <- renderText({
    req(input$eda_series)
    m <- var_meta(input$eda_series, meta())
    paste0("Seria origjinale për ", m$label, ".")
  })

  output$cap_eda_ts_roll <- renderText({
    req(input$eda_series, input$roll_k)
    m <- var_meta(input$eda_series, meta())
    paste0("Mesatare lëvizëse (k = ", input$roll_k, ") për ", m$label, ".")
  })

  output$cap_eda_ts_dist <- renderText({
    req(input$eda_series)
    m <- var_meta(input$eda_series, meta())
    paste0("Shpërndarja e vlerave për ", m$label, ".")
  })

  output$cap_eda_rel_scatter <- renderText({
    req(input$rel_x, input$rel_y)
    mx <- var_meta(input$rel_x, meta())
    my <- var_meta(input$rel_y, meta())
    paste0("Grafik shpërndarjeje: ", mx$label, " kundrejt ", my$label, ".")
  })

  output$cap_eda_rel_corr <- renderText({
    "Matrica e korrelacionit (Pearson) për variablat numerike."
  })

  output$cap_stat_diff_plot <- renderText({
    req(input$stat_series)
    m <- var_meta(input$stat_series, meta())
    paste0("Diferenca e parë (Δyₜ = yₜ − yₜ₋₁) për ", m$label, ".")
  })

  output$cap_stat_acf_pacf <- renderText({
    req(input$stat_series)
    m <- var_meta(input$stat_series, meta())
    paste0("ACF/PACF mbi diferencën e parë të ", m$label, ".")
  })

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
  # EDA – Seri kohore 
  # =========================

  output$eda_ts_raw <- renderPlotly({
    req(df_dyn(), input$eda_series)

    m <- var_meta(input$eda_series, meta())
    d0 <- df_dyn()

    xlab <- time_axis_label(d0$Time)

    d <- d0 %>%
      dplyr::select(Time, value = dplyr::all_of(input$eda_series)) %>%
      dplyr::mutate(
        hover = paste0(
          xlab, ": ", fmt_time(Time),
          "<br>", m$label, ": ", fmt_unit(value, input$eda_series, meta())
        )
      )

    p <- ggplot(d, aes(x = Time, y = value)) +
      geom_line(linewidth = 1, color = "white") +
      labs(
        title = paste0("Seria kohore e vëzhguar – ", m$label),
        x = xlab,
        y = if (nzchar(m$unit)) paste0(m$label, " (", m$unit, ")") else m$label
      ) +
      scale_y_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
      theme_minimal() +
      theme(
        plot.background  = element_blank(),
        panel.background = element_blank(),
        text = element_text(color = "white"),
        axis.text = element_text(color = "white"),
        axis.title = element_text(color = "white")
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        font = list(color = "white"),
        xaxis = list(gridcolor = "rgba(255,255,255,0.15)"),
        yaxis = list(gridcolor = "rgba(255,255,255,0.15)")
      )

    line_idx <- find_traces(pl, function(tr) {
      (tr$type %||% "") == "scatter" && grepl("lines", tr$mode %||% "")
    })[1]

    pl <- set_trace_text(pl, line_idx, d$hover)

    plotly_cfg(pl)
  })

  output$eda_ts_roll <- renderPlotly({
    req(df_dyn(), input$eda_series, input$roll_k)

    if (!requireNamespace("zoo", quietly = TRUE)) {
      showNotification("Paketa 'zoo' mungon. Instalo: install.packages('zoo')", type = "error")
      return(NULL)
    }

    m <- var_meta(input$eda_series, meta())
    d0 <- df_dyn()
    xlab <- time_axis_label(d0$Time)

    # -------------------------
    # roll_k
    # -------------------------
    y <- d0[[input$eda_series]]
    n_non_na <- sum(!is.na(y))

    k <- input$roll_k
    if (is.null(k) || is.na(k)) k <- 5
    k <- as.integer(k)
    k <- max(2L, k)

    if (n_non_na < 3) {
      showNotification("Seria ka shumë pak vlera reale (jo-NA) për rolling mean.", type = "warning")
      return(NULL)
    }

    k_max <- max(2L, n_non_na - 1L)
    if (k > k_max) {
      k <- k_max
      showNotification(
        paste0("roll_k u përshtat automatikisht në k=", k,
              " (seri ka ", n_non_na, " vlera jo-NA)."),
        type = "message"
      )
    }

    # -------------------------
    # Rolling mean
    # -------------------------
    d <- d0 %>%
      dplyr::arrange(Time) %>%
      dplyr::mutate(
        roll_mean = zoo::rollapply(
          .data[[input$eda_series]],
          width = k,
          FUN = function(z) {
            if (all(is.na(z))) NA_real_
            else mean(z, na.rm = TRUE)
          },
          fill = NA,
          align = "right",
          partial = FALSE
        )
      ) %>%
      dplyr::mutate(
        hover_raw = paste0(
          xlab, ": ", fmt_time(Time),
          "<br>", m$label, ": ", fmt_unit(.data[[input$eda_series]], input$eda_series, meta())
        ),
        hover_roll = ifelse(
          is.na(roll_mean),
          NA_character_,
          paste0(
            xlab, ": ", fmt_time(Time),
            "<br>Mesatare lëvizëse: ", fmt_unit(roll_mean, input$eda_series, meta())
          )
        )
      )

    p <- ggplot(d, aes(x = Time)) +
      geom_line(
        aes(y = .data[[input$eda_series]]),
        color = scales::alpha("white", 0.35),
        linewidth = 0.9
      ) +
      geom_line(
        aes(y = roll_mean),
        color = "#ff3b30",
        linewidth = 1.6
      ) +
      labs(
        title = paste0("Mesatarja lëvizëse (k = ", k, ")"),
        subtitle = if (nzchar(m$unit)) paste0(m$label, " (", m$unit, ")") else m$label,
        x = NULL,
        y = NULL
      ) +
      scale_y_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = scales::alpha("white", 0.12), linewidth = 0.3),
        panel.grid.minor = element_blank(),
        axis.text     = element_text(color = scales::alpha("white", 0.92)),
        plot.title    = element_text(face = "bold", color = scales::alpha("white", 0.95)),
        plot.subtitle = element_text(color = scales::alpha("white", 0.75))
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 40, r = 20, b = 40),
        hovermode = "x unified",
        font  = list(color = "white"),
        xaxis = list(
          gridcolor     = "rgba(255,255,255,0.15)",
          zerolinecolor = "rgba(255,255,255,0.15)",
          tickfont      = list(color = "white")
        ),
        yaxis = list(
          gridcolor     = "rgba(255,255,255,0.15)",
          zerolinecolor = "rgba(255,255,255,0.15)",
          tickfont      = list(color = "white")
        )
      )

    line_idx <- find_traces(pl, function(tr) {
      (tr$type %||% "") == "scatter" && grepl("lines", tr$mode %||% "")
    })

    if (length(line_idx) >= 1) pl <- set_trace_text(pl, line_idx[1], d$hover_raw)
    if (length(line_idx) >= 2) pl <- set_trace_text(pl, line_idx[2], d$hover_roll)

    plotly_cfg(pl)
  })

  output$eda_ts_dist <- renderPlotly({
    req(df_dyn(), input$eda_series)

    m <- var_meta(input$eda_series, meta())

    d <- df_dyn() %>%
      dplyr::mutate(val = .data[[input$eda_series]])

    p <- ggplot(d, aes(x = val)) +
      geom_histogram(
        aes(y = after_stat(density)),
        bins = 18,
        fill  = scales::alpha("#0a84ff", 0.35),
        color = scales::alpha("white", 0.18)
      ) +
      geom_density(
        color = "#ff3b30",
        linewidth = 1.4
      ) +
      labs(
        title = "Shpërndarja",
        subtitle = if (nzchar(m$unit)) paste0(m$label, " (", m$unit, ")") else m$label,
        x = NULL,
        y = NULL
      ) +
      scale_x_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),

        panel.grid.major = element_line(color = scales::alpha("white", 0.12), linewidth = 0.3),
        panel.grid.minor = element_blank(),

        axis.text     = element_text(color = scales::alpha("white", 0.92)),
        plot.title    = element_text(face = "bold", color = scales::alpha("white", 0.95)),
        plot.subtitle = element_text(color = scales::alpha("white", 0.75))
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 40, r = 20, b = 40),

        font  = list(color = "white"),
        xaxis = list(
          gridcolor     = "rgba(255,255,255,0.15)",
          zerolinecolor = "rgba(255,255,255,0.15)",
          tickfont      = list(color = "white")
        ),
        yaxis = list(
          gridcolor     = "rgba(255,255,255,0.15)",
          zerolinecolor = "rgba(255,255,255,0.15)",
          tickfont      = list(color = "white")
        )
      )

    pl <- skip_trace_hover(pl, seq_along(pl$x$data))

    plotly_cfg(pl)
  })

  # =========================
  # EDA – Marrëdhënie
  # =========================

  output$eda_rel_scatter <- renderPlotly({
    req(df_dyn(), input$rel_x, input$rel_y)

    d0 <- df_dyn()
    req(input$rel_x %in% names(d0), input$rel_y %in% names(d0))

    mx <- var_meta(input$rel_x, meta())
    my <- var_meta(input$rel_y, meta())

    has_time  <- "Time" %in% names(d0)
    xlab_time <- if (has_time) time_axis_label(d0$Time) else "Rreshti"

    d <- d0 %>%
      dplyr::mutate(
        xval = .data[[input$rel_x]],
        yval = .data[[input$rel_y]],
        rowi = dplyr::row_number(),
        hover = if (has_time) {
          paste0(
            xlab_time, ": ", fmt_time(.data$Time),
            "<br>", mx$label, ": ", fmt_unit(xval, input$rel_x, meta()),
            "<br>", my$label, ": ", fmt_unit(yval, input$rel_y, meta())
          )
        } else {
          paste0(
            "Rreshti: ", rowi,
            "<br>", mx$label, ": ", fmt_unit(xval, input$rel_x, meta()),
            "<br>", my$label, ": ", fmt_unit(yval, input$rel_y, meta())
          )
        }
      ) %>%
      dplyr::filter(is.finite(xval), is.finite(yval))

    shiny::validate(shiny::need(nrow(d) > 1, "S’ka mjaft pika (pas heqjes së NA)."))
    shiny::validate(shiny::need(length(unique(d$xval)) > 1, "Variabla X s’ka mjaft variacion për regresion."))

    fit <- tryCatch(stats::lm(yval ~ xval, data = d), error = function(e) NULL)

    line_df <- NULL
    if (!is.null(fit) && all(is.finite(stats::coef(fit)))) {
      xs <- seq(min(d$xval), max(d$xval), length.out = 100)
      line_df <- data.frame(xval = xs)
      line_df$yhat <- as.numeric(stats::predict(fit, newdata = line_df))
    }

    p <- ggplot2::ggplot(d, ggplot2::aes(x = xval, y = yval)) +
      ggplot2::geom_point(
        ggplot2::aes(text = hover),
        size = 2.6,
        alpha = 0.70,
        color = "#2E86FF"
      )

    if (!is.null(line_df)) {
      p <- p +
        ggplot2::geom_line(
          data = line_df,
          ggplot2::aes(x = xval, y = yhat),
          inherit.aes = FALSE,
          linewidth = 0.9,
          color = "#FF3B30"
        )
    }

    p <- p +
      ggplot2::scale_x_continuous(labels = fmt_by_series) +
      ggplot2::scale_y_continuous(labels = fmt_by_series) +
      ggplot2::labs(
        title = "Marrëdhënia ndërmjet variablave",
        subtitle = paste0(mx$label, " kundrejt ", my$label),
        x = if (nzchar(mx$unit)) paste0(mx$label, " (", mx$unit, ")") else mx$label,
        y = if (nzchar(my$unit)) paste0(my$label, " (", my$unit, ")") else my$label
      ) +
      ggplot2::theme_minimal(base_size = 13) +
      ggplot2::theme(
        panel.background = ggplot2::element_rect(fill = "transparent", color = NA),
        plot.background  = ggplot2::element_rect(fill = "transparent", color = NA),

        text       = ggplot2::element_text(color = scales::alpha("white", 0.85)),
        plot.title = ggplot2::element_text(face = "bold", size = 15, color = scales::alpha("white", 0.95)),
        plot.subtitle = ggplot2::element_text(color = scales::alpha("white", 0.70), size = 12),

        axis.title = ggplot2::element_text(color = scales::alpha("white", 0.90)),
        axis.text  = ggplot2::element_text(color = scales::alpha("white", 0.75)),
        axis.ticks = ggplot2::element_line(color = scales::alpha("white", 0.35)),

        panel.grid.major = ggplot2::element_line(color = scales::alpha("white", 0.10), linewidth = 0.3),
        panel.grid.minor = ggplot2::element_blank()
      )

    pl <- plotly::ggplotly(p, tooltip = "text") %>%
      plotly::layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 50, r = 20, b = 60),
        hovermode = "closest",
        font = list(color = "rgba(255,255,255,0.85)"),
        xaxis = list(
          tickfont  = list(color = "rgba(255,255,255,0.75)"),
          titlefont = list(color = "rgba(255,255,255,0.90)"),
          gridcolor = "rgba(255,255,255,0.10)",
          zerolinecolor = "rgba(255,255,255,0.10)"
        ),
        yaxis = list(
          tickfont  = list(color = "rgba(255,255,255,0.75)"),
          titlefont = list(color = "rgba(255,255,255,0.90)"),
          gridcolor = "rgba(255,255,255,0.10)",
          zerolinecolor = "rgba(255,255,255,0.10)"
        )
      )

    if (!is.null(pl$x$layout$annotations)) {
      pl$x$layout$annotations <- lapply(pl$x$layout$annotations, function(a) {
        if (is.null(a$font)) a$font <- list()
        a$font$color <- "rgba(255,255,255,0.90)"
        a
      })
    }

    plotly_cfg(pl)
  })

  output$eda_rel_corr <- renderPlotly({
    req(df_dyn())

    d0 <- df_dyn()

    num_df <- d0 %>%
      dplyr::select(where(is.numeric)) %>%
      dplyr::select(-dplyr::any_of("Time"))

    if (ncol(num_df) < 2) {
      shiny::showNotification("Duhet të paktën 2 kolona numerike për korrelacion.", type = "warning")
      return(NULL)
    }

    if (ncol(num_df) > 20) {
      num_df <- num_df[, 1:20, drop = FALSE]
      shiny::showNotification("U përdorën vetëm 20 kolonat e para numerike për heatmap.", type = "message")
    }

    num_df <- num_df %>%
      dplyr::select(where(~ {
        s <- stats::sd(.x, na.rm = TRUE)
        is.finite(s) && s > 0
      }))

    if (ncol(num_df) < 2) {
      shiny::showNotification("Pas filtrit (sd>0) s’mbetën të paktën 2 kolona numerike.", type = "warning")
      return(NULL)
    }

    corr_mat <- stats::cor(num_df, use = "pairwise.complete.obs")

    corr_df <- as.data.frame(as.table(corr_mat), stringsAsFactors = FALSE)
    colnames(corr_df) <- c("Var1", "Var2", "Korrelacioni")

    vars <- colnames(num_df)
    corr_df$Var1 <- factor(corr_df$Var1, levels = vars)
    corr_df$Var2 <- factor(corr_df$Var2, levels = vars)

    corr_df <- corr_df %>%
      dplyr::mutate(
        text = paste0(
          as.character(Var1), " × ", as.character(Var2),
          "<br>Korrelacioni: ", fmt_fixed(Korrelacioni, digits = 2)
        )
      )

    p <- ggplot2::ggplot(
      corr_df,
      ggplot2::aes(x = Var1, y = Var2, fill = Korrelacioni, text = text)
    ) +
      ggplot2::geom_tile(color = scales::alpha("white", 0.35), linewidth = 0.4) +
      ggplot2::scale_fill_gradient2(
        low = "#0a84ff",
        mid = "white",
        high = "#ff3b30",
        midpoint = 0
      ) +
      ggplot2::geom_text(
        ggplot2::aes(label = fmt_fixed(Korrelacioni, digits = 2)),
        color = "black",
        size = 4.2
      ) +
      ggplot2::labs(
        title = "Matrica e korrelacionit",
        x = NULL,
        y = NULL
      ) +
      ggplot2::theme_minimal(base_size = 13) +
      ggplot2::theme(
        panel.background = ggplot2::element_rect(fill = "transparent", color = NA),
        plot.background  = ggplot2::element_rect(fill = "transparent", color = NA),
        panel.grid = ggplot2::element_blank(),
        axis.text.x = ggplot2::element_text(color = scales::alpha("white", 0.92), size = 12),
        axis.text.y = ggplot2::element_text(color = scales::alpha("white", 0.92), size = 12),
        plot.title  = ggplot2::element_text(face = "bold", size = 15, color = scales::alpha("white", 0.95))
      )

    pl <- plotly::ggplotly(p, tooltip = "text") %>%
      plotly::layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 80, r = 20, b = 60)
      ) %>%
      plotly_cfg()

    for (i in seq_along(pl$x$data)) {
      tr <- pl$x$data[[i]]
      if (!is.null(tr$mode) && grepl("text", tr$mode)) {
        if (is.null(pl$x$data[[i]]$textfont)) pl$x$data[[i]]$textfont <- list()
        pl$x$data[[i]]$textfont$color <- "black"
      }
    }

    pl
  })

  # =========================
  # Stacionariteti
  # =========================

  output$stat_diff_plot <- renderPlotly({
    req(df_dyn(), input$stat_series)

    d0 <- df_dyn()
    req("Time" %in% names(d0))

    validate(
      need(!is.null(input$stat_series) && nzchar(input$stat_series),
          "Zgjidh një seri për analizën e stacionaritetit."),
      need(input$stat_series %in% names(d0),
          paste0("Kolona '", input$stat_series, "' nuk ekziston në dataset. Ndrysho serinë te dropdown-i."))
    )

    m    <- var_meta(input$stat_series, meta())
    xlab <- time_axis_label(d0$Time)

    dd <- d0 %>%
      dplyr::select(Time, y = dplyr::all_of(input$stat_series)) %>%
      dplyr::arrange(Time) %>%
      dplyr::filter(!is.na(y))

    if (nrow(dd) < 3) {
      showNotification("Seria ka shumë pak vlera reale (jo-NA) për diferencë të parë.", type = "warning")
      return(NULL)
    }

    dy <- diff(dd$y)
    tt <- dd$Time[-1]

    d <- data.frame(
      Time = tt,
      Diferenca = as.numeric(dy),
      stringsAsFactors = FALSE
    ) %>%
      dplyr::mutate(
        hover = paste0(
          xlab, ": ", fmt_time(Time),
          "<br>Diferenca: ", fmt_unit(Diferenca, input$stat_series, meta())
        )
      )

    p <- ggplot(d, aes(x = Time, y = Diferenca)) +
      geom_line(linewidth = 1.2, color = "#0a84ff") +
      labs(
        title = paste0("Diferenca e parë – ", m$label),
        x = xlab,
        y = "Vlera e diferencuar"
      ) +
      scale_y_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = scales::alpha("white", 0.15)),
        panel.grid.minor = element_blank(),
        axis.text.x = element_text(color = scales::alpha("white", 0.92), size = 12),
        axis.text.y = element_text(color = scales::alpha("white", 0.92), size = 12),
        axis.title.x = element_text(color = scales::alpha("white", 0.85)),
        axis.title.y = element_text(color = scales::alpha("white", 0.85)),
        plot.title   = element_text(face = "bold", size = 15, color = scales::alpha("white", 0.95))
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 70, r = 20, b = 60),
        font  = list(color = "white"),
        xaxis = list(gridcolor = "rgba(255,255,255,0.15)"),
        yaxis = list(gridcolor = "rgba(255,255,255,0.15)")
      )

    line_idx <- find_traces(pl, function(tr) grepl("lines", tr$mode %||% ""))
    if (length(line_idx) >= 1) {
      pl <- set_trace_text(pl, line_idx[1], d$hover)
    }

    plotly_cfg(pl)
  })

  output$stat_acf_pacf <- renderPlotly({
    req(df_dyn(), input$stat_series)

    d0 <- df_dyn()
    req("Time" %in% names(d0))

    validate(
      need(!is.null(input$stat_series) && nzchar(input$stat_series),
          "Zgjidh një seri për ACF/PACF."),
      need(input$stat_series %in% names(d0),
          paste0("Kolona '", input$stat_series, "' nuk ekziston në dataset. Ndrysho serinë te dropdown-i."))
    )

    m <- var_meta(input$stat_series, meta())

    dd <- d0 %>%
      dplyr::select(Time, y = dplyr::all_of(input$stat_series)) %>%
      dplyr::arrange(Time) %>%
      dplyr::filter(!is.na(y))

    if (nrow(dd) < 6) {
      showNotification("Duhet të paktën ~6 vlera reale për ACF/PACF (pas diferencës humbet 1).", type="warning")
      return(NULL)
    }

    spec <- ts_spec_from_time(dd$Time, input$data_freq %||% "auto")
    y_ts <- stats::ts(as.numeric(dd$y), frequency = spec$freq, start = spec$start)
    dy   <- diff(y_ts)
    n    <- length(dy)

    if (n < 5) {
      showNotification("Seria e diferencuar ka shumë pak pika për ACF/PACF.", type="warning")
      return(NULL)
    }

    acf_obj  <- stats::acf(dy, plot = FALSE)
    pacf_obj <- stats::pacf(dy, plot = FALSE)

    freq0 <- stats::frequency(y_ts)
    if (is.null(freq0) || is.na(freq0) || freq0 < 1) freq0 <- 1

    acf_df <- data.frame(
      Vonesa = as.integer(round(as.numeric(acf_obj$lag[-1]) * freq0)),
      Vlera  = as.numeric(acf_obj$acf[-1]),
      Tipi   = "ACF",
      stringsAsFactors = FALSE
    )

    pacf_df <- data.frame(
      Vonesa = as.integer(round(as.numeric(pacf_obj$lag) * freq0)),
      Vlera  = as.numeric(pacf_obj$acf),
      Tipi   = "PACF",
      stringsAsFactors = FALSE
    )

    df_plot <- rbind(acf_df, pacf_df)

    conf <- 1.96 / sqrt(n)

    p <- ggplot(df_plot, aes(x = Vonesa, y = Vlera)) +
      geom_col(fill = scales::alpha("#0a84ff", 0.75), width = 0.7) +
      geom_hline(
        yintercept = c(-conf, conf),
        linetype = "dashed",
        color = scales::alpha("white", 0.6)
      ) +
      facet_wrap(~ Tipi, scales = "free_y", ncol = 1) +
      labs(
        title = paste0("ACF dhe PACF – ", m$label),
        x = "Vonesa (lag)",
        y = "Korrelacioni"
      ) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = scales::alpha("white", 0.15)),
        panel.grid.minor = element_blank(),
        strip.background = element_rect(fill = scales::alpha("white", 0.18), color = NA),
        strip.text       = element_text(color = scales::alpha("white", 0.95), face = "bold"),
        axis.text.x      = element_text(color = scales::alpha("white", 0.92), size = 11),
        axis.text.y      = element_text(color = scales::alpha("white", 0.92), size = 11),
        axis.title.x     = element_text(color = scales::alpha("white", 0.85)),
        axis.title.y     = element_text(color = scales::alpha("white", 0.85)),
        plot.title       = element_text(face = "bold", size = 15, color = scales::alpha("white", 0.95))
      )

    ggplotly(p, tooltip = c("Vonesa", "Vlera", "Tipi")) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 70, l = 70, r = 20, b = 60)
      ) %>%
      plotly_cfg()
  })

  # =========================
  # ADF
  # =========================
  adf_res <- reactive({
    req(df_dyn(), input$stat_series)

    d0 <- df_dyn()

    validate(
      need(!is.null(input$stat_series) && nzchar(input$stat_series),
          "Zgjidh një seri për ADF."),
      need(input$stat_series %in% names(d0),
          paste0("Kolona '", input$stat_series, "' nuk ekziston në dataset. Ndrysho serinë te dropdown-i."))
    )

    y <- suppressWarnings(as.numeric(d0[[input$stat_series]]))
    y <- y[!is.na(y)]

    base_tbl <- data.frame(
      Serie     = c("Original (niveli)", "First difference (Δ)"),
      Statistic = NA_real_,
      `p-value` = NA_real_,
      Method    = NA_character_,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )

    if (!requireNamespace("tseries", quietly = TRUE)) {
      base_tbl$Method <- "Paketa 'tseries' mungon — instalo: install.packages('tseries')"
      return(list(
        ok = FALSE, reason = "no_pkg",
        y_len = length(y),
        table = base_tbl,
        p_lvl = NA_real_, p_diff = NA_real_
      ))
    }

    if (length(y) < 20) {
      base_tbl$Method <- "ADF (tseries::adf.test) — kërkon ≥ 20 pika"
      return(list(
        ok = FALSE, reason = "too_short",
        y_len = length(y),
        table = base_tbl,
        p_lvl = NA_real_, p_diff = NA_real_
      ))
    }

    adf_lvl <- try(tseries::adf.test(y), silent = TRUE)
    dy      <- diff(y)
    adf_diff <- if (length(dy) >= 20) try(tseries::adf.test(dy), silent = TRUE) else "try-error"

    fill_row <- function(tbl, row_idx, obj) {
      if (!inherits(obj, "try-error")) {
        tbl$Statistic[row_idx] <- as.numeric(obj$statistic)
        tbl$`p-value`[row_idx] <- as.numeric(obj$p.value)
        tbl$Method[row_idx]    <- obj$method
      } else {
        tbl$Method[row_idx]    <- "ADF (tseries::adf.test)"
      }
      tbl
    }

    out_tbl <- base_tbl
    out_tbl <- fill_row(out_tbl, 1, adf_lvl)
    out_tbl <- fill_row(out_tbl, 2, adf_diff)

    out_tbl$Statistic <- round(out_tbl$Statistic, 4)
    out_tbl$`p-value` <- formatC(out_tbl$`p-value`, format = "f", digits = 4)

    p_lvl  <- if (!inherits(adf_lvl,  "try-error")) as.numeric(adf_lvl$p.value)  else NA_real_
    p_diff <- if (!inherits(adf_diff, "try-error")) as.numeric(adf_diff$p.value) else NA_real_

    list(
      ok = TRUE, reason = "ok",
      y_len = length(y),
      table = out_tbl,
      p_lvl = p_lvl, p_diff = p_diff
    )
  })

  # =========================
  # OUTPUTS
  # =========================
  output$stat_adf_tbl <- renderTable({
    adf_res()$table
  }, striped = FALSE, bordered = TRUE, spacing = "s")

  output$stat_adf_note <- renderUI({
    req(df_dyn(), input$stat_series)

    res <- adf_res()

    if (identical(res$reason, "no_pkg")) {
      return(HTML(
        "<p style='margin-top:10px; font-size: 13px; line-height: 1.45;'>
          <b>Interpretim (ADF):</b> Paketa <b>tseries</b> mungon.
          Instalo: <code>install.packages('tseries')</code>.
        </p>"
      ))
    }

    if (identical(res$reason, "too_short")) {
      return(HTML(
        "<p style='margin-top:10px; font-size: 13px; line-height: 1.45;'>
          <b>Interpretim (ADF):</b> Seria ka shumë pak pika (duhen ≥ 20) për test të besueshëm.
        </p>"
      ))
    }

    m <- var_meta(input$stat_series, meta())

    alpha <- 0.05
    p_lvl  <- res$p_lvl
    p_diff <- res$p_diff

    concl_lvl <- if (!is.na(p_lvl) && p_lvl < alpha) {
      "refuzohet hipoteza zero dhe seria në nivel vlerësohet stacionare"
    } else if (!is.na(p_lvl)) {
      "nuk refuzohet hipoteza zero dhe seria në nivel sugjeron jo-stacionaritet"
    } else {
      "testi për serinë në nivel nuk u llogarit (gabim gjatë ekzekutimit)"
    }

    concl_diff <- if (!is.na(p_diff) && p_diff < alpha) {
      "pas diferencës së parë refuzohet hipoteza zero dhe seria e diferencuar vlerësohet stacionare"
    } else if (!is.na(p_diff)) {
      "edhe pas diferencës së parë nuk refuzohet hipoteza zero"
    } else {
      "testi për serinë e diferencuar nuk u llogarit (gabim gjatë ekzekutimit)"
    }

    p_txt_lvl  <- ifelse(is.na(p_lvl),  "NA", formatC(p_lvl,  format = "f", digits = 4))
    p_txt_diff <- ifelse(is.na(p_diff), "NA", formatC(p_diff, format = "f", digits = 4))

    unit_txt <- if (nzchar(m$unit %||% "")) paste0(" (", m$unit, ")") else ""

    HTML(paste0(
      "<p style='margin-top:10px; font-size: 13px; line-height: 1.45;'>",
      "<b>Interpretim (ADF):</b> Për serinë <i>", m$label, "</i>", unit_txt, ", ",
      "hipoteza zero e testit ADF është se seria ka rrënjë njësi (pra është jo-stacionare). ",
      "Me nivel rëndësie &alpha; = 0.05: ",
      "<br>• <b>Niveli</b> (p = ", p_txt_lvl, "): ", concl_lvl, ".",
      "<br>• <b>Diferenca e parë</b> (p = ", p_txt_diff, "): ", concl_diff, ".",
      "</p>"
    ))
  })

  # =========================
  # Modelimi – ETS & ARIMA
  # =========================

  model_h_db <- shiny::debounce(reactive({input$model_h}), millis = 350)

  .model_cache_key <- reactiveVal(NULL)
  .model_cache_val <- reactiveVal(NULL)

  .model_fits <- reactive({
    req(df_dyn(), input$model_series)

    d0 <- df_dyn()

    dd <- d0 %>%
      dplyr::select(Time, y = dplyr::all_of(input$model_series)) %>%
      dplyr::arrange(Time) %>%
      dplyr::filter(!is.na(y))

    n <- nrow(dd)
    if (n < 20) {
      return(list(ok = FALSE, msg = "Për ETS/ARIMA rekomandohen ≥ 20 pika reale (jo-NA)."))
    }

    y_raw <- as.numeric(dd$y)

    spec <- ts_spec_from_time(dd$Time, input$data_freq %||% "auto")
    y_ts <- stats::ts(y_raw, frequency = spec$freq, start = spec$start)
    y_mod <- if (anyNA(y_ts)) forecast::na.interp(y_ts) else y_ts

    key <- paste0(
      input$model_series, "|", (input$data_freq %||% "auto"), "|",
      n, "|", fmt_time(tail(dd$Time, 1)), "|",
      sprintf("%.6f", sum(y_raw, na.rm = TRUE)), "|",
      sprintf("%.6f", stats::sd(y_raw, na.rm = TRUE))
    )

    if (identical(.model_cache_key(), key)) {
      return(.model_cache_val())
    }

    out <- shiny::withProgress(message = "Duke ndërtu ETS & ARIMA...", value = 0, {
      shiny::incProgress(0.2)

      fit_ets <- try(forecast::ets(y_mod), silent = TRUE)
      shiny::incProgress(0.55)

      fq <- stats::frequency(y_mod)

      seasonal_flag <- fq %in% c(4, 12, 52)

      fastish <- length(y_mod) > 800 || fq > 12

      fit_arima <- try(
        forecast::auto.arima(
          y_mod,
          seasonal = seasonal_flag,
          stepwise = TRUE,
          approximation = if (fastish) TRUE else FALSE
        ),
        silent = TRUE
      )

      shiny::incProgress(0.95)

      if (inherits(fit_ets, "try-error") || inherits(fit_arima, "try-error")) {
        return(list(ok = FALSE, msg = "Modelimi dështoi për ETS ose ARIMA (kontrollo NA / seri konstante / freq)."))
      }

      list(
        ok = TRUE,
        dd = dd,
        y_raw = y_raw,
        fit_ets = fit_ets,
        fit_arima = fit_arima,
        xlab = time_axis_label(d0$Time),
        m = var_meta(input$model_series, meta())
      )
    })

    .model_cache_key(key)
    .model_cache_val(out)
    out
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

    acc_ets   <- forecast::accuracy(x$fit_ets)
    acc_arima <- forecast::accuracy(x$fit_arima)

    get_metric <- function(acc, metric) {
      val <- if ("Training set" %in% rownames(acc)) acc["Training set", metric] else acc[1, metric]
      as.numeric(val)
    }

    add_unit <- function(txt) {
      u <- m$unit %||% ""
      if (nzchar(u)) paste0(txt, " ", u) else txt
    }

    rmse_vals <- c(get_metric(acc_ets, "RMSE"), get_metric(acc_arima, "RMSE"))
    mae_vals  <- c(get_metric(acc_ets, "MAE"),  get_metric(acc_arima, "MAE"))
    mape_vals <- c(get_metric(acc_ets, "MAPE"), get_metric(acc_arima, "MAPE"))

    data.frame(
      Modeli = c("ETS", "ARIMA"),
      RMSE   = vapply(rmse_vals, function(v) add_unit(fmt_by_series(v, for_axis = FALSE)), character(1)),
      MAE    = vapply(mae_vals,  function(v) add_unit(fmt_by_series(v, for_axis = FALSE)), character(1)),
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

    dd <- d0 %>%
      dplyr::select(Time, y = dplyr::all_of(input$forecast_series)) %>%
      dplyr::filter(!is.na(Time)) %>%
      dplyr::arrange(Time)

    if (any(duplicated(dd$Time))) {
      dd <- dd %>%
        dplyr::group_by(Time) %>%
        dplyr::summarise(y = mean(y, na.rm = TRUE), .groups = "drop") %>%
        dplyr::arrange(Time)

      dd$y[is.nan(dd$y)] <- NA_real_
      showNotification("U gjetën duplikate në kohë; u agreguan me mesatare (mean).", type = "message")
    }

    if (sum(!is.na(dd$y)) < 2) {
      showNotification("Duhet të paktën 2 pika reale (jo-NA) për parashikim.", type = "warning")
      return(NULL)
    }

    if (stats::sd(dd$y, na.rm = TRUE) < 1e-12) {
      showNotification("Seria është (pothuaj) konstante — parashikimi s’ka kuptim.", type = "warning")
      return(NULL)
    }

    dd
  })

  series_ts <- reactive({
    req(series_dat())
    dd <- series_dat()

    spec <- ts_spec_from_time(dd$Time, input$data_freq %||% "auto")
    yts  <- stats::ts(as.numeric(dd$y), frequency = spec$freq, start = spec$start)

    if (anyNA(yts)) yts <- forecast::na.interp(yts)
    yts
  })

  h_db <- shiny::debounce(reactive({input$h}), millis = 350)

  .arima_cache_key <- reactiveVal(NULL)
  .arima_cache_val <- reactiveVal(NULL)

  arima_fit <- reactive({
    req(series_ts(), series_dat())

    if ((input$method %||% "") != "arima") return(NULL)

    y  <- series_ts()
    dd <- series_dat()

    n_real <- sum(!is.na(dd$y))
    if (n_real < 30) {
      return(list(ok = FALSE, msg = "Për ARIMA rekomandohen ≥ 30 pika reale. Zgjidh SES/Holt ose shto të dhëna."))
    }

    fq <- stats::frequency(y)

    key <- paste0(
      "n=", length(y),
      "|fq=", fq,
      "|last=", fmt_time(tail(dd$Time, 1)),
      "|sum=", sprintf("%.6f", sum(as.numeric(dd$y), na.rm = TRUE)),
      "|sd=",  sprintf("%.6f", stats::sd(as.numeric(dd$y), na.rm = TRUE)),
      "|freqopt=", (input$data_freq %||% "auto")
    )

    if (identical(.arima_cache_key(), key)) {
      return(.arima_cache_val())
    }

    out <- shiny::withProgress(message = "Duke ndërtu ARIMA...", value = 0, {
      shiny::incProgress(0.2)

      seasonal_flag <- fq %in% c(4, 12, 52)

      fastish <- length(y) > 800 || fq > 12

      fit <- try(
        forecast::auto.arima(
          y,
          seasonal = seasonal_flag,
          stepwise = TRUE,
          approximation = if (fastish) TRUE else FALSE
        ),
        silent = TRUE
      )

      shiny::incProgress(0.95)

      if (inherits(fit, "try-error")) {
        return(list(ok = FALSE, msg = "ARIMA dështoi (kontrollo të dhënat / missing / seri konstante / freq)."))
      }

      list(ok = TRUE, fit = fit)
    })

    .arima_cache_key(key)
    .arima_cache_val(out)
    out
  })

  forecast_obj <- reactive({
    req(series_ts(), series_dat(), input$method)

    y  <- series_ts()
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

    if (input$method == "ses")  return(forecast::ses(y,  h = h))
    if (input$method == "holt") return(forecast::holt(y, h = h))

    af <- arima_fit()
    if (is.null(af) || !isTRUE(af$ok)) {
      msg <- if (is.null(af)) "ARIMA s’u krijua." else (af$msg %||% "ARIMA s’u krijua.")
      showNotification(msg, type="error")
      return(NULL)
    }

    forecast::forecast(af$fit, h = h)
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
        add_unit(fmt_by_series(vals["ME"],   for_axis = FALSE)),
        add_unit(fmt_by_series(vals["MAE"],  for_axis = FALSE)),
        add_unit(fmt_by_series(vals["RMSE"], for_axis = FALSE)),
        if (is.na(vals["MAPE"])) "NA" else paste0(fmt_fixed(vals["MAPE"], digits = 2), " %")
      ),
      check.names = FALSE
    )
  }, striped = FALSE, bordered = TRUE, spacing = "s")
}
