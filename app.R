# Funksionet jetojnë te R/: Shiny i ngarkon vetë para app.R.
suppressPackageStartupMessages({
  library(shiny)
  library(shinyjs)
  library(plotly)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(forecast)
  library(scales)
  library(tseries)
  library(DT)
  library(jsonlite)
  library(zoo)
})
options(scipen = 999, shiny.maxRequestSize = UPLOAD_MAX_MB * 1024^2)   # V-28 a

# Të dhënat e përdoruesit te storage/ (migrim që kopjon), fotot e ngarkuara si
# "user-images/" dhe gjuha nga settings.json.
init_storage()
migrate_legacy_images()   # V-22 b: fotot e vjetra të www/images/ -> storage/images/
addResourcePath(USER_IMAGES_PREFIX, IMAGES_DIR)
set_lang(read_settings()$lang)

# ui si funksion: lexohet për çdo kërkesë, që pas session$reload() të dalin
# gjuha e re dhe state-i i ruajtur i background-it (mod_background_ui).
ui <- function(req) {
  app_page(
    main_tabs = tabsetPanel(
      id = "main_tabs",
      type = "hidden",
      selected = page_tab(DEFAULT_PAGE),

      tabPanel(
        title = tr("page.settings.menu"),
        value = page_tab("settings"),

        div(class="glass-divider"),

        # ===== Dataset section =====
        mod_datasets_ui("datasets"),

        div(class="glass-divider"),

        # ===== Background section (Faza 6) =====
        mod_background_ui("bg"),

        div(class = "glass-divider"),

        # ===== Gjuha (V-09) =====
        section_box(
          h4(tr("settings.language")),
          radioButtons(
            "app_lang",
            label    = NULL,
            choices  = setNames(names(LANGS), unname(LANGS)),
            selected = current_lang(),
            inline   = TRUE
          )
        )
      ),

      tabPanel(
        title = tr("page.overview.menu"),
        value = page_tab("overview"),

        mod_overview_ui("overview")
      ),

      tabPanel(
        title = tr("page.eda_ts.menu"),
        value = page_tab("eda_ts"),

        mod_eda_ts_ui("eda_ts")
      ),

      tabPanel(
        title = tr("page.eda_rel.menu"),
        value = page_tab("eda_rel"),

        mod_eda_rel_ui("eda_rel")
      ),

      tabPanel(
        title = tr("page.stationary.menu"),
        value = page_tab("stationary"),

        mod_stationarity_ui("stationary")
      ),

      tabPanel(
        title = tr("page.modeling.menu"),
        value = page_tab("modeling"),

        mod_modeling_ui("modeling")
      ),

      tabPanel(
        title = tr("page.forecast.menu"),
        value = page_tab("forecast"),

        mod_forecast_ui("forecast")
      )
    ),

    modals = tagList(mod_datasets_modals_ui("datasets"), mod_background_modals_ui("bg"))
  )
}

server <- function(input, output, session) {
  mod_nav_server(input, output, session)

  # Gjuha (V-09): ruhet te settings.json, pastaj faqja rifreskohet në gjuhën e re.
  observeEvent(input$app_lang, {
    lang <- input$app_lang
    if (!lang %in% names(LANGS) || identical(lang, current_lang())) return()
    write_settings(modifyList(read_settings(), list(lang = lang)))
    set_lang(lang)
    session$reload()
  }, ignoreInit = TRUE)

  # =========================================================
  # 2) DATASET-I AKTIV (V-04): një burim i vetëm
  # =========================================================
  active <- mod_datasets_server("datasets")
  series <- reactive(prepare_series(active()))
  fits   <- model_store()   # ETS/ARIMA të përbashkët për Modelimin dhe Parashikimin (P-07)

  # =========================================================
  # 3) BACKGROUND (Faza 6)
  # =========================================================
  mod_background_server("bg")

  mod_overview_server("overview", active, series, reactive(input$main_tabs))
  mod_eda_ts_server("eda_ts", series)
  mod_eda_rel_server("eda_rel", series)
  mod_stationarity_server("stationary", series)
  mod_modeling_server("modeling", series, fits)
  mod_forecast_server("forecast", series, fits)
}

shinyApp(ui, server)
