source("helpers.R")
source("server_plots.R")

ui <- fluidPage(
  shinyjs::useShinyjs(),
  
  tags$head(
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    
    tags$link(rel = "stylesheet", type = "text/css", href = "custom-style.css"),
    
    tags$style(HTML("
      html, body { height: 100%; margin: 0 !important; }
      body > .container-fluid{
        padding-left: 0 !important;
        padding-right: 0 !important;
        margin: 0 !important;
        width: 100% !important;
      }
      ")),
    
    tags$script(src = "bg.js"),
    tags$script(src = "sidebar.js"),
    tags$script(src = "plotly-animate.js")
  ),
  
  # Background
  tags$div(
    id = "bg-wrapper",
    tags$div(class = "bg-layer current",
             style = "background-image:url('images/image0.jpeg');"),
    tags$div(class = "bg-layer next")
  ),
  tags$div(id = "bg-overlay"),
  
  div(
  class = "app-shell",
  
  # Backdrop
  tags$div(
    id = "sidebar_backdrop",
    class = "sidebar-backdrop",
    `aria-hidden` = "true"
  ),
  
    # Sidebar
    div(
    id = "app_sidebar",
    class = "app-sidebar",

    div(
      class = "sidebar-main",

      div(class = "menu-title", "Serite Kohore - Bujqesia Shqiperi (1998–2024)"),

      actionButton("go_overview",   "Overview",            class = "btn btn-light nav-btn"),
      actionButton("go_eda_ts",     "EDA – Time Series",   class = "btn btn-light nav-btn"),
      actionButton("go_eda_rel",    "EDA – Relationships", class = "btn btn-light nav-btn"),
      actionButton("go_stationary", "Stationarity",        class = "btn btn-light nav-btn"),
      actionButton("go_modeling",   "Modeling",            class = "btn btn-light nav-btn"),
      actionButton("go_forecast",   "Forecasting",         class = "btn btn-light nav-btn"),
      actionButton("go_wrapup",     "Wrap-up",             class = "btn btn-light nav-btn")
    ),

    div(
      class = "sidebar-footer-wrap",
      div(class = "glass-divider"),
      div(
        class = "sidebar-footer",
        tags$small(
          "By ",
          tags$a(
            "Amarildo Alla",
            href = "https://github.com/USERNAME_YT",
            target = "_blank",
            rel = "noopener noreferrer",
            class = "github-link"
          )
        )
      )
    )
  ),
    
    # Content
    div(
      class = "app-content",
      div(
        class = "app-content-inner",

        # Hamburger (scrolls away with content)
        tags$button(
          id = "toggle_sidebar",
          type = "button",
          class = "hamburger-btn",
          `aria-label` = "Open menu",
          tags$span(),
          tags$span(),
          tags$span()
        ),
        
        tabsetPanel(
          id = "main_tabs",
          type = "hidden",
          selected = "tab_overview",
          
          tabPanel(
            title = "Overview",
            value = "tab_overview",

            # Header box
            div(
              class = "section-box",
              h3("Hyrje & Të dhënat (1998–2024)"),
              p("Ky është versioni MVP i app-it Shiny, i ndërtum mbi analizën Rmd. Qëllimi është me e bo analizën më interaktive dhe më të lehtë për me u navigu.")
            ),

            fluidRow(
              column(
                6,

                div(
                  class = "section-box",
                  h4("Konteksti"),
                  p("Bujqësia në Shqipëri ndikohet fort nga faktorë klimatikë dhe ndryshime strukturore. Analiza me seri kohore ndihmon me kuptu prirjet afatgjata dhe me ndërtu parashikime të besueshme."),
                  tags$ul(
                    tags$li("EDA interaktive (plotly)"),
                    tags$li("Stacionaritet + diferencim"),
                    tags$li("Parashikim me SES / Holt / ARIMA"),
                    tags$li("Opsione Advanced (VAR, GARCH) – sipas disponueshmërisë së paketave")
                  )
                ),

                tags$details(
                  class = "section-box",
                  open = FALSE,
                  tags$summary(tags$strong("Abstrakt (hap / mbyll)")),
                  p("Ky studim analizon dinamikën afatgjatë të prodhimit bujqësor në Shqipëri (1998–2024) me metoda të serive kohore, duke synuar identifikimin e prirjeve dhe vlerësimin e mundësisë së parashikimit."),
                  p("Metodat kryesore: analiza eksploruese, teste stacionariteti (ADF), sheshim eksponencial dhe ARIMA; si shtesë ilustrim teorik me simulime ARMA.")
                ),

                tags$details(
                  class = "section-box",
                  open = FALSE,
                  tags$summary(tags$strong("Metodologjia (hap / mbyll)")),
                  tags$ul(
                    tags$li("EDA: prirje, variabilitet, marrëdhënie mes variablave"),
                    tags$li("Stacionaritet: ADF + diferencim nëse duhet"),
                    tags$li("Forecasting: Exponential smoothing (SES/Holt) dhe ARIMA"),
                    tags$li("Opsionale: ARMA simulime, VAR/IRF, GARCH")
                  )
                )
              ),

              column(
                6,

                fluidRow(
                  column(
                    12,
                    div(
                      class = "section-box",
                      h4("Dataset Information"),
                      tableOutput("data_info_tbl")
                    )
                  )
                ),

                fluidRow(
                  column(
                    12,
                    div(
                      class = "section-box",
                      h4("Variables Description"),
                      tableOutput("variables_tbl")
                    )
                  )
                )
              )
            ),

            br(),

            fluidRow(
              column(
                12,
                div(
                  class = "section-box",
                  h4("Summary Statistics"),
                  tableOutput("summary_tbl")
                )
              )
            )
          ),
          
          tabPanel(
            title = "EDA – Time Series",
            value = "tab_eda_ts",

            div(
              class = "section-box",
              h3("Exploratory Data Analysis – Time Series"),
              p("Ky seksion analizon formen, trendin dhe shperndarjen e serive kohore.")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput(
                  "eda_series",
                  "Zgjidh serine",
                  choices = c(
                    "Production (ton)" = "Production_ton",
                    "Yield (ton/ha)"   = "Yield_ton_per_ha",
                    "Rainfall (mm)"    = "Rainfall_mm"
                  ),
                  selected = "Production_ton"
                ),

                sliderInput(
                  "roll_k",
                  "Rolling window (vite)",
                  min = 3,
                  max = 10,
                  value = 5,
                  step = 1
                )
              ),

              mainPanel(
                div(
                  class = "section-box",
                  div(class = "plot-container",
                      plotlyOutput("eda_ts_raw", height = "360px"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  div(class = "plot-container",
                      plotlyOutput("eda_ts_roll", height = "360px"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  div(class = "plot-container",
                      plotlyOutput("eda_ts_dist", height = "360px"))
                )

              )
            )
          ),
          tabPanel(
            title = "EDA – Relationships",
            value = "tab_eda_rel",

            div(
              class = "section-box",
              h3("Exploratory Data Analysis – Relationships"),
              p("Ky seksion analizon marredheniet mes variablave kryesore bujqesore.")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput(
                  "rel_x",
                  "Zgjidh variablen X",
                  choices = c(
                    "Production (ton)" = "Production_ton",
                    "Yield (ton/ha)"   = "Yield_ton_per_ha",
                    "Rainfall (mm)"    = "Rainfall_mm"
                  ),
                  selected = "Rainfall_mm"
                ),

                selectInput(
                  "rel_y",
                  "Zgjidh variablen Y",
                  choices = c(
                    "Production (ton)" = "Production_ton",
                    "Yield (ton/ha)"   = "Yield_ton_per_ha",
                    "Rainfall (mm)"    = "Rainfall_mm"
                  ),
                  selected = "Production_ton"
                )
              ),

              mainPanel(
                div(
                  class = "section-box",

                  h4("Scatter plot"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("eda_rel_scatter", height = "420px")
                  )
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",

                  h4("Correlation matrix"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("eda_rel_corr", height = "420px")
                  )
                )

              )
            )
          ),
          tabPanel(
            title = "Stationarity",
            value = "tab_stationary",

            div(
              class = "section-box",
              h3("Stationarity & Transformations"),
              p("Ky seksion analizon stacionaritetin e serive kohore dhe transformimet e nevojshme per modelim.")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput(
                  "stat_series",
                  "Zgjidh serine",
                  choices = c(
                    "Production (ton)" = "Production_ton",
                    "Yield (ton/ha)"   = "Yield_ton_per_ha",
                    "Rainfall (mm)"    = "Rainfall_mm"
                  ),
                  selected = "Production_ton"
                )
              ),

              mainPanel(
                div(
                  class = "section-box",

                  h4("First difference"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("stat_diff_plot", height = "360px")
                  )),

                  div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("ACF & PACF"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("stat_acf_pacf", height = "420px")
                  )),

                  div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("ADF Test"),
                  div(
                    class = "table-wrap",
                    tableOutput("stat_adf_tbl")
                  )
                )
              )
            )
          ),
          tabPanel(
            title = "Modeling",
            value = "tab_modeling",

            div(
              class = "section-box",
              h3("Time Series Modeling"),
              p("Ky seksion krahason modele ETS dhe ARIMA per parashikim.")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput(
                  "model_series",
                  "Zgjidh serine",
                  choices = c(
                    "Production (ton)" = "Production_ton",
                    "Yield (ton/ha)"   = "Yield_ton_per_ha",
                    "Rainfall (mm)"    = "Rainfall_mm"
                  ),
                  selected = "Production_ton"
                ),

                sliderInput(
                  "model_h",
                  "Forecast horizon (vite)",
                  min = 1,
                  max = 10,
                  value = 5,
                  step = 1
                )
              ),

              mainPanel(
                div(
                  class = "section-box",

                  h4("Forecast comparison"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("model_plot", height = "480px")
                  )),

                  div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("Model Accuracy (Training set)"),
                  div(
                    class = "table-wrap",
                    tableOutput("model_acc_tbl")
                  )
                )
              )
            )
          ),
          tabPanel(
            title = "Forecast",
            value = "tab_forecast",

            sidebarLayout(
              position = "left",

              sidebarPanel(
                h4("Forecast settings"),

                selectInput(
                  "forecast_series",
                  "Seria",
                  choices = c(
                    "Production (ton)" = "Production_ton",
                    "Yield (ton/ha)"   = "Yield_ton_per_ha",
                    "Rainfall (mm)"    = "Rainfall_mm"
                  )
                ),

                selectInput(
                  "method",
                  "Metoda",
                  choices = c(
                    "SES"   = "ses",
                    "Holt"  = "holt",
                    "ARIMA" = "arima"
                  )
                ),

                sliderInput("h", "Horizonti i parashikimit (vite)", 1, 10, 5),

                hr(),
                p("Grafiku paraqet vlerat e observuara dhe parashikimin për vitet e ardhshme, së bashku me intervalet e pasigurisë.")
              ),

              mainPanel(
                div(
                  class = "section-box",

                  h4("Forecast"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("forecast_plot", height = "520px")
                  )),

                  div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("Forecast accuracy"),
                  div(
                    class = "table-wrap",
                    uiOutput("forecast_metrics")
                  )
                )
              )
            )
          ),
          tabPanel(
            title = "Wrap-up",
            value = "tab_wrapup",

            # =========================
            # Conclusion
            # =========================
            div(
              class = "section-box",
              h3("Conclusion"),
              tags$ul(
                tags$li("Prodhimi bujqësor në Shqipëri shfaq trend afatgjatë rritës me variabilitet vjetor."),
                tags$li("Testet e stacionaritetit tregojnë nevojën për diferencim përpara modelimit ARIMA."),
                tags$li("Metodat SES dhe Holt janë efektive për parashikim afatshkurtër."),
                tags$li("ARIMA ofron fleksibilitet më të lartë për modelim dhe parashikim."),
                tags$li("Aplikacioni Shiny shërben si mjet eksplorues, ndërsa analiza e plotë dokumentohet në raportin Rmd.")
              )
            ),

            # =========================
            # Decomposition – Methodological note
            # =========================
            div(
              class = "section-box",
              tags$details(
                open = FALSE,
                tags$summary(
                  tags$strong("Time Series Decomposition – Methodological Note")
                ),
                p(
                  "Seasonal decomposition was evaluated as part of the analysis workflow."
                ),
                p(
                  strong("Result: "),
                  "Not applicable for this dataset."
                ),
                tags$ul(
                  tags$li(
                    "The data are annual (frequency = 1), therefore no seasonal component can be identified."
                  ),
                  tags$li(
                    "The analysis focuses instead on long-term trend, variability, stationarity and forecasting."
                  )
                )
              )
            ),

            # =========================
            # References
            # =========================
            div(
              class = "section-box",
              h3("References"),
              tags$ul(
                tags$li("INSTAT Albania – Agricultural Statistics"),
                tags$li("Our World in Data – Agriculture & Climate"),
                tags$li("Hyndman & Athanasopoulos (2018). Forecasting: Principles and Practice.")
              )
            )
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  observeEvent(input$go_overview, {updateTabsetPanel(session, "main_tabs", "tab_overview")})
  observeEvent(input$go_eda_ts, {updateTabsetPanel(session, "main_tabs", "tab_eda_ts")})
  observeEvent(input$go_eda_rel, {updateTabsetPanel(session, "main_tabs", "tab_eda_rel")})
  observeEvent(input$go_stationary, {updateTabsetPanel(session, "main_tabs", "tab_stationary")})
  observeEvent(input$go_modeling, {updateTabsetPanel(session, "main_tabs", "tab_modeling")})
  observeEvent(input$go_forecast, {updateTabsetPanel(session, "main_tabs", "tab_forecast")})
  observeEvent(input$go_wrapup, {updateTabsetPanel(session, "main_tabs", "tab_wrapup")})

  df <- reactive({
    read_data_safe(DATA_PATH)
  })
  server_plots(input, output, session, df)
}
shinyApp(ui, server)
