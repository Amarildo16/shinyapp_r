server_plots <- function(input, output, session, df) {

  # =========================
  # Overview tables
  # =========================

  output$data_info_tbl <- renderTable({
    d <- df()

    data.frame(
      Item = c(
        "Start Year",
        "End Year",
        "Number of Observations",
        "Data Source"
      ),
      Value = c(
        min(d$Year),
        max(d$Year),
        nrow(d),
        "INSTAT / Our World in Data"
      )
    )
  })

  output$variables_tbl <- renderTable({
    data.frame(
      Variable = c(
        "Production_ton",
        "Yield_ton_per_ha",
        "Rainfall_mm"
      ),
      Description = c(
        "Total agricultural production (tons)",
        "Agricultural yield (tons per hectare)",
        "Annual rainfall (millimeters)"
      )
    )
  })

  output$summary_tbl <- renderTable({
    d <- df() %>% select(-Year)

    stats <- data.frame(
      Variable = names(d),
      Mean = sapply(d, mean, na.rm = TRUE),
      SD   = sapply(d, sd,   na.rm = TRUE),
      Min  = sapply(d, min,  na.rm = TRUE),
      Max  = sapply(d, max,  na.rm = TRUE),
      check.names = FALSE
    )

    num_cols <- sapply(stats, is.numeric)
    stats[num_cols] <- lapply(stats[num_cols], function(x) round(x, 2))

    stats
  })

  # =========================
  # EDA – Time Series (NEW)
  # =========================

  output$eda_ts_raw <- renderPlotly({
  req(df(), input$eda_series)

  d <- df() %>%
    select(Year, value = all_of(input$eda_series))

  p <- ggplot(d, aes(x = Year, y = value)) +
    geom_line(size = 1, color = "white") +
    labs(
      title = paste0("Raw time series – ", input$eda_series),
      x = "Year",
      y = input$eda_series
    ) +
    theme_minimal() +
    theme(
      plot.background  = element_blank(),
      panel.background = element_blank(),
      text = element_text(color = "white"),
      axis.text = element_text(color = "white"),
      axis.title = element_text(color = "white")
    )

  ggplotly(p) %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor  = "rgba(0,0,0,0)",
      font = list(color = "white"),
      xaxis = list(gridcolor = "rgba(255,255,255,0.15)"),
      yaxis = list(gridcolor = "rgba(255,255,255,0.15)")
    )
  })

  output$eda_ts_roll <- renderPlotly({
  req(df(), input$eda_series, input$roll_k)

  d <- df() %>%
    arrange(Year) %>%
    mutate(
      roll_mean = zoo::rollmean(
        .data[[input$eda_series]],
        k = input$roll_k,
        fill = NA,
        align = "right"
      )
    )

  p <- ggplot(d, aes(x = Year)) +
    geom_line(
      aes(y = .data[[input$eda_series]]),
      color = "rgba(0,0,0,0.35)",
      linewidth = 0.9
    ) +
    geom_line(
      aes(y = roll_mean),
      color = "#ff3b30",
      linewidth = 1.6
    ) +
    labs(
      title = paste0("Rolling mean (k = ", input$roll_k, ")"),
      subtitle = input$eda_series,
      x = NULL,
      y = NULL
    ) +
    theme_minimal(base_size = 13) +
    theme(
      panel.background = element_rect(fill = "transparent", color = NA),
      plot.background  = element_rect(fill = "transparent", color = NA),
      panel.grid.major = element_line(color = "rgba(0,0,0,0.08)", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      axis.text        = element_text(color = "rgba(0,0,0,0.65)"),
      plot.title       = element_text(face = "bold"),
      plot.subtitle    = element_text(color = "rgba(0,0,0,0.55)")
    )

  ggplotly(p, tooltip = c("x", "y")) %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor  = "rgba(0,0,0,0)",
      margin = list(t = 60, l = 40, r = 20, b = 40),
      hovermode = "x unified"
    )
  })

  output$eda_ts_dist <- renderPlotly({
  req(df(), input$eda_series)

  d <- df()

  p <- ggplot(d, aes(x = .data[[input$eda_series]])) +
    geom_histogram(
      aes(y = after_stat(density)),
      bins = 18,
      fill = "rgba(0,122,255,0.35)",
      color = "rgba(0,0,0,0.15)"
    ) +
    geom_density(
      color = "#ff3b30",
      linewidth = 1.4
    ) +
    labs(
      title = "Distribution",
      subtitle = input$eda_series,
      x = NULL,
      y = NULL
    ) +
    theme_minimal(base_size = 13) +
    theme(
      panel.background = element_rect(fill = "transparent", color = NA),
      plot.background  = element_rect(fill = "transparent", color = NA),
      panel.grid.major = element_line(color = "rgba(0,0,0,0.08)", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      axis.text        = element_text(color = "rgba(0,0,0,0.65)"),
      plot.title       = element_text(face = "bold"),
      plot.subtitle    = element_text(color = "rgba(0,0,0,0.55)")
    )

  ggplotly(p, tooltip = "x") %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor  = "rgba(0,0,0,0)",
      margin = list(t = 60, l = 40, r = 20, b = 40)
    )
  })

  # =========================
  # EDA – Relationships
  # =========================

  output$eda_rel_scatter <- renderPlotly({
  req(df(), input$rel_x, input$rel_y)

  d <- df()

  p <- ggplot(
    d,
    aes(
      x = .data[[input$rel_x]],
      y = .data[[input$rel_y]]
    )
  ) +
    geom_point(
      size = 2.6,
      alpha = 0.55,
      color = "rgba(0,122,255,0.55)"
    ) +
    geom_smooth(
      method = "lm",
      se = FALSE,
      linewidth = 1.4,
      color = "#ff3b30"
    ) +
    labs(
      title = "Relationship",
      subtitle = paste(input$rel_x, "vs", input$rel_y),
      x = NULL,
      y = NULL
    ) +
    theme_minimal(base_size = 13) +
    theme(
      panel.background = element_rect(fill = "transparent", color = NA),
      plot.background  = element_rect(fill = "transparent", color = NA),

      panel.grid.major = element_line(
        color = "rgba(0,0,0,0.08)",
        linewidth = 0.3
      ),
      panel.grid.minor = element_blank(),

      axis.text = element_text(
        color = "rgba(0,0,0,0.65)"
      ),

      plot.title = element_text(
        face = "bold",
        size = 15
      ),
      plot.subtitle = element_text(
        color = "rgba(0,0,0,0.55)",
        size = 12
      )
    )

  ggplotly(p, tooltip = c("x", "y")) %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor  = "rgba(0,0,0,0)",

      margin = list(
        t = 60,
        l = 40,
        r = 20,
        b = 40
      ),

      hovermode = "closest"
    )
  })

    output$eda_rel_corr <- renderPlotly({
  req(df())

  d <- df() %>% select(-Year)

  corr_mat <- cor(d, use = "complete.obs")

  corr_df <- as.data.frame(as.table(corr_mat))
  colnames(corr_df) <- c("Var1", "Var2", "Correlation")

  p <- ggplot(
    corr_df,
    aes(x = Var1, y = Var2, fill = Correlation)
  ) +
    geom_tile(color = "rgba(255,255,255,0.35)", linewidth = 0.4) +
    scale_fill_gradient2(
      low = "#0a84ff",
      mid = "white",
      high = "#ff3b30",
      midpoint = 0
    ) +
    geom_text(
      aes(label = round(Correlation, 2)),
      color = "rgba(0,0,0,0.75)",
      size = 4.2
    ) +
    labs(
      title = "Correlation Matrix",
      x = NULL,
      y = NULL
    ) +
    theme_minimal(base_size = 13) +
    theme(
      panel.background = element_rect(fill = "transparent", color = NA),
      plot.background  = element_rect(fill = "transparent", color = NA),

      panel.grid = element_blank(),

      axis.text.x = element_text(
        color = "rgba(255,255,255,0.92)",
        size = 12
      ),
      axis.text.y = element_text(
        color = "rgba(255,255,255,0.92)",
        size = 12
      ),

      plot.title = element_text(
        face = "bold",
        size = 15,
        color = "rgba(255,255,255,0.95)"
      )
    )

  ggplotly(p, tooltip = "Correlation") %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor  = "rgba(0,0,0,0)",

      margin = list(
        t = 60,
        l = 80,
        r = 20,
        b = 60
      )
    )
  })

    # =========================
    # Decomposition
    # =========================

    output$decomp_plot <- renderPlotly({
    req(df(), input$decomp_series, input$decomp_type)

    y <- ts(
        df()[[input$decomp_series]],
        start = min(df()$Year),
        frequency = 1
    )

    # =========================
    # Annual data -> no seasonal decomposition
    # =========================
    if (frequency(y) < 2) {

        p <- ggplot() +
        annotate(
            "text",
            x = 0,
            y = 0,
            label = paste(
            "Seasonal decomposition is not applicable",
            "for annual time series (frequency = 1).",
            "",
            "This analysis therefore focuses on",
            "long-term trend and variability.",
            sep = "\n"
            ),
            size = 5,
            hjust = 0.5,
            vjust = 0.5
        ) +
        theme_void() +
        labs(
            title = paste(
            "Decomposition –",
            input$decomp_series
            )
        )

        return(ggplotly(p))
    }

    # =========================
    # (This part will run only if freq >= 2)
    # =========================
    if (input$decomp_type == "classical") {

        dec <- decompose(y)

        dec_df <- data.frame(
        Year = time(y),
        Observed  = dec$x,
        Trend     = dec$trend,
        Seasonal  = dec$seasonal,
        Remainder = dec$random
        )

    } else {

        dec <- stl(y, s.window = "periodic")

        dec_df <- data.frame(
        Year = time(y),
        Observed  = dec$time.series[, "trend"] +
                    dec$time.series[, "seasonal"] +
                    dec$time.series[, "remainder"],
        Trend     = dec$time.series[, "trend"],
        Seasonal  = dec$time.series[, "seasonal"],
        Remainder = dec$time.series[, "remainder"]
        )
    }

    dec_long <- tidyr::pivot_longer(
        dec_df,
        cols = -Year,
        names_to = "Component",
        values_to = "Value"
    )

    p <- ggplot(dec_long, aes(x = Year, y = Value)) +
        geom_line() +
        facet_wrap(~ Component, scales = "free_y", ncol = 1) +
        labs(
        title = paste0(
            "Decomposition (",
            toupper(input$decomp_type),
            ") – ",
            input$decomp_series
        ),
        x = "Year",
        y = ""
        ) +
        theme_minimal()

    ggplotly(p)
    })
    # =========================
    # Stationarity & Transformations
    # =========================

    output$stat_diff_plot <- renderPlotly({
  req(df(), input$stat_series)

  y <- ts(
    df()[[input$stat_series]],
    start = min(df()$Year),
    frequency = 1
  )

  dy <- diff(y)

  d <- data.frame(
    Year = time(dy),
    Differenced = as.numeric(dy)
  )

  p <- ggplot(d, aes(x = Year, y = Differenced)) +
    geom_line(
      linewidth = 1.2,
      color = "#0a84ff"
    ) +
    labs(
      title = paste0("First Difference – ", input$stat_series),
      x = "Year",
      y = "Differenced value"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      panel.background = element_rect(fill = "transparent", color = NA),
      plot.background  = element_rect(fill = "transparent", color = NA),
      panel.grid.major = element_line(color = "rgba(255,255,255,0.15)"),
      panel.grid.minor = element_blank(),

      axis.text.x = element_text(
        color = "rgba(255,255,255,0.92)",
        size = 12
      ),
      axis.text.y = element_text(
        color = "rgba(255,255,255,0.92)",
        size = 12
      ),

      axis.title.x = element_text(
        color = "rgba(255,255,255,0.85)"
      ),
      axis.title.y = element_text(
        color = "rgba(255,255,255,0.85)"
      ),

      plot.title = element_text(
        face = "bold",
        size = 15,
        color = "rgba(255,255,255,0.95)"
      )
    )

  ggplotly(p) %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor  = "rgba(0,0,0,0)",
      margin = list(
        t = 60,
        l = 70,
        r = 20,
        b = 60
      )
    )
  })

    output$stat_acf_pacf <- renderPlotly({
  req(df(), input$stat_series)

  y <- ts(
    df()[[input$stat_series]],
    start = min(df()$Year),
    frequency = 1
  )

  dy <- diff(y)

  acf_obj  <- acf(dy, plot = FALSE)
  pacf_obj <- pacf(dy, plot = FALSE)

  acf_df <- data.frame(
    Lag   = as.numeric(acf_obj$lag[-1]),
    Value = as.numeric(acf_obj$acf[-1]),
    Type  = "ACF"
  )

  pacf_df <- data.frame(
    Lag   = as.numeric(pacf_obj$lag),
    Value = as.numeric(pacf_obj$acf),
    Type  = "PACF"
  )

  df_plot <- rbind(acf_df, pacf_df)

  conf <- 1.96 / sqrt(length(dy))

  p <- ggplot(df_plot, aes(x = Lag, y = Value)) +
    geom_col(
      fill = "rgba(10,132,255,0.75)",
      width = 0.7
    ) +
    geom_hline(
      yintercept = c(-conf, conf),
      linetype = "dashed",
      color = "rgba(255,255,255,0.6)"
    ) +
    facet_wrap(~ Type, scales = "free_y", ncol = 1) +
    labs(
      title = paste0("ACF & PACF – ", input$stat_series),
      x = "Lag",
      y = "Correlation"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      panel.background = element_rect(fill = "transparent", color = NA),
      plot.background  = element_rect(fill = "transparent", color = NA),

      panel.grid.major = element_line(color = "rgba(255,255,255,0.15)"),
      panel.grid.minor = element_blank(),

      strip.background = element_rect(
        fill = "rgba(255,255,255,0.18)",
        color = NA
      ),
      strip.text = element_text(
        color = "rgba(255,255,255,0.95)",
        face = "bold"
      ),

      axis.text.x = element_text(
        color = "rgba(255,255,255,0.92)",
        size = 11
      ),
      axis.text.y = element_text(
        color = "rgba(255,255,255,0.92)",
        size = 11
      ),

      axis.title.x = element_text(
        color = "rgba(255,255,255,0.85)"
      ),
      axis.title.y = element_text(
        color = "rgba(255,255,255,0.85)"
      ),

      plot.title = element_text(
        face = "bold",
        size = 15,
        color = "rgba(255,255,255,0.95)"
      )
    )

  ggplotly(p) %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor  = "rgba(0,0,0,0)",
      margin = list(
        t = 70,
        l = 70,
        r = 20,
        b = 60
      )
    )
  })

    output$stat_adf_tbl <- renderTable({
    req(df(), input$stat_series)

    y <- ts(
        df()[[input$stat_series]],
        start = min(df()$Year),
        frequency = 1
    )

    dy <- diff(y)

    adf <- tseries::adf.test(dy)

    data.frame(
        Statistic = c("ADF statistic", "p-value"),
        Value = c(
        round(adf$statistic, 4),
        round(adf$p.value, 4)
        )
    )
    })
    # =========================
    # Modeling – ETS & ARIMA
    # =========================

    output$model_plot <- renderPlotly({
      req(df(), input$model_series, input$model_h)

      y <- ts(
        df()[[input$model_series]],
        start = min(df()$Year),
        frequency = 1
      )

      fit_ets   <- ets(y)
      fit_arima <- auto.arima(
        y,
        seasonal = FALSE,
        stepwise = FALSE,
        approximation = FALSE
      )

      fc_ets   <- forecast(fit_ets, h = input$model_h)
      fc_arima <- forecast(fit_arima, h = input$model_h)

      obs_df <- data.frame(
        Year  = as.numeric(time(y)),
        Value = as.numeric(y),
        Type  = "Observed"
      )

      ets_df <- data.frame(
        Year  = as.numeric(time(fc_ets$mean)),
        Value = as.numeric(fc_ets$mean),
        Type  = "ETS"
      )

      arima_df <- data.frame(
        Year  = as.numeric(time(fc_arima$mean)),
        Value = as.numeric(fc_arima$mean),
        Type  = "ARIMA"
      )

      plot_df <- rbind(obs_df, ets_df, arima_df)

      p <- ggplot(plot_df, aes(x = Year, y = Value, color = Type)) +
    geom_line(size = 1.1) +
    labs(
      title = paste("Forecast comparison –", input$model_series),
      x = "Year",
      y = input$model_series
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.background   = element_rect(fill = "transparent", color = NA),
      panel.background  = element_rect(fill = "transparent", color = NA),
      panel.grid.major  = element_line(color = "rgba(255,255,255,0.18)"),
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

  ggplotly(p) %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor  = "rgba(0,0,0,0)"
    ) 
  })

    output$model_acc_tbl <- renderTable({
      req(df(), input$model_series)

      y <- ts(
        df()[[input$model_series]],
        start = min(df()$Year),
        frequency = 1
      )

      fit_ets   <- ets(y)
      fit_arima <- auto.arima(
        y,
        seasonal = FALSE,
        stepwise = FALSE,
        approximation = FALSE
      )

      acc_ets   <- accuracy(fit_ets)
    acc_arima <- accuracy(fit_arima)

    get_metric <- function(acc, metric) {
      val <- if ("Training set" %in% rownames(acc)) {
        acc["Training set", metric]
      } else {
        acc[1, metric]
      }
      as.numeric(val)
    }

    data.frame(
      Model = c("ETS", "ARIMA"),
      RMSE  = round(c(
        get_metric(acc_ets, "RMSE"),
        get_metric(acc_arima, "RMSE")
      ), 3),
      MAE   = round(c(
        get_metric(acc_ets, "MAE"),
        get_metric(acc_arima, "MAE")
      ), 3),
      MAPE  = round(c(
        get_metric(acc_ets, "MAPE"),
        get_metric(acc_arima, "MAPE")
      ), 3)
    )
  })
  # =========================================================
  # Forecasting – Shared reactive objects
  # =========================================================

  series_ts <- reactive({
    req(df(), input$forecast_series)

    ts(
      df()[[input$forecast_series]],
      start = min(df()$Year),
      frequency = 1
    )
  })

  fitted_model <- reactive({
    req(series_ts(), input$method, input$h)

    y <- series_ts()

    if (input$method == "ses") {

      forecast::ses(y, h = input$h)

    } else if (input$method == "holt") {

      forecast::holt(y, h = input$h)

    } else {

      fit <- forecast::auto.arima(
        y,
        seasonal = FALSE,
        stepwise = FALSE,
        approximation = FALSE
      )

      forecast::forecast(fit, h = input$h)
    }
  })

  # =========================================================
  # Forecast plot (Observed + Forecast + 80% CI)
  # =========================================================

  output$forecast_plot <- renderPlotly({
  req(series_ts(), fitted_model(), input$forecast_series)

  y_ts <- series_ts()
  fc   <- fitted_model()

  obs_df <- data.frame(
    Year  = as.numeric(time(y_ts)),
    Value = as.numeric(y_ts),
    Type  = "Observed"
  )

  fc_df <- data.frame(
    Year = as.numeric(time(fc$mean)),
    Mean = as.numeric(fc$mean),
    Lo80 = as.numeric(fc$lower[, "80%"]),
    Hi80 = as.numeric(fc$upper[, "80%"]),
    Type = "Forecast"
  )

  p <- ggplot() +

    geom_line(
      data = obs_df,
      aes(x = Year, y = Value),
      color = "white",
      size = 1
    ) +

    geom_ribbon(
      data = fc_df,
      aes(x = Year, ymin = Lo80, ymax = Hi80),
      fill = "white",
      alpha = 0.12
    ) +

    geom_line(
      data = fc_df,
      aes(x = Year, y = Mean),
      color = "white",
      size = 1.2,
      linetype = "solid"
    ) +

    labs(
      title = paste0(
        "Forecast – ",
        input$forecast_series,
        " (", toupper(input$method), ")"
      ),
      x = "Year",
      y = input$forecast_series
    ) +

    theme_minimal(base_size = 13) +

    theme(
      plot.background  = element_rect(fill = "transparent", color = NA),
      panel.background = element_rect(fill = "transparent", color = NA),
      panel.grid.major = element_line(color = "rgba(255,255,255,0.12)"),
      panel.grid.minor = element_blank(),

      text        = element_text(color = "white"),
      plot.title  = element_text(color = "white", face = "bold"),
      axis.title  = element_text(color = "white"),
      axis.text   = element_text(color = "white")
    )

  if (input$forecast_series == "Production_ton") {
    p <- p +
      scale_y_continuous(
        labels = scales::label_number(scale = 1e-6, suffix = " mln")
      )
  }

  ggplotly(p) %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor  = "rgba(0,0,0,0)",
      font = list(color = "white")
    )
  })

  # =========================================================
  # Forecast accuracy (Training set)
  # =========================================================

  output$forecast_metrics <- renderUI({
    req(fitted_model())

    acc <- tryCatch(
      forecast::accuracy(fitted_model()),
      error = function(e) NULL
    )

    if (is.null(acc)) {

      div(
        class = "section-box",
        p("Accuracy nuk u llogarit (kontrollo modelin ose paketat).")
      )

    } else {

      div(
        class = "section-box",
        h4("Training accuracy"),
        tableOutput("acc_tbl")
      )
    }
  })

  output$acc_tbl <- renderTable({
    acc <- forecast::accuracy(fitted_model())

    if ("Training set" %in% rownames(acc)) {
      a <- acc["Training set", c("ME", "MAE", "RMSE", "MAPE")]
    } else {
      a <- acc[1, c("ME", "MAE", "RMSE", "MAPE")]
    }

    data.frame(
      Metric = names(a),
      Value  = round(as.numeric(a), 4)
    )
  })
}