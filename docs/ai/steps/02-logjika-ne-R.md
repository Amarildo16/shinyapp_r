# Faza 02 — Logjika e pastër → `R/` + testet

Statusi: **i pafilluar**. Kërkesat: R05, R08, R15, R21, R22. Problemet: P-01 (pjesë), P-02, P-03, B-01, D-05.

## Qëllimi

`helpers.R` zhduket. Çdo funksion shkon në file-in e vet tematik te `R/` dhe merr teste. **Sjellja dhe rezultatet nuk ndryshojnë**, përveç paraqitjes së numrave (B-01).

## Lexo para

ARCHITECTURE.md: tabela "Nga ku vjen çdo pjesë e kodit aktual". ISSUES.md: P-02, P-03, B-01, D-05.

## Veprimet

1. Krijo `R/` dhe file-t sipas tabelës. Lëvizja bëhet **pa ndryshuar trupin e funksioneve** (copy → verifiko → fshi origjinalin).
2. Zhvendos `library()` dhe `options(scipen = 999)` te `app.R`.
3. Zhvendos `server_plots.R` → `R/legacy_server_plots.R` (i përkohshëm, fshihet në Fazën 05).
4. Hiq `source("helpers.R")` dhe `source("server_plots.R")`.
5. Konfirmo që `get_app_dir()` jep të njëjtin rezultat kur `R/` ngarkohet automatikisht (`shiny.appdir`, RStudio, `getwd()`).
6. `detect_numeric_cols(d, exclude, threshold = 0.70)`: zëvendëso **të 8 kopjet** (P-02). Sjellja identike, përfshirë rastin "asnjë numerike → të gjitha kolonat".
7. `resolve_dataset_defaults(d, cfg)`: zëvendëso **të 6 kopjet** (P-03). Kthen `time_choices`, `time_col`, `num_cols`, `value_cols`, me të njëjtat rregulla default (3 seritë e para).
8. B-01: formatimi i tabelave bëhet për gjithë kolonën ose me funksion për vlerë të vetme. **Vetëm paraqitja ndryshon.** Regjistro shembuj para/pas te STATUS.md.
9. D-05: thjeshto degën numerike të `parse_time_safe` pa ndryshuar daljen (testi e provon).
10. Hiq parametrin e papërdorur `context` nga `validate_ts_ready` dhe nga thirrjet.
11. Testet `testthat`:
    - `test-data_parse.R`
    - `test-data_prepare.R`
    - `test-ts_validate.R`
    - `test-utils_format.R` (përfshirë B-01)
    - `test-utils_paths.R` (`../`, shtigje absolute, emra të rrezikshëm)
12. `tests/fixtures/`: dataset-et e listuara te QUALITY.md.

## Mos bëj

- Mos "përmirëso" logjikën gjatë lëvizjes. Lëvizja dhe ndryshimi janë hapa të veçantë.
- Mos ndrysho pragun 0.70, rendin e kandidatëve të kohës apo rregullat e default-eve.

## Kriteret e përfundimit

- `helpers.R` nuk ekziston. `app.R` nuk ka `source()`.
- Çdo funksion i pastër ka të paktën një test. Testi i B-01 dështon mbi kodin e vjetër dhe kalon mbi të riun.
- Q29 dhe Q30 kalojnë; smoke test-i kalon.

## Dorëzimi

STATUS.md (me shembujt B-01 para/pas), TASKS.md, ISSUES.md, Obsidian. Commit-e të vegjël, p.sh. `refactor(faza-2): detect_numeric_cols zëvendëson 8 kopjet (P-02)`.
