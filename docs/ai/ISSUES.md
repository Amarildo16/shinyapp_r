# Problemet e gjetura (ISSUES)

> [!info] Si përdoret
> Çdo problem ka një ID që përmendet te [TASKS.md](TASKS.md), te `steps/` dhe në ditarin e Obsidian. Kur rregullohet, shëno kutinë **vetëm me provë** (testi ose skenari Qxx) dhe pasqyroje te `02 - Problemet e gjetura.md` në Obsidian.
> Rreshtat i referohen commit-it `976dce0`.

**Kategoritë:** `P` = strukturë, `B` = bug, `D` = kod / asete të vdekura, `U` = konsistencë / UX

## P — Struktura

- [ ] **P-01 — Tre file monolitike.** `app.R` ka UI + server (2 365 rreshta); `helpers.R` përzien librari, globale, I/O, matematikë dhe background; `server_plots.R` është një funksion i vetëm 1 867 rreshta.
  - Zgjidhja: folderi `R/` + module Shiny ([ARCHITECTURE.md](ARCHITECTURE.md)). · Faza: 2–5
- [ ] **P-02 — Zbulimi i kolonave numerike është kopjuar 8 herë.** Kontrolli `mean(!is.na(to_numeric_safe(x))) >= 0.70`.
  - `app.R`: 893, 992, 1221, 1333, 1410, 1548, 1622
  - `server_plots.R`: 41
  - Zgjidhja: një funksion `detect_numeric_cols(d, exclude)`. · Faza: 2
- [ ] **P-03 — Zbulimi i kolonës së kohës + vlerat default janë kopjuar 6 herë.**
  - `app.R`: 882, 982, 1202, 1325, 1533
  - `server_plots.R`: 18
  - Zgjidhja: `resolve_dataset_defaults(d, cfg)` që kthen `time_choices`, `time_col`, `num_cols`, `value_cols`. · Faza: 2
- [ ] **P-04 — Tema e grafikëve është kopjuar 9 herë.** Sfondi transparent, teksti i bardhë dhe `layout()` i njëjtë përsëriten në çdo grafik.
  - Zgjidhja: `plot_theme.R` me `glass_layout()`. · Faza: 5
- [ ] **P-05 — Dy burime të së vërtetës për konfigurimin.** JSON-i (`active_cfg()`) dhe inputet e fshehura (`data_time_col`, `data_value_cols`). Përmbledhja preferon JSON-in, grafikët preferojnë inputet. Kjo shkakton render të dyfishtë kur ndryshon dataset-i.
  - Zgjidhja: `mod_datasets` kthen një `active()` të vetëm. · Faza: 4
- [ ] **P-06 — Dataset-i aktiv ngarkohet dy herë në startup.** `observe()` (`app.R:1151`) dhe `observeEvent(active_dataset_file())` (`app.R:910`) ngarkojnë të dy.
  - Faza: 4
- [ ] **P-07 — ARIMA llogaritet dy herë, me dy cache manuale.** Modelimi (`.model_cache_*`) dhe Parashikimi (`.arima_cache_*`) llogaritin të njëjtin `auto.arima`.
  - Zgjidhja: `model_store` i përbashkët me `bindCache`. · Faza: 5
- [ ] **P-08 — Modalet hapen me tre mënyra.** Mesazhi `toggle_modal`, `shinyjs::runjs` me Bootstrap (`modal_show_bg`) dhe `showModal`.
  - Zgjidhja: një mënyrë e vetme + `glass_modal()` në `ui_components.R`. · Faza: 3–6
- [ ] **P-09 — `BG_STATE` lexohet dy herë** (`app.R:4` dhe `app.R:1657`). · Faza: 6
- [ ] **P-10 — `BG_PLACEHOLDER_SVG` definohet pasi përdoret** (`app.R:1743`). Punon vetëm falë vlerësimit të vonuar. · Faza: 6
- [ ] **P-11 — Inputet `data_dup` dhe `data_freq` janë të fshehura.** Janë gjithmonë `mean` / `auto`, pra kod që nuk zgjidhet kurrë nga përdoruesi.
  - Zgjidhja: konstante në `config.R`, ose opsion në konfigurimin e dataset-it. · Faza: 4
