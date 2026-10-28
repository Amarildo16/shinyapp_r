# Faza 05 — Faqet e analizës si module

Statusi: **në punë** (bazat `7ba9afb`; `mod_overview` i përfunduar 2026-10-28, pa commit). Vendimet e fazës: V-17, V-18, T-18, T-19, T-20. Kërkesat: R09–R16, R21. Problemet: P-04, P-07, B-02, B-04, B-05, B-06, B-07, B-09. Vendimet: V-08 (`plot_ly` direkt), V-11 (vetëm mesazh), V-09 (tekstet me `tr()`).

## Qëllimi

`server_plots.R` (tani `legacy_server_plots.R`) zhduket. Çdo faqe është modul i vetëm, me logjikë llogaritëse të pastër dhe të testuar, dhe me modele të ndara.

## Veprimet

1. `R/ts_models.R`: `fit_ets`, `fit_arima`, `run_adf`, `acf_pacf_data`, `forecast_table`, me **të njëjtat thirrje dhe parametra** si sot. Teste kundrejt referencës (`test-ts_models.R`).
2. `R/model_store.R`: cache i përbashkët me `cachem` (P-07). Ndryshimi i horizontit nuk e rillogarit modelin.
3. `R/plot_theme.R` (shtohet me `mod_eda_ts`, T-18): tema e përbashkët (P-04) dhe `plot_ly` direkt (V-08). Pamja (ngjyrat, trashësia e vijave, transparenca, margjinat, grid-i) riprodhon atë aktuale; krahasohet me screenshot-et "para".
4. Modulet, **me këtë radhë**. Pas secilit hiqet pjesa përkatëse nga `legacy_server_plots.R` dhe kalon smoke test-i i asaj faqeje.
   1. `mod_overview` ✅ (2026-10-28, T-20)
   2. `mod_eda_ts`: kufijtë e slider-it rillogariten për çdo seri (B-02)
   3. `mod_eda_rel`: rregullo tekstin "bujqësore" (B-07)
   4. `mod_stationarity`
   5. `mod_modeling`: slider-i i horizontit (B-02)
   6. `mod_forecast`: ngjyra të dallueshme (B-04), hover për çdo trace (B-05), slider-i (B-02)
5. Në të gjitha modulet: asnjë `showNotification` në render/reactive (B-06). Gjendjet e pavlefshme shfaqen me `validate(need(...))` dhe me të njëjtat mesazhe si sot.
6. V-11 (B-09): kolona e kohës numerike jo-vit mbetet e refuzuar nga analizat statistike, por mesazhi shpjegon pse dhe sugjeron formatet e pranuara (`YYYY`, `YYYY-MM`, `YYYY-MM-DD`, `YYYYQ#`).
6a. Të gjitha tekstet (tituj grafikësh, boshte, kokat e tabelave, mesazhet, interpretimi i ADF) kalojnë nga `tr()`. Përkthimi anglisht i interpretimit ADF duhet të jetë statistikisht i saktë (R26).
7. `plotly-animate.js`: grafikët e animueshëm marrin klasën `anim-plot`, që animacioni të mbijetojë ID-të e reja të moduleve (`eda_ts-raw` etj.).
8. Fshi `legacy_server_plots.R`.

## Mos bëj

- Mos ndrysho kufijtë minimalë (3 / 6 / 20 / 20 / 30), nivelin e intervalit, opsionet e `auto.arima` (`stepwise`, `approximation`, `seasonal`), `bins = 18` të histogramit, apo mënyrën e llogaritjes së lag-ut te ACF.
- Mos ndrysho tekstin e interpretimit ADF, përveç gabimeve drejtshkrimore të regjistruara.

## Kriteret e përfundimit

- `server_plots.R` / `legacy_server_plots.R` nuk ekzistojnë.
- Q09–Q19 kalojnë; Q30 kalon për të dy dataset-et; Q27 nuk tregon regresione të pavendosura.
- Animacioni i vizatimit punon në çdo grafik që e kishte.

## Dorëzimi

STATUS.md, TASKS.md, ISSUES.md, Obsidian (me screenshot-e "pas" për faqet e analizës). Commit-e për çdo modul, p.sh. `refactor(faza-5): mod_forecast (B-04, B-05)`.
