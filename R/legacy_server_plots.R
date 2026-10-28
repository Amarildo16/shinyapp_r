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
  # Slider DINAMIK: roll_k (EDA) + model_h + h (Forecast)
  # =========================================================


  .slider_once <- reactiveValues(roll_k = FALSE, model_h = FALSE, h = FALSE)

  # priority = 1: rivendoset para observer-ave të slider-ave, si me df() e vjetër.
  observeEvent(active(), {
    .slider_once$roll_k  <- FALSE
    .slider_once$model_h <- FALSE
    .slider_once$h       <- FALSE
  }, ignoreInit = TRUE, priority = 1)

  observeEvent(list(df_dyn(), input$eda_series), {
    req(df_dyn(), input$eda_series)

    d0 <- df_dyn()
    if (is.null(d0) || nrow(d0) == 0) return()
    if (!(input$eda_series %in% names(d0))) return()

    y <- d0[[input$eda_series]]
    n_non_na <- sum(!is.na(y))

    unit <- time_step_unit(d0$Time)

    rb    <- roll_bounds(n_non_na, d0$Time)
    k_min <- rb$min
    k_max <- rb$max

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

    rm <- rolling_mean(d0, input$eda_series, input$roll_k)

    if (!isTRUE(rm$ok)) {
      showNotification("Seria ka shumë pak vlera reale (jo-NA) për rolling mean.", type = "warning")
      return(NULL)
    }

    k <- rm$k
    if (rm$k_adjusted) {
      showNotification(
        paste0("roll_k u përshtat automatikisht në k=", k,
              " (seri ka ", rm$n_non_na, " vlera jo-NA)."),
        type = "message"
      )
    }

    d <- rm$data %>%
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
      )

    rel <- relation_fit(d, input$rel_x, input$rel_y)
    shiny::validate(shiny::need(rel$reason != "few_points", "S’ka mjaft pika (pas heqjes së NA)."))
    shiny::validate(shiny::need(rel$reason != "no_x_variation", "Variabla X s’ka mjaft variacion për regresion."))

    d       <- rel$data
    line_df <- rel$line

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

    cm <- correlation_matrix(d0)

    if (identical(cm$reason, "few_cols")) {
      shiny::showNotification("Duhet të paktën 2 kolona numerike për korrelacion.", type = "warning")
      return(NULL)
    }

    if (isTRUE(cm$truncated)) {
      shiny::showNotification("U përdorën vetëm 20 kolonat e para numerike për heatmap.", type = "message")
    }

    if (identical(cm$reason, "few_cols_after_sd")) {
      shiny::showNotification("Pas filtrit (sd>0) s’mbetën të paktën 2 kolona numerike.", type = "warning")
      return(NULL)
    }

    corr_mat <- cm$corr

    corr_df <- as.data.frame(as.table(corr_mat), stringsAsFactors = FALSE)
    colnames(corr_df) <- c("Var1", "Var2", "Korrelacioni")

    vars <- colnames(corr_mat)
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

    ts_ok <- validate_ts_ready(d0, input$stat_series, FREQ_POLICY, min_n = 3L)
    validate(need(isTRUE(ts_ok$ok), ts_ok$message))

    fd <- first_difference(ts_ok$data)

    if (is.null(fd)) {
      showNotification("Seria ka shumë pak vlera reale (jo-NA) për diferencë të parë.", type = "warning")
      return(NULL)
    }

    d <- data.frame(Time = fd$Time, Diferenca = fd$diff, stringsAsFactors = FALSE) %>%
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

    ts_ok <- validate_ts_ready(d0, input$stat_series, FREQ_POLICY, min_n = 6L)
    validate(need(isTRUE(ts_ok$ok), ts_ok$message))

    dd <- ts_ok$data

    if (nrow(dd) < 6) {
      showNotification("Duhet të paktën ~6 vlera reale për ACF/PACF (pas diferencës humbet 1).", type="warning")
      return(NULL)
    }

    ap <- acf_pacf_data(dd)

    if (is.null(ap)) {
      showNotification("Seria e diferencuar ka shumë pak pika për ACF/PACF.", type="warning")
      return(NULL)
    }

    df_plot <- rbind(
      data.frame(Vonesa = ap$acf$lag,  Vlera = ap$acf$value,  Tipi = "ACF",  stringsAsFactors = FALSE),
      data.frame(Vonesa = ap$pacf$lag, Vlera = ap$pacf$value, Tipi = "PACF", stringsAsFactors = FALSE)
    )

    conf <- ap$conf

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

    base_tbl <- data.frame(
      Serie     = c("Original (niveli)", "First difference (Δ)"),
      Statistic = NA_real_,
      `p-value` = NA_real_,
      Method    = NA_character_,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )

    ts_ok <- validate_ts_ready(d0, input$stat_series, FREQ_POLICY, min_n = 20L)
    if (!isTRUE(ts_ok$ok)) {
      base_tbl$Method <- ts_ok$message %||% TS_INCOMPLETE_MSG
      return(list(
        ok = FALSE, reason = "invalid_ts",
        msg = ts_ok$message %||% TS_INCOMPLETE_MSG,
        y_len = ts_ok$n %||% 0L,
        table = base_tbl,
        p_lvl = NA_real_, p_diff = NA_real_
      ))
    }

    y <- suppressWarnings(as.numeric(ts_ok$data$y))

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

    adf <- run_adf(y)

    fill_row <- function(tbl, row_idx, obj) {
      if (!is.null(obj)) {
        tbl$Statistic[row_idx] <- obj$statistic
        tbl$`p-value`[row_idx] <- obj$p_value
        tbl$Method[row_idx]    <- obj$method
      } else {
        tbl$Method[row_idx]    <- "ADF (tseries::adf.test)"
      }
      tbl
    }

    out_tbl <- base_tbl
    out_tbl <- fill_row(out_tbl, 1, adf$level)
    out_tbl <- fill_row(out_tbl, 2, adf$diff)

    out_tbl$Statistic <- round(out_tbl$Statistic, 4)
    out_tbl$`p-value` <- formatC(out_tbl$`p-value`, format = "f", digits = 4)

    p_lvl  <- adf$level$p_value %||% NA_real_
    p_diff <- adf$diff$p_value  %||% NA_real_

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

    if (identical(res$reason, "invalid_ts")) {
      return(HTML(
        paste0(
          "<p style='margin-top:10px; font-size: 13px; line-height: 1.45;'>",
          "<b>Interpretim (ADF):</b> ", res$msg %||% TS_INCOMPLETE_MSG,
          "</p>"
        )
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

  .model_fits <- reactive({
    req(df_dyn(), input$model_series)

    d0 <- df_dyn()

    ts_ok <- validate_ts_ready(d0, input$model_series, FREQ_POLICY, min_n = 20L)
    if (!isTRUE(ts_ok$ok)) {
      return(list(ok = FALSE, msg = ts_ok$message %||% TS_INCOMPLETE_MSG))
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