- [ ] **P-12 — Lista e faqeve përsëritet në 5 vende.** Butonat në UI, `TITLE_MAP`, `BG_TABS`, `MAP` te `sidebar.js` dhe `AFFECTS` te `plotly-animate.js`.
  - Zgjidhja: `PAGES` në `config.R`, ku UI dhe JS gjenerohen prej saj. · Faza: 3

## B — Bug-e

- [ ] **B-01 — Tabelat tregojnë gjithmonë 4 decimale.** `fmt_by_series()` thirret për një vlerë të vetme, kështu që hapësira e vlerave është 0 dhe zgjidhet formati me 4 decimale.
  - Vendet: `server_plots.R` 372–380 (statistikat përmbledhëse), 1495–1497 (saktësia e modelimit), 1859–1861 (saktësia e parashikimit)
  - Zgjidhja: formatimi i gjithë kolonës njëherësh, ose një funksion i dedikuar për vlera të vetme. · Faza: 2
- [ ] **B-02 — Slider-at përditësohen vetëm një herë për dataset.** Për shkak të `.slider_once` (`server_plots.R:141`), kur ndërron serinë, maksimumi mbetet ai i serisë së vjetër.
  - Faza: 5
- [ ] **B-03 — Upload dhe Edit ofrojnë seri të ndryshme.** Te upload, "Proceed" ofron çdo kolonë që nuk është koha (`app.R:1381`), ndërsa Edit ofron vetëm kolonat numerike.
  - Faza: 4
- [ ] **B-04 — Te Parashikimi, vija e vëzhguar dhe parashikimi janë të dyja të bardha.** Nuk dallohen. · Faza: 5
- [ ] **B-05 — Hover-i i Parashikimit lidhet me vijat sipas gjatësisë.** `nx == nrow(...)` (`server_plots.R:1760`) prishet kur h = n.
  - Zgjidhja: `plot_ly` direkt me `text` për çdo trace. · Faza: 5
- [ ] **B-06 — `showNotification` brenda render-ave.** Njoftimet përsëriten në çdo rifreskim.
  - Vendet: `server_plots.R` 514, 534, 541, 838, 844, 854, 951, 1030, 1040, 1373, 1512, 1522, 1616, 1620, 1630
  - Zgjidhja: `validate(need(...))` ose mesazh në kartë. · Faza: 5
- [ ] **B-07 — Teksti i vjetër "variablave kryesore bujqësore"** te EDA – Marrëdhënie (`app.R:397`). · Faza: 5
- [ ] **B-08 — Emri i fotos futet në JS pa escape.** `sprintf("...'%s'...")` (`app.R:2053`). Një emër me `'` e prish klikimin.
  - Zgjidhja: `jsonlite::toJSON()` si te dataset-et. · Faza: 6
- [ ] **B-09 — Kolona e kohës numerike që nuk është vit refuzohet.** Vendimi: vetëm mesazh më i qartë (V-11). Klasifikohet si `index`, kështu që Stacionariteti, Modelimi dhe Parashikimi nuk punojnë.
  - Vendim: ose mbështetje me frekuencë 1, ose mesazh më i qartë. · Faza: 5
- [ ] **B-10 — Preloader-i errëson gjithë ekranin në çdo `shiny:busy`** (`custom.js:14`), edhe për një lëvizje slider-i.
  - Zgjidhja: shfaqet vetëm pas ~400 ms, ose vetëm për llogaritje të gjata. · Faza: 7
- [ ] **B-11 — Warning-e në console të R-së gjatë përdorimit** (gjetur në Fazën 0, 2026-10-27, Q01).
  - `ggplot2::geom_point(aes(text = hover))` → "Ignoring unknown aesthetics: text" (`server_plots.R:752`, EDA – Marrëdhënie). Zhduket me `plot_ly` (V-08).
  - `tseries::adf.test()` → "p-value smaller than printed p-value" kur p < 0,01 (`server_plots.R:1163–1165`). Është sjellje normale e testit; vlera e shfaqur (0,0100) është ajo e `tseries`. Zgjidhja duhet të mos ndryshojë vlerën (R21), p.sh. kapja e këtij warning-u specifik.
  - Faza: 5
