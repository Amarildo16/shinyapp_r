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
    tags$div(
      class = "bg-layer current",
      style = "background-image:url('images/image0.jpeg');"
    ),
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

        div(class = "menu-title", "Seritë kohore – Bujqësia në Shqipëri (1998–2024)"),

        actionButton("go_overview",   "Përmbledhje",                         class = "btn btn-light nav-btn"),
        actionButton("go_eda_ts",     "Analiza eksploruese – Seri kohore",   class = "btn btn-light nav-btn"),
        actionButton("go_eda_rel",    "Analiza eksploruese – Marrëdhënie",   class = "btn btn-light nav-btn"),
        actionButton("go_stationary", "Stacionariteti",                     class = "btn btn-light nav-btn"),
        actionButton("go_modeling",   "Modelimi",                           class = "btn btn-light nav-btn"),
        actionButton("go_forecast",   "Parashikimi",                        class = "btn btn-light nav-btn"),
        actionButton("go_wrapup",     "Përfundime",                         class = "btn btn-light nav-btn")
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
              href = "https://github.com/Amarildo16",
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
          `aria-label` = "Hap menunë",
          tags$span(),
          tags$span(),
          tags$span()
        ),

        tabsetPanel(
          id = "main_tabs",
          type = "hidden",
          selected = "tab_overview",

          tabPanel(
            title = "Përmbledhje",
            value = "tab_overview",

            div(
              class = "section-box",

              h3("Seritë kohore – Bujqësia në Shqipëri (1998–2024)"),

              p(
                "Ky aplikacion interaktiv (Shiny) paraqet një analizë të strukturuar të serive kohore për treguesit kryesorë të bujqësisë në Shqipëri gjatë periudhës 1998–2024, "
              ),
              p(
                "Qëllimi kryesor është të vlerësohet dinamika afatgjatë e prodhimit dhe treguesve të lidhur me të (p.sh. rendimenti, sipërfaqja e kultivuar, reshjet), "
                ,"të identifikohen prirjet dhe variabiliteti, si dhe të ndërtohen parashikime të argumentuara statistikisht."
              ),

              tags$ul(
                tags$li(tags$strong("Së pari"), " do të shihni përmbledhjen e të dhënave, përshkrimin e variablave dhe statistikat përmbledhëse (min, max, mesatare, kuartile)."),
                tags$li(tags$strong("Më pas"), " do të kaloni te analiza eksploruese (vizualizime interaktive) për të kuptuar prirjet, luhatjet dhe shpërndarjet e serive."),
                tags$li(tags$strong("Në vijim"), " vlerësohet stacionariteti përmes testit ADF dhe, kur është e nevojshme, aplikohen transformime/diferencime për stabilizimin e serisë."),
                tags$li(tags$strong("Në fund"), " ndërtohen modele parashikuese (SES/Holt dhe ARIMA) dhe paraqiten parashikimet për horizontin e zgjedhur, së bashku me interpretimin e rezultateve.")
              ),
            ),

            div(class = "glass-divider"),

              h4("Ekstrakt i të dhënave (2000–2010)"),
              p("Më poshtë paraqiten vëzhgime të renditura kronologjikisht nga seria e të dhënave, për qëllime ilustrimi dhe verifikimi të strukturës së dataset-it."),

              fluidRow(
                column(
                  8,
                  div(
                    class = "table-wrap",
                    style="padding-top: 20px;",
                    DT::DTOutput("data_sample_dt")
                  )
                ),
                column(
                  4,
                  div(
                    class = "section-box",
                    p("Tabela përmbledh treguesit kryesorë bujqësorë dhe klimatikë për çdo vit të vrojtimit."),
                    tags$ul(
                      tags$li(tags$strong("Production_ton:"), " prodhimi total bujqësor (në ton)."),
                      div(class = "glass-divider"),
                      tags$li(tags$strong("Area_ha:"), " sipërfaqja e kultivuar (në hektar)."),
                      div(class = "glass-divider"),
                      tags$li(tags$strong("Rainfall_mm:"), " reshjet vjetore (në milimetra)."),
                      div(class = "glass-divider"),
                      tags$li(tags$strong("Yield_ton_per_ha:"), " rendimenti mesatar (ton/ha), tregues i produktivitetit në raport me sipërfaqen e kultivuar.")
                    ),
                    p("Ky ekstrakt shërben për të verifikuar renditjen kohore, magnitudat e treguesve dhe koherencën e njësive matëse përpara analizës eksploruese dhe modelimit.")
                  )
                )
              ),

            div(class = "glass-divider"),

            fluidRow(
              column(
                6,

                div(
                  class = "section-box",
                  h4("Konteksti"),
                  p("Bujqësia në Shqipëri ndikohet ndjeshëm nga faktorë klimatikë dhe ndryshime strukturore. Analiza e serive kohore mundëson vlerësimin e prirjeve afatgjata, identifikimin e variabilitetit dhe ndërtimin e parashikimeve të argumentuara statistikisht."),
                  tags$ul(
                    tags$li("Analizë eksploruese interaktive (Plotly)"),
                    tags$li("Vlerësimi i stacionaritetit dhe transformimet përkatëse"),
                    tags$li("Parashikim me sheshim eksponencial (SES/Holt) dhe ARIMA"),
                    tags$li("Opsione të avancuara (p.sh. VAR, GARCH) – në varësi të disponueshmërisë së paketave")
                  )
                ),

                tags$details(
                  class = "section-box",
                  open = FALSE,
                  tags$summary(tags$strong("Abstrakti")),
                  p("Ky studim analizon dinamikën afatgjatë të prodhimit bujqësor në Shqipëri (1998–2024) përmes metodave të serive kohore, me synim identifikimin e prirjeve dhe vlerësimin e aftësisë parashikuese të modeleve."),
                  p("Metodat kryesore përfshijnë analizën eksploruese, testet e stacionaritetit (ADF), sheshimin eksponencial dhe modelet ARIMA; si shtesë, paraqiten elemente teorike përmes simulimeve ARMA.")
                )
              ),

              column(
                6,

                div(
                  class = "section-box",
                  h4("Informacion mbi të dhënat"),
                  tableOutput("data_info_tbl")
                ),

                tags$details(
                  class = "section-box",
                  open = FALSE,
                  tags$summary(tags$strong("Metodologjia")),
                  tags$ul(
                    tags$li("Analizë eksploruese: prirje, variabilitet dhe shpërndarje"),
                    tags$li("Stacionaritet: testi ADF dhe diferencimi kur kërkohet"),
                    tags$li("Parashikim: SES/Holt dhe ARIMA"),
                    tags$li("Opsionale: simulime ARMA, VAR/IRF dhe GARCH")
                  )
                )
              )
            ),

            br(),

            fluidRow(
              column(
                6,
                div(
                  class = "section-box",
                  h4("Përshkrimi i variablave"),
                  tableOutput("variables_tbl")
                )
              ),
              column(
                6,
                div(
                  class = "section-box",
                  h4("Statistika përmbledhëse"),
                  tableOutput("summary_tbl")
                )
              )
            ),
          ),

          tabPanel(
            title = "Analiza eksploruese – Seri kohore",
            value = "tab_eda_ts",

            div(
              class = "section-box",
              h3("Analiza eksploruese e të dhënave – Seri kohore"),
              p("Në këtë seksion shqyrtohen forma e serisë, prirja (trendi), variabiliteti dhe karakteristikat e shpërndarjes.")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput(
                  "eda_series",
                  "Përzgjidhni serinë",
                  choices = c(
                    "Prodhimi (ton)"     = "Production_ton",
                    "Sipërfaqja (ha)"     = "Area_ha",
                    "Rendimenti (ton/ha)"= "Yield_ton_per_ha",
                    "Reshjet (mm)"       = "Rainfall_mm"
                  ),
                  selected = "Production_ton"
                ),

                sliderInput(
                  "roll_k",
                  "Dritarja lëvizëse (vite)",
                  min = 3,
                  max = 10,
                  value = 5,
                  step = 1
                )
              ),

              mainPanel(
                div(
                  class = "section-box",
                  div(
                    class = "plot-container",
                    plotlyOutput("eda_ts_raw", height = "360px")
                  ),
                  tags$small(textOutput("cap_eda_ts_raw"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  div(
                    class = "plot-container",
                    plotlyOutput("eda_ts_roll", height = "360px")
                  ),
                  tags$small(textOutput("cap_eda_ts_roll"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  div(
                    class = "plot-container",
                    plotlyOutput("eda_ts_dist", height = "360px")
                  ),
                  tags$small(textOutput("cap_eda_ts_dist"))
                )
              )
            )
          ),

          tabPanel(
            title = "Analiza eksploruese – Marrëdhënie",
            value = "tab_eda_rel",

            div(
              class = "section-box",
              h3("Analiza eksploruese e të dhënave – Marrëdhënie"),
              p("Në këtë seksion analizohen marrëdhëniet ndërmjet variablave kryesore bujqësore, përmes grafikëve dhe matricës së korrelacionit.")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput(
                  "rel_x",
                  "Përzgjidhni variablën X",
                  choices = c(
                    "Prodhimi (ton)"      = "Production_ton",
                    "Sipërfaqja (ha)"     = "Area_ha",
                    "Rendimenti (ton/ha)" = "Yield_ton_per_ha",
                    "Reshjet (mm)"        = "Rainfall_mm"
                  ),
                  selected = "Rainfall_mm"
                ),

                selectInput(
                  "rel_y",
                  "Përzgjidhni variablën Y",
                  choices = c(
                    "Prodhimi (ton)"      = "Production_ton",
                    "Sipërfaqja (ha)"     = "Area_ha",
                    "Rendimenti (ton/ha)" = "Yield_ton_per_ha",
                    "Reshjet (mm)"        = "Rainfall_mm"
                  ),
                  selected = "Production_ton"
                )
              ),

              mainPanel(
                div(
                  class = "section-box",
                  h4("Grafiku i shpërndarjes (Scatter plot)"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("eda_rel_scatter", height = "420px")
                  ),
                  tags$small(textOutput("cap_eda_rel_scatter"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("Matrica e korrelacionit"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("eda_rel_corr", height = "420px")
                  ),
                  tags$small(textOutput("cap_eda_rel_corr"))
                )
              )
            )
          ),

          tabPanel(
            title = "Stacionariteti",
            value = "tab_stationary",

            div(
              class = "section-box",
              h3("Stacionariteti dhe transformimet"),
              p("Në këtë seksion vlerësohet stacionariteti i serive kohore dhe paraqiten transformimet e nevojshme për modelim (p.sh. diferencimi).")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput(
                  "stat_series",
                  "Përzgjidhni serinë",
                  choices = c(
                    "Prodhimi (ton)"      = "Production_ton",
                    "Sipërfaqja (ha)"     = "Area_ha",
                    "Rendimenti (ton/ha)" = "Yield_ton_per_ha",
                    "Reshjet (mm)"        = "Rainfall_mm"
                  ),
                  selected = "Production_ton"
                )
              ),

              mainPanel(
                div(
                  class = "section-box",
                  h4("Diferenca e parë (First difference)"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("stat_diff_plot", height = "360px")
                  ),
                  tags$small(textOutput("cap_stat_diff_plot"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("ACF dhe PACF"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("stat_acf_pacf", height = "420px")
                  ),
                  tags$small(textOutput("cap_stat_acf_pacf"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("Testi ADF"),
                  div(
                    class = "table-wrap",
                    tableOutput("stat_adf_tbl"),
                    uiOutput("stat_adf_note")
                  )
                )
              )
            )
          ),

          tabPanel(
            title = "Modelimi",
            value = "tab_modeling",

            div(
              class = "section-box",
              h3("Modelimi i serive kohore"),
              p("Në këtë seksion krahasohen modelet ETS dhe ARIMA për parashikim, si dhe vlerësohet saktësia e tyre në setin e trajnimit.")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput(
                  "model_series",
                  "Përzgjidhni serinë",
                  choices = c(
                    "Prodhimi (ton)"      = "Production_ton",
                    "Sipërfaqja (ha)"     = "Area_ha",
                    "Rendimenti (ton/ha)" = "Yield_ton_per_ha",
                    "Reshjet (mm)"        = "Rainfall_mm"
                  ),
                  selected = "Production_ton"
                ),

                sliderInput(
                  "model_h",
                  "Horizonti i parashikimit (vite)",
                  min = 1,
                  max = 10,
                  value = 5,
                  step = 1
                )
              ),

              mainPanel(
                div(
                  class = "section-box",
                  h4("Krahasimi i parashikimeve"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("model_plot", height = "480px")
                  ),
                  tags$small(textOutput("cap_model_plot"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("Saktësia e modelit (seti i trajnimit)"),
                  div(
                    class = "table-wrap",
                    tableOutput("model_acc_tbl")
                  )
                )
              )
            )
          ),

          tabPanel(
            title = "Parashikimi",
            value = "tab_forecast",

            sidebarLayout(
              position = "left",

              sidebarPanel(
                h4("Cilësimet e parashikimit"),

                selectInput(
                  "forecast_series",
                  "Seria",
                  choices = c(
                    "Prodhimi (ton)"      = "Production_ton",
                    "Sipërfaqja (ha)"     = "Area_ha",
                    "Rendimenti (ton/ha)" = "Yield_ton_per_ha",
                    "Reshjet (mm)"        = "Rainfall_mm"
                  )
                ),

                selectInput(
                  "method",
                  "Metoda e parashikimit",
                  choices = c(
                    "SES (sheshim eksponencial i thjeshtë)" = "ses",
                    "Holt (trend i zbutur)"                  = "holt",
                    "ARIMA"                                  = "arima"
                  )
                ),

                sliderInput("h", "Horizonti i parashikimit (vite)", 1, 10, 5),

                hr(),
                p("Grafiku paraqet vlerat e vëzhguara dhe parashikimet për vitet pasuese, së bashku me intervalet e pasigurisë.")
              ),

              mainPanel(
                div(
                  class = "section-box",
                  h4("Parashikimi"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("forecast_plot", height = "520px")
                  ),
                  tags$small(textOutput("cap_forecast_plot"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("Saktësia e parashikimit"),
                  div(
                    class = "table-wrap",
                    uiOutput("forecast_metrics")
                  )
                )
              )
            )
          ),

          tabPanel(
            title = "Përfundime",
            value = "tab_wrapup",

            div(
              class = "section-box",
              h3("Përfundime"),
              tags$ul(
                tags$li("Prodhimi bujqësor në Shqipëri shfaq prirje afatgjatë rritëse, shoqëruar me variabilitet vjetor."),
                tags$li("Testet e stacionaritetit sugjerojnë nevojën për transformime (p.sh. diferencim) përpara modelimit ARIMA, kur seria nuk është stacionare."),
                tags$li("Metodat SES dhe Holt rezultojnë të përshtatshme për parashikime afatshkurtra, sidomos kur struktura e serisë është e qëndrueshme."),
                tags$li("ARIMA ofron fleksibilitet më të lartë për modelim dhe parashikim, veçanërisht kur struktura kërkon përfshirje të komponentëve autoregresivë dhe mesatares lëvizëse."),
                tags$li("Aplikacioni Shiny shërben si mjet eksplorues dhe demonstrues; analiza e plotë dokumentohet në raportin përkatës Rmd.")
              )
            ),

            div(
              class = "section-box",
              tags$details(
                open = FALSE,
                tags$summary(tags$strong("Shënim metodologjik: dekompozimi i serive kohore")),
                p("Dekompozimi sezonal u vlerësua si pjesë e rrjedhës së analizës."),
                p(strong("Përfundim: "), "Nuk është i zbatueshëm për këtë dataset."),
                tags$ul(
                  tags$li("Të dhënat janë vjetore (frequency = 1); rrjedhimisht nuk mund të identifikohet komponent sezonal."),
                  tags$li("Analiza fokusohet në trendin afatgjatë, variabilitetin, stacionaritetin dhe parashikimin.")
                )
              )
            )
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  observeEvent(input$go_overview,   { updateTabsetPanel(session, "main_tabs", "tab_overview") })
  observeEvent(input$go_eda_ts,     { updateTabsetPanel(session, "main_tabs", "tab_eda_ts") })
  observeEvent(input$go_eda_rel,    { updateTabsetPanel(session, "main_tabs", "tab_eda_rel") })
  observeEvent(input$go_stationary, { updateTabsetPanel(session, "main_tabs", "tab_stationary") })
  observeEvent(input$go_modeling,   { updateTabsetPanel(session, "main_tabs", "tab_modeling") })
  observeEvent(input$go_forecast,   { updateTabsetPanel(session, "main_tabs", "tab_forecast") })
  observeEvent(input$go_wrapup,     { updateTabsetPanel(session, "main_tabs", "tab_wrapup") })

  df <- reactive({
    read_data_safe(DATA_PATH)
  })

  server_plots(input, output, session, df)
}

shinyApp(ui, server)
