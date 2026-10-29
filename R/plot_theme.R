# ---- Tema e përbashkët e grafikëve plot_ly (V-08, P-04) -----------------------
# Riprodhon atë që ggplotly() nxirrte nga theme_minimal(base_size): madhësitë në px,
# margjinat dhe boshtet me tick-e të llogaritura si te ggplot2. Pamja mbetet e njëjtë.

PX_PER_PT <- 96 / 72.27
PX_PER_MM <- 96 / 25.4

GLASS_GRID  <- "rgba(255,255,255,0.15)"
GLASS_WHITE <- "rgba(255,255,255,1)"

# Madhësitë e theme_minimal(base_size) në px (tekst, titull, tick-e, gjatësia e tick-ut, margjina).
glass_sizes <- function(base_size = 11) {
  list(
    text    = base_size * PX_PER_PT,
    title   = base_size * 1.2 * PX_PER_PT,
    tick    = base_size * 0.8 * PX_PER_PT,
    ticklen = base_size / 4 * PX_PER_PT,
    margin  = base_size / 2 * PX_PER_PT
  )
}

# Tick-et e një boshti si te ggplot2: kufijtë zgjerohen 5%, thyerjet llogariten mbi
# kufijtë e zgjeruar dhe mbahen ato brenda tyre. labels: funksion mbi thyerjet (NA = jashtë).
# date = TRUE: vlerat janë ditë (Date si numër), etiketat si te scale_x_date().
gg_ticks <- function(values, labels = NULL, date = FALSE) {
  lim <- range(as.numeric(values), na.rm = TRUE)
  rng <- scales::expand_range(lim, mul = 0.05, zero_width = 1)

  if (date) {
    br  <- scales::transform_date()$breaks(as.Date(rng))
    lab <- scales::transform_date()$format(br)
    br  <- as.numeric(br)
  } else {
    br  <- scales::transform_identity()$breaks(rng)
  }
  keep <- !is.na(br) & br >= rng[1] & br <= rng[2]
  br[!keep] <- NA

  if (!date) {
    lab <- if (is.null(labels)) scales::transform_identity()$format(br) else labels(br)
  }
  list(range = rng, tickvals = br[keep], ticktext = unname(lab[keep]))
}

glass_axis <- function(ticks, title, sz, gridwidth, title_color = GLASS_WHITE,
                       tick_color = GLASS_WHITE, zerolinecolor = NULL, anchor = "y") {
  ax <- list(
    domain = c(0, 1), automargin = TRUE, type = "linear", autorange = FALSE,
    range = ticks$range, tickmode = "array",
    ticktext = ticks$ticktext, tickvals = ticks$tickvals,
    categoryorder = "array", categoryarray = ticks$ticktext,
    ticks = "", ticklen = sz$ticklen, tickwidth = 0, showticklabels = TRUE,
    tickfont = list(color = tick_color, family = "", size = sz$tick), tickangle = 0,
    showline = FALSE, linewidth = 0, showgrid = TRUE,
    gridcolor = GLASS_GRID, gridwidth = gridwidth, zeroline = FALSE, anchor = anchor,
    title = list(text = title, font = list(color = title_color, family = "", size = sz$text)),
    hoverformat = ".2f"
  )
  if (!is.null(zerolinecolor)) ax$zerolinecolor <- zerolinecolor
  ax
}

# Margjinat që ggplotly llogariste nga teksti: titulli lart, tick-et dhe titujt e boshteve.
gg_margin <- function(sz, xaxis, yaxis, has_title = TRUE) {
  longest <- function(x) if (length(x)) max(nchar(x)) else 0
  title_h <- function(ax) if (nzchar(ax$title$text)) sz$text else 0
  list(
    t = sz$margin + (if (has_title) sz$title else 0) + 16,
    r = sz$margin,
    b = sz$margin + sz$ticklen + (if (length(xaxis$ticktext)) sz$tick else 0) + title_h(xaxis),
    l = sz$margin + sz$ticklen + sz$tick * longest(yaxis$ticktext) / 2 + title_h(yaxis)
  )
}

glass_layout <- function(title, sz, xaxis, yaxis, margin, hovermode = "closest",
                         title_color = GLASS_WHITE) {
  list(
    margin = margin,
    font = list(color = "white", family = "", size = sz$text),
    title = list(text = title, font = list(color = title_color, family = "", size = sz$title),
                 x = 0, xref = "paper"),
    xaxis = xaxis, yaxis = yaxis,
    showlegend = FALSE, hovermode = hovermode, barmode = "relative",
    paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)"
  )
}

# Ngjyra si i kthente ggplotly ngjyrat me alpha të ggplot2 (p.sh. 0.95 -> 0.949).
gg_color <- function(color, alpha = NA) plotly::toRGB(scales::alpha(color, alpha))

# Legjenda e fshehur që ggplotly shtonte në layout (showlegend = FALSE). NA = null në JSON.
gg_legend <- function(color, sz, title = NULL) {
  out <- list(bgcolor = NA, bordercolor = NA, borderwidth = 0,
              font = list(color = color, family = "", size = sz$tick))
  if (!is.null(title)) out$title <- list(text = title, font = list(color = color, family = "", size = sz$text))
  out
}

# Konfigurimi që kishin grafikët e ggplotly (shiriti i veglave i fshehur).
GLASS_CONFIG <- list(
  doubleClick = "reset", modeBarButtonsToAdd = c("hoverclosest", "hovercompare"),
  showSendToCloud = FALSE, displayModeBar = FALSE, responsive = TRUE
)

# Figura plotly e plotë (gjurmët + layout): pa ngjyra default dhe pa heqje NA-sh
# nga plot_ly(), që JSON-i të jetë ai i ggplotly-t të vjetër.
glass_figure <- function(traces, layout) {
  plotly::as_widget(list(data = traces, layout = layout, config = GLASS_CONFIG))
}
