# Time Series Analysis (Shiny)

App Shiny për analizën e serive kohore: përmbledhje e dataset-it, analizë eksploruese, stacionaritet (ADF, ACF/PACF), modelim (ETS dhe ARIMA) dhe parashikim (SES, Holt, ARIMA). Ndërfaqja është në shqip (e paracaktuar) dhe në anglisht; gjuha zgjidhet te **Cilësimet**.

App-i punon plotësisht lokalisht: të gjitha asetet (CSS, JS, fonte, ikona, FilePond) janë në projekt dhe nuk kërkohet internet.

## Kërkesat

- R 4.6 ose më i ri (projekti është provuar me R 4.6.1)
- RStudio (i rekomanduar)
- Paketat: `shiny`, `shinyjs`, `plotly`, `ggplot2`, `dplyr`, `tidyr`, `readr`, `forecast`, `scales`, `tseries`, `zoo`, `DT`, `jsonlite`, `cachem`, `rlang`

## Instalimi

Rruga e rekomanduar është **renv**, që instalon saktësisht versionet e provuara (`renv.lock`):

```r
install.packages("renv")   # vetëm herën e parë
renv::restore()
```

Si alternativë, `install_packages.R` instalon vetëm paketat që mungojnë:

```r
source("install_packages.R")
```

## Nisja

Hap dosjen e projektit në RStudio dhe ekzekuto:

```r
shiny::runApp()
```

Ose hap `app.R` dhe kliko **Run App**.

## Përdorimi

1. Hap menynë anësore (butoni ☰) dhe shko te **Cilësimet**.
2. Te **Dataset**: ngarko një CSV, zgjidh kolonën e kohës dhe seritë numerike, pastaj **Ruaj**. Dataset-i aktiv përdoret në të gjitha faqet; mund ta ndryshosh ose ta fshish kur të duash.
3. Faqet e analizës: Përmbledhja, Analiza eksploruese (seri kohore dhe marrëdhënie), Stacionariteti, Modelimi, Parashikimi.
4. Te **Sfondi** zgjidh një foto për të gjitha faqet ose për secilën veç e veç, një ngjyrë, ose pa sfond. Ndryshimet ruhen vetëm me **Ruaj**.

Formatet e kohës që njihen: `YYYY`, `YYYY-MM`, `YYYY-MM-DD`, `YYYYQ#`, `dd/mm/YYYY`, `dd-mm-YYYY`, `YYYY/mm/dd`. Një kolonë me numra të thjeshtë (1, 2, 3…) pranohet për analizën eksploruese; analizat statistikore kërkojnë kohë kalendarike.

## Ku ruhen të dhënat

Të dhënat e përdoruesit nuk ruhen brenda kodit, por te `storage/` (krijohet vetë në nisjen e parë dhe nuk shkon në git):

| Dosja | Përmbajtja |
|---|---|
| `storage/datasets/` | CSV-të e ngarkuara |
| `storage/images/` | fotot e ngarkuara për background-in |
| `storage/state/` | dataset-i aktiv, konfigurimi i serive, background-i, gjuha, kopjet rezervë |

Dataset-et shembull janë te `data/samples/`; 12 fotot default janë te `www/images/` dhe nuk fshihen nga app-i.

## Përditësimi nga versioni i mëparshëm

Nuk duhet bërë asgjë me dorë. Në nisjen e parë të versionit të ri:

- CSV-të dhe state-i i vjetër te `data/` **kopjohen** te `storage/` (me kopje rezervë te `storage/state/backup-…`);
- fotot e ngarkuara më parë te `www/images/` **kopjohen** te `storage/images/` dhe background-i i ruajtur drejtohet te kopjet.

Origjinalet nuk fshihen dhe nuk mbishkruhen: mbeten aty ku ishin si kopje rezervë. Dataset-i aktiv, seritë e zgjedhura dhe background-i duken njësoj si më parë.

## Struktura e projektit

```
app.R                 UI dhe server: faqet dhe thirrjet e moduleve
R/                    kodi (Shiny e ngarkon vetë)
  config.R            shtigjet, kufijtë dhe lista e faqeve (PAGES)
  storage.R           storage/ dhe migrimi i të dhënave të vjetra
  i18n.R              përkthimet: tr("çelësi")
  mod_*.R             një modul për çdo faqe ose seksion (datasets, background, overview, eda_ts,
                      eda_rel, stationarity, modeling, forecast) dhe navigimi (mod_nav)
  stats_eda.R, ts_models.R, ts_time.R, ts_validate.R   llogaritjet e pastra
  model_store.R       cache i modeleve ETS/ARIMA (një model për seri)
  plot_theme.R        tema e përbashkët e grafikëve plot_ly
  media_library.R     fotot e background-it dhe migrimi i tyre
i18n/                 sq.json dhe en.json (të njëjtët çelësa)
www/css/              tokens, layout, components, modals, datatables, background
www/js/               sidebar, bg, plotly-animate, preloader, filepond-bridge, modals, color-picker
data/samples/         dataset-et shembull (vetëm për lexim)
tests/                testthat (tests/testthat/) dhe krahasimi me referencën (tests/reference/)
docs/ai/              specifikimi, vendimet, problemet dhe gjendja e projektit
```

## Si shtohet një faqe e re

1. Shto faqen te `PAGES` në `R/config.R`, p.sh. `list(id = "faqja_ime", nav = TRUE)`. Menyja, titulli dhe fotoja e background-it për faqen dalin vetë prej saj.
2. Shto tekstet `page.faqja_ime.menu` dhe `page.faqja_ime.title` te `i18n/sq.json` dhe `i18n/en.json`.
3. Krijo `R/mod_faqja_ime.R` me `mod_faqja_ime_ui(id)` dhe `mod_faqja_ime_server(id, series)`; çdo tekst i dukshëm me `tr()`. Llogaritjet mbaji në funksione të pastra, që të testohen pa Shiny.
4. Te `app.R`: një `tabPanel(title = tr("page.faqja_ime.menu"), value = page_tab("faqja_ime"), mod_faqja_ime_ui("faqja_ime"))` dhe `mod_faqja_ime_server("faqja_ime", series)` te serveri.
5. Grafikët që duhet të animohen marrin klasën `anim-plot` (shih `anim_plotly_output()`).
6. Shto testet te `tests/testthat/test-mod_faqja_ime.R`.

## Testet

```r
testthat::test_dir("tests/testthat")          # testet e njësive dhe të moduleve
source("tests/reference/compare_reference.R")  # rezultatet statistike kundrejt referencës
```

## Autori

Amarildo Alla — [GitHub](https://github.com/Amarildo16)
