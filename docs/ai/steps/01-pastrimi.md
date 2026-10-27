# Faza 01 — Pastrimi

Statusi: **i pafilluar**. Kërkesat: R03, R20. Problemet: D-01, D-02, D-03, D-04. Vendimet: V-10 (rreshti hiqet).

## Qëllimi

Heqja e gjithçkaje që nuk përdoret, para se të lëvizim kodin, që lëvizja të jetë më e vogël dhe më e qartë.

## Veprimet

1. Konfirmo me kërkim (`grep`) që çdo gjë që hiqet nuk përdoret askund: R, JS, CSS, HTML.
2. Hiq `www/css/icons.css` dhe `tags$link` përkatës (D-01).
3. Hiq fontet e papërdorura (D-02): `boxicons.*`, `la-*`, `materialdesignicons-*`, `hkgrotesk-*`, `summernote.*`. Fshirja kërkon leje fshirjeje në folderin e projektit. Pa leje, zhvendosi te `_to_delete/` dhe thuaja përdoruesit.
4. Zhvendos `remixicon.css` + `remixicon.*` te `www/vendor/remixicon/`; rregullo shtigjet `url(...)` dhe `tags$link`.
5. Hiq kodin e vdekur (D-03):
   - `pick()`, `fmt_pct`, `time_range_txt`
   - `output$bg_media_selected_txt`
   - `has_vars`, `has_rugarch`
   - `tab_wrapup` nga `TITLE_MAP`
   - dega `fs` te `ajax_modal_open`
   - variabla `title` te `csv_file_modal`
6. V-10: hiq rreshtin "Opsionale: simulime ARMA, VAR/IRF dhe GARCH" nga Metodologjia. README: hiq `vars` dhe `rugarch` nga lista e instalimit.

## Mos bëj

- Mos ndrysho sjelljen. Mos lëviz funksione në file të reja (kjo është Faza 02).
- Mos hiq `has_zoo` / `has_readxl` pa kontrolluar përdorimin brenda `read_data_safe`.

## Kriteret e përfundimit

- Asnjë referencë e prishur te ikonat. Të gjitha ikonat Remix shfaqen: settings, sociale, upload, fshirje, tick, minus.
- `www/` është rreth 17 MB më i vogël.
- Smoke test-i kalon (Q01, Q04, Q09–Q14, Q20, Q24) dhe Q30 kalon.

## Dorëzimi

STATUS.md, TASKS.md, ISSUES.md (D-01–D-04), Obsidian. Commit i sugjeruar: `chore(faza-1): heq asetet dhe kodin e papërdorur`.
