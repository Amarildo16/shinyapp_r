# mod_overview: tabelat e Përmbledhjes (Q09) dhe moduli me shiny::testServer.

agri_active <- function() {
  f <- "albania_agriculture_timeseries_1998_2024.csv"
  d <- read_data_safe(file.path(APP_ROOT, "data", "samples", f), f)
  list(file = f, data = d, time_col = "Year", value_cols = c("Production_ton", "Area_ha"))
}

test_that("overview_info_table: periudha, numrat dhe burimi", {
  s <- prepare_series(agri_active())
  out <- overview_info_table(s$data, length(s$value_cols), "agri.csv")

  expect_equal(names(out), c("Element", "Vlera"))
  expect_equal(out[[1]], c("Viti fillestare", "Viti përfundimtare", "Numri i vrojtimeve",
                           "Numri i serive numerike", "Burimi i të dhënave"))
  expect_equal(out[[2]], c("1998", "2024", "27", "2", "agri.csv"))
  expect_equal(overview_info_table(s$data, 2, NULL)[[2]][5], "Përdoruesi (dataset i ngarkuar)")

  d <- prepare_fixture("monthly_gap.csv", "Date", "Value")
  out <- overview_info_table(d, 1, "m.csv")
  expect_equal(out[[1]][1:2], c("Data fillestare", "Data përfundimtare"))
  expect_equal(out[[2]][1], "2021-01-01")
})

test_that("overview_variables_table dhe overview_summary_table", {
  meta <- list(a = list(label = "A", unit = "kg"), b = list(label = "B", unit = ""))
  v <- overview_variables_table(c("a", "b"), meta)
  expect_equal(names(v), c("Variabla", "Përshkrimi"))
  expect_equal(v$Variabla, c("A (kg)", "B"))
  expect_equal(v$Përshkrimi, rep("Seri numerike e ngarkuar nga përdoruesi.", 2))

  d <- data.frame(Time = 2000:2003, a = c(1, 2, 3, NA), b = c(0.1, 0.2, 0.3, 0.4))
  st <- overview_summary_table(d, c("a", "b"), meta)
  expect_equal(names(st), c("Variabla", "Mesatarja", "Devijimi standard", "Minimumi",
                            "Maksimumi", "N (jo-NA)", "% që mungon"))
  expect_equal(st$Mesatarja, c("2,00", "0,2500"))
  expect_equal(st$Minimumi, c("1,00", "0,1000"))
  expect_equal(st$`N (jo-NA)`, summary_stats(d, c("a", "b"))$n)
  # B-24: presja dhjetore e gjuhës, vlera e njëjtë e summary_stats().
  expect_equal(st$`% që mungon`, c("25,00", "0,00"))
  on.exit(set_lang("sq"), add = TRUE)
  set_lang("en")
  expect_equal(overview_summary_table(d, c("a", "b"), meta)$`Missing %`, c("25.00", "0.00"))
})

test_that("overview_selected_data: kolona e kohës me emrin origjinal, e renditur", {
  a <- agri_active()
  a$data <- a$data[rev(seq_len(nrow(a$data))), ]
  out <- overview_selected_data(a)
  expect_equal(names(out), c("Year", "Production_ton", "Area_ha"))
  expect_false(is.unsorted(out$Year))
})

test_that("përkthimi anglisht i tabelave", {
  on.exit(set_lang("sq"), add = TRUE)
  set_lang("en")
  s <- prepare_series(agri_active())
  out <- overview_info_table(s$data, 2, "agri.csv")
  expect_equal(names(out), c("Item", "Value"))
  expect_equal(out[[1]][1:2], c("First Year", "Last Year"))
})

test_that("mod_overview_server vizaton të katër tabelat dhe validate-t", {
  act <- reactiveVal(agri_active())
  testServer(mod_overview_server, args = list(
    active = act, series = reactive(prepare_series(act())), current_tab = reactive("tab_overview")
  ), {
    session$flushReact()
    expect_match(output$data_info_tbl, "Viti fillestare")
    expect_match(output$variables_tbl, "Production ton")
    expect_match(output$summary_tbl, "Devijimi standard")
    expect_false(is.null(output$ts_selected_tbl))

    a <- agri_active(); a$value_cols <- "Mungon"
    act(a)
    session$flushReact()
    expect_error(output$ts_selected_tbl, "S’ke zgjedhur asnjë seri numerike te Cilësimet.")
  })
})
