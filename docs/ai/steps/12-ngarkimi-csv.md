# Faza 12 — Ngarkimi i CSV-së dhe pamja e vogël

Statusi: **commit `b32c558`** (2026-10-30, V-33, V-34); B-31 gati, pa commit (V-35; provat te STATUS "Faza 12 — rezultati"). Problemet: U-13 (pjesa e CSV-së), B-25, B-26 (rruga e tyre zëvendësohet), B-31. Vendimet: V-29, V-32, V-33, V-34, V-35. Varet nga: 10, 11.

Kërkesa e përdoruesit (2026-10-30): modali i ngarkimit me një kuti të vetme (jo dy kornizat që mbivendosen) dhe ikonë Excel-i në vend të resë; pas zgjedhjes së skedarit, ngarkimi si te fotot, me ikonë skedari Excel-i si preview; pas ngarkimit një pamje e vogël si shembulli i ChatGPT-së, vetëm rreth 5 rreshta × 8 kolona; "Vazhdo" dhe modali i dytë nuk ndryshojnë.

## Veprimet

1. **Pritja e përbashkët:** funksionet e pritjes dhe filtri i `registerDataObj` bëhen të përbashkëta për fotot dhe CSV-në, pa logjikë të kopjuar; pamja dhe sjellja e fotove nuk ndryshojnë.
2. **Serveri i CSV-së:** `csv_stage_add()` (vetëm `.csv`, kufiri `UPLOAD_MAX_MB`), `read_data_safe(n_max)`, numri i rreshtave nga indeksi i `readr`, `csv_glance()` dhe `csv_glance_ui()`.
3. **`mod_datasets`:** hiqet `fileInput`; `csv_uploaded` lexon pamjen dhe fsheh zonën, X-i i pamjes (`csv_glance_remove`) e heq skedarin dhe e rikthen zonën (V-34); "Vazhdo" lexon gjithë skedarin; "Anulo", ruajtja dhe hapja e re zbrazin pritjen.
4. **JS:** `initServerPond` shërben të dyja mënyrat; hiqet ura e vjetër e `fileInput`-it (`sync`, proxy, `watchUploadError`, `clearPond`).
5. **CSS dhe ikonat:** një kuti e vetme, `font-size: 16px`, unaza, tabela; dy ikona SVG bardh e zi te `www/icons/` (V-34).
6. **Testet:** B-03, Q06, Q07 me rrugën e re, me të njëjtat pritje; pritja e CSV-së, titulli, pamja, kufijtë 5 × 8.

## Mos bëj

- Mos ndrysho modalin e konfigurimit, "Vazhdo" përtej vendit të leximit, as `prepare_series` (P-13).
- Mos ndrysho pamjen e zonës së fotove.
- Mos ruaj asgjë te `storage/datasets/` para "Ruaj".
- Mos prek skedarët e përdoruesit te `Downloads`: provat bëhen me kopje.
- Asnjë ndryshim te rezultatet statistike. Mos bëj commit, merge, tag apo push.

## Kriteret e përfundimit

- Q29 dhe Q30 kalojnë.
- Në browser, në një kopje: CSV 12 MB dhe 122 MB me progres; ndalimi, riprovimi, X-i, "Anulo" gjatë ngarkimit; pamja del menjëherë dhe tregon 5 × 8; "Vazhdo" lexon gjithë skedarin; kthimi nga konfigurimi; "Ruaj" e ruan; 256 MB, TXT dhe skedari vetëm me kokë refuzohen; asgjë te `storage/datasets/` para "Ruaj"; 375 px; anglisht; fotot punojnë si më parë; console 0.

## Dorëzimi

STATUS.md, TASKS.md, ISSUES.md, DECISIONS.md, HANDOFF.md, Obsidian.
