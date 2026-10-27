# Pjesët e përbashkëta të UI-së. HTML-i dhe klasat CSS janë të njëjtat si te app.R i
# vjetër, që pamja të mos ndryshojë; menyja dhe titujt vijnë nga PAGES (P-12).

app_head <- function() {
  tags$head(
    tags$meta(name="viewport", content="width=device-width, initial-scale=1"),
    tags$link(rel="stylesheet", href="vendor/filepond/filepond.min.css"),
    tags$link(rel="stylesheet", type="text/css", href="css/custom-style.css"),
    tags$link(rel="icon", type="image/png", href="favicon/favicon.png"),
    tags$script(src="vendor/filepond/filepond.min.js"),
    tags$script(src="vendor/filepond/filepond-plugin-file-validate-type.min.js"),
    tags$script(src="vendor/filepond/filepond-plugin-file-validate-size.min.js"),
    tags$script(src="js/bg.js"),
    tags$script(src="js/sidebar.js"),
    tags$script(src="js/plotly-animate.js"),
    tags$link(rel = "stylesheet", href = "vendor/remixicon/remixicon.css"),
    tags$script(src="js/custom.js")
  )
}

preloader <- function() {
  tags$div(
    id = "preloader",
    tags$div(
      id = "status",
      tags$div(
        class = "loading",
        tags$span(), tags$span(), tags$span(), tags$span(), tags$span()
      )
    )
  )
}

bg_layers <- function() {
  tagList(
    tags$div(
      id = "bg-wrapper",
      tags$div(
        class = "bg-layer current",
        style = "background-color:#0b1c24; background-image:none;"
      ),
      tags$div(class = "bg-layer next")
    ),
    tags$div(id = "bg-overlay")
  )
}

# data-nav-tab lidh çdo buton me tab-in e vet; sidebar.js e lexon prej këtu (P-12).
nav_button <- function(id) {
  actionButton(page_btn(id), tr(paste0("page.", id, ".menu")),
               class = "btn btn-light nav-btn", `data-nav-tab` = page_tab(id))
}

sidebar_footer <- function() {
  social <- function(href, label, icon) {
    tags$a(
      href   = href,
      target = "_blank",
      rel    = "noopener noreferrer",
      class  = "social-link",
      `aria-label` = label,
      tags$i(class = icon)
    )
  }

  div(
    class = "sidebar-footer",
    tags$small(class = "footer-by", "By Amarildo Alla"),
    tags$div(
      class = "footer-social",
      social("https://instagram.com/amarildo__alla", "Instagram", "ri-instagram-line"),
      social("https://al.linkedin.com/in/amarildo-alla-49a793316", "LinkedIn", "ri-linkedin-box-line"),
      social("https://github.com/Amarildo16", "GitHub", "ri-github-line")
    )
  )
}

app_sidebar <- function() {
  div(
    id = "app_sidebar",
    class = "app-sidebar",

    div(
      class = "sidebar-main",
      div(
        class = "menu-title-row",
        div(class = "menu-title", "Time Series Analysis"),
        actionButton(
          page_btn("settings"),
          label = NULL,
          icon = tags$i(class = "ri-settings-5-line"),
          class = "settings-icon-btn",
          `aria-label` = tr("sidebar.settings_aria"),
          `data-nav-tab` = page_tab("settings")
        )
      ),
      lapply(page_ids(nav_only = TRUE), nav_button)
    ),

    div(class = "glass-divider"),
    sidebar_footer()
  )
}

app_topbar <- function() {
  div(
    class = "app-topbar",
    tags$button(
      type = "button",
      class = "hamburger-btn",
      id = "toggle_sidebar",
      tags$span(), tags$span(), tags$span()
    ),
    div(class = "app-title", textOutput("topbar_title"))
  )
}

section_box <- function(...) div(class = "section-box", ...)

glass_modal <- function(id, title_output, body_output, footer, dialog_class = "modal-dialog") {
  tags$div(
    class = "modal fade",
    id = id,
    tabindex = "-1",
    `aria-hidden` = "true",
    tags$div(
      class = dialog_class,
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          uiOutput(title_output),
          tags$button(
            type = "button",
            class = "close",
            `data-dismiss` = "modal",
            `aria-label` = tr("modal.close_aria"),
            tags$span(`aria-hidden` = "true", HTML("&times;"))
          )
        ),
        tags$div(class = "modal-body", uiOutput(body_output)),
        tags$div(class = "modal-footer", footer)
      )
    )
  )
}

# Modalet glass hapen e mbyllen vetëm kështu (P-08); id është ID-ja brenda modulit.
toggle_glass_modal <- function(session, id, action = c("show", "hide")) {
  session$sendCustomMessage("toggle_modal", list(id = session$ns(id), action = match.arg(action)))
}

# Modali i background-it (Faza 6 e kalon te mod_background).
app_modals <- function() {
  tagList(
    glass_modal(
      "bg_modal_fs", "bg_modal_fs_title", "bg_modal_fs_body",
      tagList(
        actionButton("bg_btn_close", tr("common.close"), class = "btn btn-light"),
        actionButton("bg_btn_use", tr("bg.use_photo"), class = "btn btn-success")
      ),
      dialog_class = "modal-dialog modal-lg"
    )
  )
}

# Faqja e plotë: renditja e elementeve është ajo e app.R të vjetër.
app_page <- function(main_tabs, modals) {
  fluidPage(
    shinyjs::useShinyjs(),
    app_head(),
    preloader(),
    bg_layers(),
    div(
      class = "app-shell",
      tags$div(
        id = "sidebar_backdrop",
        class = "sidebar-backdrop",
        `aria-hidden` = "true"
      ),
      app_sidebar(),
      div(
        class = "app-content",
        div(
          class = "app-content-inner",
          app_topbar(),
          main_tabs
        )
      )
    ),
    modals
  )
}