- [ ] **B-12 — Errore në console të browser-it te Modelimi** (gjetur në Fazën 0, 2026-10-27).
  - "Shiny server has sent a progress message for model_plot, but the output is in an unexpected state" (+ "recalculating"/"recalculated" … "idle"). Vjen nga `shiny::withProgress()` brenda reaktivit `.model_fits()` (`server_plots.R:1316`); i njëjti model te `arima_fit()` (`server_plots.R:1572`). Grafiku dhe tabela shfaqen saktë.
  - Zgjidhja: llogaritja e modeleve jashtë render-it (`model_store`, P-07), progres pa `withProgress` brenda `reactive()`. · Faza: 5

## D — Kod dhe asete të vdekura

- [ ] **D-01 — `www/css/icons.css` (750 KB) ngarkohet por nuk përdoret.** · Faza: 1
- [ ] **D-02 — ~16 MB fonte të papërdorura.** `boxicons.*`, `la-*`, `materialdesignicons-*`, `hkgrotesk-*`, `summernote.*`. Mbahen vetëm `remixicon.*`. · Faza: 1
- [ ] **D-03 — Funksione dhe output-e të papërdorura:**
  - `pick()` (`helpers.R:1065`)
  - `fmt_pct` (`server_plots.R:388`)
  - `time_range_txt` (`server_plots.R:257`)
  - `output$bg_media_selected_txt` (`app.R:2094`)
  - `has_vars`, `has_rugarch` (`helpers.R:367`)
  - `tab_wrapup` (`app.R:722`)
  - dega `fs` te `ajax_modal_open`
  - variabla `title` te `csv_file_modal`
  - parametri `context` te `validate_ts_ready`
  - Faza: 1–2
- [ ] **D-04 — README dhe Metodologjia premtojnë gjëra që nuk ekzistojnë.** Vendimi: hiqen (V-10). README instalon `vars` dhe `rugarch`; Metodologjia përmend ARMA, VAR/IRF dhe GARCH, që nuk janë implementuar. · Faza: 1 dhe 8
- [ ] **D-05 — Dega numerike e `parse_time_safe` ka kod të tepërt.** Kontrolli i hapit kthen `xn` në të dyja rastet. · Faza: 2

## U — Konsistencë dhe UX

- [ ] **U-01 — Gjuha e përzier.** Vendimi: UI dygjuhëshe sq/en me `tr()` (V-09, R26). Etiketa në anglisht: Settings, Save, Proceed, Cancel, Library, Upload, Blur strength, Edit. · Faza: 8
- [ ] **U-02 — Gabime drejtshkrimi.** "ndërtu", "u lexu", "Backround" (në koment). · Faza: 8
- [x] **U-03 — `.gitignore` ka `.Rproj`.** Duhet `*.Rproj`. · Faza: 0
  - Mbyllur 2026-10-27: `.Rproj` → `*.Rproj`; u shtuan `storage/` dhe `renv/library|staging|local/`. Prova: `git diff .gitignore` (Claude).
- [ ] **U-04 — Ngarkimet e përdoruesit shkruhen brenda kodit** (`data/`, `www/images/`).
  - Zgjidhja: folderi `storage/`. · Faza: 3
- [ ] **U-05 — CSS ka 135 `!important` dhe selektorë të përsëritur.** P.sh. `.bg-tab-card`, `.media-card` dhe `.bg-tabs-grid` janë definuar 2–3 herë. · Faza: 7
- [x] **U-06 — Line endings ndryshojnë vetvetiu.** Vendimi: discard i ndryshimit aktual (V-12) + `.gitattributes`. Windows i kthen në CRLF, kështu që `datasets_state.json` del si i ndryshuar edhe pa ndryshim real.
  - Zgjidhja: `.gitattributes`. · Faza: 0
  - Mbyllur 2026-10-27: në kompjuterin e përdoruesit `core.autocrlf=input`, prandaj git nuk shfaqte më ndryshim (s'kishte çfarë të hidhej poshtë). U shtua `.gitattributes` (`* text=auto eol=lf`, binare për foto/fonte/`.rds`/`.xlsx`/`.ico`…). Prova: `git status` pa ndryshime te `data/`, `git ls-files --eol` (index LF), `git check-attr` (Claude).
- [ ] **U-07 — "Ke ndryshime pa Save" mbetet pasi kthehet zgjedhja fillestare** (gjetur në Fazën 0, 2026-10-27). Te Background, Foto → Pa background (pa Save) e lë mesazhin edhe pse gjendja është sërish ajo e ruajtur. E vogël; vetëm UX. · Faza: 6
