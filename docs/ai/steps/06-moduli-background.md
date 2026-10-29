# Faza 06 — Moduli i background-it

Statusi: **gati, pa commit** (2026-10-29, V-22, T-26). Kërkesat: R17, R18, R19, R23. Problemet: P-08, P-09, P-10, B-08. Varet nga Faza 03.

## Qëllimi

Background-i dhe Media Library bëhen modul i vetëm, me state te `storage/` dhe me fotot e përdoruesit jashtë kodit.

## Veprimet

1. `mod_background_ui(id)` / `mod_background_server(id)`, me Media Library brenda dhe `glass_modal()` (P-08). ✅
2. `state_background.R` shkruan te `storage/state/`; migrimi i `background_state.json` bëhet nga `init_storage()` (Faza 03). ✅ (që nga Faza 3)
3. Fotot e ngarkuara → `storage/images/`, të shërbyera me `addResourcePath("user-images", ...)`. Fotot default mbeten te `www/images/` (`images/...`). State-i ruan prefiksin përkatës. ✅
4. Migrimi i fotove: fotot e ngarkuara në të kaluarën te `www/images/` që nuk janë nga 12 default-et kopjohen te `storage/images/` dhe state-i përditësohet, me kopje rezervë. ✅ (V-22 b: origjinalet mbeten, jashtë galerisë)
5. Emrat e fotove në JS kalojnë me `jsonlite::toJSON()` (B-08). ✅
6. State-i lexohet një herë (P-09); placeholder-i SVG lëviz te `ui_components.R` / `config.R` (P-10). ✅
7. Validimi i ngarkimit (`validate_bg_upload_file`) dhe kontrolli "në përdorim" para fshirjes mbeten identikë. ✅ (+ V-22 a: defaultet nuk fshihen)

8. Çdo tekst i dukshëm i modulit kalon nga `tr()`, me çelësa në `sq.json` dhe `en.json` (R26). ✅ (V-22 c)
## Kriteret e përfundimit

- Q20–Q23 kalojnë, përfshirë rinisjen e app-it.
- Background-i i ruajtur më parë nga përdoruesi shfaqet njësoj pas migrimit.
- Smoke test-i kalon.

## Dorëzimi

STATUS.md, TASKS.md, ISSUES.md, Obsidian. Commit i sugjeruar: `refactor(faza-6): mod_background dhe storage/images`.
