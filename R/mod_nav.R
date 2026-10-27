# Navigimi mes faqeve dhe titulli i topbar-it, nga PAGES (P-12).
# Përdor ID-të globale main_tabs dhe go_<id>: i lexojnë sidebar.js, bg.js dhe
# state-i i background-it, prandaj këtu nuk përdoret moduleServer() (T-10).

page_title <- function(tab) {
  id <- sub("^tab_", "", tab %||% "")
  if (!id %in% page_ids()) id <- DEFAULT_PAGE
  tr(paste0("page.", id, ".title"))
}

mod_nav_server <- function(input, output, session) {
  for (id in page_ids()) {
    local({
      page <- id
      observeEvent(input[[page_btn(page)]], {
        updateTabsetPanel(session, "main_tabs", page_tab(page))
      })
    })
  }

  output$topbar_title <- renderText(page_title(input$main_tabs))
}
