# Faza 04 — Moduli i dataset-eve

Statusi: **i pafilluar**. Kërkesat: R05, R06, R07, R22. Problemet: P-05, P-06, P-08 (pjesë), B-03. Vendimet: V-04.

## Qëllimi

Një burim i vetëm i së vërtetës për dataset-in aktiv. Asnjë input i fshehur.

## Veprimet

1. `mod_datasets_ui(id)`: seksioni "Dataset" i Settings (kartat + "Ngarko CSV") dhe modalet përkatëse me `glass_modal()`.
2. `mod_datasets_server(id)` kthen `active()` sipas kontratës te ARCHITECTURE.md ("Kontratat mes pjesëve").
3. Upload dhe Edit përdorin **të njëjtin** funksion për modalin e konfigurimit dhe të njëjtën logjikë ruajtjeje. Seritë e ofruara janë kolonat numerike (`detect_numeric_cols`) në të dyja rastet (B-03).
4. Hiq inputet e fshehura `data_source`, `data_time_col`, `data_value_cols`, `data_dup`, `data_freq` dhe `active_cfg()` (P-05).
5. Një rrugë e vetme ngarkimi në startup (P-06).
6. Një mënyrë e vetme për hapjen/mbylljen e modaleve (P-08 për dataset-et).
7. `series <- reactive(prepare_series(active()))` në `app.R`; `prepare_series()` është funksion i pastër me test.
8. Përshtat përkohësisht `legacy_server_plots.R` që të marrë `series` në vend të `df` dhe inputeve.
9. Të gjitha ruajtjet përdorin `resolve_saved_dataset_path` dhe `is_path_inside_dir` (siguria e Phase 1 ruhet).

10. Çdo tekst i dukshëm i modulit kalon nga `tr()`, me çelësa në `sq.json` dhe `en.json` (R26).
## Mos bëj

- Mos ndrysho rregullat e sanitizimit të emrave, timestamp-in për emrat ekzistues apo konfirmimin e fshirjes.
- Mos humb funksionalitetin "Cancel" në modalet (rikthim te modali i ngarkimit kur ka draft).

## Kriteret e përfundimit

- Q04–Q08 kalojnë. Q04 verifikohet me `reactlog` ose me numërim render-ash: **një** render për output pas aktivizimit.
- `grep` nuk gjen asnjë nga 5 inputet e fshehura.
- Smoke test-i, Q29, Q30 kalojnë.

## Dorëzimi

STATUS.md, TASKS.md, ISSUES.md, Obsidian. Commit i sugjeruar: `refactor(faza-4): mod_datasets si burim i vetëm (V-04)`.
