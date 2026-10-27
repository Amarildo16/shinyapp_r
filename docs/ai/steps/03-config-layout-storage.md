# Faza 03 — Config, layout, storage, i18n

Statusi: **i përfunduar** (2026-10-27, pa commit). Kërkesat: R07, R20, R22, R23, R26. Problemet: P-11 (konstantet), P-12 (pa `AFFECTS`), U-04 (pa fotot), U-01 (infrastruktura). Vendimet: V-05, V-09, T-08 – T-13.

> [!note] Rezultati (2026-10-27)
> - Migrimi bëhet një herë, me shënues; dataset-et e state-it të vjetër që mungojnë te `data/` merren nga `data/samples/`; çdo kopje verifikohet me md5 (T-08). Përshkrimi i plotë: STATUS.md "Faza 3 — rezultati".
> - `PAGES` ruan ID-të ekzistuese (`stationary`), sepse përdoren nga JS dhe nga `background_state.json`.
> - `ui` u bë `function(req)` (T-11); navigimi është `mod_nav_server()` pa `moduleServer()` (T-10).
> - `sq.json` mban tekstet e sotme (T-12), që pamja shqip të mbetet identike; diff-i i HTML-së e vërteton.

## Qëllimi

Një vend i vetëm për faqet dhe konstantet, UI e përbashkët si funksione, dhe të dhënat e përdoruesit jashtë kodit, pa humbur asgjë.

## Veprimet

1. `R/config.R`:
   - `PAGES` (id, menu, title)
   - ngjyrat e serive
   - kufijtë e horizontit dhe të dritares (të njëjtat vlera si sot)
   - `DUP_POLICY = "mean"`, `FREQ_POLICY = "auto"` (P-11, sjellje identike)
   - shtigjet `STORAGE_DIR`, `SAMPLES_DIR`
2. `R/ui_components.R`: `app_page()`, `app_sidebar(PAGES)`, `app_topbar()`, `preloader()`, `glass_modal()`, `section_box()`. HTML-i i gjeneruar duhet të ketë të njëjtat klasa CSS, që pamja të mos ndryshojë.
3. `R/mod_nav.R`: navigimi dhe titulli i topbar-it nga `PAGES`.
4. JS (`sidebar.js`, `bg.js`) merr hartën e faqeve nga R (atribute `data-` në HTML ose custom message), pa ID të shkruara me dorë (P-12).
5. `R/storage.R` → `init_storage()` (U-04):
   - krijon `storage/datasets`, `storage/images`, `storage/state`
   - **migrimi:** nëse gjen CSV/JSON te `data/` (struktura e vjetër) dhe `storage/` nuk i ka, **i kopjon**. Para kopjimit ruan kopje rezervë të JSON-eve te `storage/state/backup-<data>/`. Origjinalet nuk preken.
   - **shembujt:** nëse `storage/datasets` është bosh pas migrimit, kopjon nga `data/samples/`.
   - shtigjet e brendshme në state (emrat e file-ve) mbeten të vlefshme pas migrimit.
6. Zhvendos CSV-të shembull te `data/samples/`.
7. Funksionet e state-it shkruajnë te `storage/state/`.
8. **i18n (V-09):**
   - `R/i18n.R` me `tr(key, ...)` (zëvendësim parametrash), `current_lang()`, leximin e `i18n/sq.json` dhe `i18n/en.json`
   - gjuha e paracaktuar: `sq`
   - ruajtja te `storage/state/settings.json`
   - zgjedhja e gjuhës në Settings; ndërrimi ruan dhe thërret `session$reload()`
   - formatimi i numrave (`fmt_*`) merr gjuhën: shqip `1 234,56` + mijë/mln/mld, anglisht `1,234.56` + K/M/B
   - çelësat për layout-in, sidebar-in, topbar-in dhe Settings shtohen tani; çdo modul i ri i shton të vetët
   - test: `test-i18n.R` (të njëjtët çelësa në të dyja gjuhët, asnjë vlerë bosh, formati i numrave)

## Mos bëj

- Mos fshi asgjë nga `data/` e përdoruesit. Pas migrimit, `data/` e vjetër mbetet; pastrimi bëhet vetëm me kërkesë të përdoruesit.
- Mos ndrysho pamjen.

## Kriteret e përfundimit

- Q02 (klon i ri) dhe Q03 (migrim, mbi një **kopje** të strukturës së vjetër) kalojnë.
- Sidebar-i, titujt dhe kartat e background-it gjenerohen nga `PAGES`.
- Ndërrimi i gjuhës punon për pjesët e ndërtuara deri tani dhe ruhet pas rinisjes (Q31 i pjesshëm, Q32).
- Smoke test-i, Q29 dhe Q30 kalojnë.

## Dorëzimi

STATUS.md (me përshkrimin e migrimit), TASKS.md, ISSUES.md, Obsidian. Commit i sugjeruar: `refactor(faza-3): config, layout dhe storage me migrim`.
