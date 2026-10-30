# Pjesët e përbashkëta të UI-së. HTML-i dhe klasat CSS janë të njëjtat si te app.R i
# vjetër, që pamja të mos ndryshojë; menyja dhe titujt vijnë nga PAGES (P-12).

# CSS-ja e app-it, me radhën e kaskadës (Faza 7: nga custom-style.css).
APP_CSS <- c("tokens", "layout", "components", "modals", "datatables", "background")
# JS-ja e ndarë nga custom.js (Faza 7), në vendin e tij të mëparshëm.
APP_JS  <- c("preloader", "filepond-bridge", "modals", "color-picker")

# Tekstet që përdor JS-ja (FilePond), sipas gjuhës (R26, V-23 b).
js_i18n <- function() {
  keys <- grep("^pond\\.", names(translations()[[DEFAULT_LANG]]), value = TRUE)   # të gjitha tekstet "pond.*"
  tags$script(HTML(paste0("window.APP_I18N = ",
                          jsonlite::toJSON(setNames(lapply(keys, tr), keys), auto_unbox = TRUE), ";")))
}

# Tekstet e DataTables sipas gjuhës (U-08); anglishtja është e njëjtë me atë të DT-së.
dt_language <- function() {
  t <- function(k) tr(paste0("dt.", k))
  list(
    lengthMenu = t("lengthMenu"), search = t("search"), info = t("info"), infoEmpty = t("infoEmpty"),
    infoFiltered = t("infoFiltered"), zeroRecords = t("zeroRecords"), emptyTable = t("emptyTable"),
    processing = t("processing"), loadingRecords = t("loadingRecords"),
    paginate = list(first = t("first"), last = t("last"), `next` = t("next"), previous = t("previous"))
  )
}

app_head <- function() {
  tags$head(
    tags$meta(name="viewport", content="width=device-width, initial-scale=1"),
    tags$link(rel="stylesheet", href="vendor/filepond/filepond.min.css"),
    tags$link(rel="stylesheet", href="vendor/filepond/filepond-plugin-image-preview.min.css"),
    lapply(APP_CSS, function(f) tags$link(rel = "stylesheet", type = "text/css", href = paste0("css/", f, ".css"))),
    tags$link(rel="icon", type="image/png", href="favicon/favicon.png"),
    tags$script(src="vendor/filepond/filepond.min.js"),
    tags$script(src="vendor/filepond/filepond-plugin-file-validate-type.min.js"),
    tags$script(src="vendor/filepond/filepond-plugin-file-validate-size.min.js"),
    tags$script(src="vendor/filepond/filepond-plugin-image-preview.min.js"),
    tags$script(src="js/bg.js"),
    tags$script(src="js/sidebar.js"),
    tags$script(src="js/plotly-animate.js"),
    tags$link(rel = "stylesheet", href = "vendor/remixicon/remixicon.css"),
    js_i18n(),
    lapply(APP_JS, function(f) tags$script(src = paste0("js/", f, ".js")))
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
      social("https://al.linkedin.com/in/amarildo-alla", "LinkedIn", "ri-linkedin-box-line"),
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

# Madhësitë e modaleve (V-26): sm 400 px, md 560, lg 800, xl 1140, fs ekrani i plotë.
# Pamja vjen nga klasa glass-modal-<size> te modals.css, jo nga ID-ja.
GLASS_MODAL_SIZES <- c("sm", "md", "lg", "xl", "fs")

glass_modal <- function(id, title_output, body_output, footer, size = GLASS_MODAL_SIZES) {
  size <- match.arg(size)
  tags$div(
    class = paste0("modal fade glass-modal glass-modal-", size),
    id = id,
    tabindex = "-1",
    `aria-hidden` = "true",
    tags$div(
      class = "modal-dialog",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          uiOutput(title_output, class = "glass-modal-title"),
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

# Pamja e vogël e CSV-së pas ngarkimit (V-33, V-34): g vjen nga csv_glance(), remove_id është
# X-i që e heq skedarin.
csv_glance_ui <- function(g, remove_id) {
  count <- function(n, one, many) tr(if (n == 1) one else many, n = fmt_fixed(n, 0))
  size <- if (g$size < 1024^2) paste(fmt_fixed(g$size / 1024, 1), "KB") else paste(fmt_fixed(g$size / 1024^2, 1), "MB")
  cell <- function(x) tags$td(if (!is.na(x)) x)

  tags$div(
    class = "csv-glance",
    tags$div(
      class = "csv-glance-head",
      tags$div(
        class = "csv-glance-meta",
        tags$div(class = "csv-glance-title", g$title),
        tags$div(class = "csv-glance-dims",
                 paste0(count(g$rows, "ds.glance_row", "ds.glance_rows"), " × ",
                        count(g$cols, "ds.glance_col", "ds.glance_cols"), " · ", size))
      ),
      actionButton(remove_id, label = NULL, icon = tags$i(class = "ri-close-line"),
                   class = "csv-glance-remove", `aria-label` = tr("pond.btn_remove"))
    ),
    tags$div(
      class = "csv-glance-scroll",
      tags$table(
        class = "csv-glance-table",
        tags$thead(tags$tr(tags$th(), lapply(names(g$head), tags$th))),
        tags$tbody(lapply(seq_len(nrow(g$head)), function(i) {
          tags$tr(tags$td(class = "csv-glance-n", i), lapply(unname(g$head), function(col) cell(col[i])))
        }))
      )
    )
  )
}

# Modalet glass hapen e mbyllen vetëm kështu (P-08); id është ID-ja brenda modulit.
toggle_glass_modal <- function(session, id, action = c("show", "hide")) {
  session$sendCustomMessage("toggle_modal", list(id = session$ns(id), action = match.arg(action)))
}

# Placeholder-i i kartave të background-it pa foto (P-10: definohet para se të përdoret).
BG_PLACEHOLDER_SVG <- '
    <svg viewBox="0 0 120 90" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Gallery placeholder">
      <defs>
        <filter id="wobble">
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="1" seed="2" result="noise"/>
          <feDisplacementMap in="SourceGraphic" in2="noise" scale="1.4" xChannelSelector="R" yChannelSelector="G"/>
        </filter>
      </defs>

      <g filter="url(#wobble)" fill="none" stroke="rgba(255,255,255,0.75)" stroke-width="3"
        stroke-linecap="round" stroke-linejoin="round">
        <rect x="10" y="10" width="100" height="70" rx="10"/>
        <circle cx="38" cy="30" r="6"/>
        <path d="M22 66 L44 44 L58 58 L80 36 L98 54"/>
        <path d="M22 66 H98"/>
      </g>
    </svg>
    '

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
