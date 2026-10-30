# Faza 11 — Ngarkimi i fotove (si media library)

Statusi: **commit `6b01bd8`** (2026-10-29, V-29); preview e fotove (V-30, U-14) gati, pa commit (provat te STATUS "Faza 11 — rezultati"). Problemet: B-28, B-29, U-12, U-13, U-14. Vendimet: V-29, V-30. Varet nga: 10.

Kërkesa e përdoruesit (2026-10-29): ngarkimi i fotove si media library e WordPress-it. Te skeda Ngarko, butonat "Ruaj fotot" dhe "Anulo"; një ose shumë foto ngarkohen menjëherë me progresin e FilePond-it dhe secila hiqet veç e veç; "Ruaj fotot" i mban, "Anulo" i hedh, të dyja të çojnë te Galeria. Pa vijën nën skeda dhe me tekst të lexueshëm në zonën e ngarkimit. CSV-ja dhe pamja e saj e shkurtër janë Faza 12.

## Veprimet

1. **Prototipi** (V-29 d): FilePond-i i dërgon fotot drejt e te serveri, një adresë për çdo sesion me `session$registerDataObj()`; progresi, ndalimi dhe heqja e çdo skedari. Nëse rruga nuk punon, ndalesë dhe raport para se të vazhdohet.
2. **Pritja** (V-29 a): fotot e ngarkuara presin te një dosje e përkohshme e sesionit (`tempdir()`); "Ruaj fotot" i kalon te `storage/images/` me `bg_store_upload()` (i njëjti kontroll si sot); "Anulo", X-i i çdo fotoje, hapja e ardhshme e Galerisë (kur modali mbyllet pa "Ruaj fotot") dhe mbarimi i sesionit i hedhin vetëm nga dosja e pritjes. Asgjë nga Galeria nuk fshihet.
3. **Butonat:** te skeda Ngarko "Ruaj fotot" + "Anulo"; te Galeria "Përdor foton" + "Mbyll" si sot.
4. **Kufiri i fotove 5 MB** edhe te FilePond-i (V-29 b), nga `BG_UPLOAD_MAX_BYTES`.
5. **Pamja:** skedat Galeria/Ngarko si çelës me dy pjesë, pa vijë; zona e ngarkimit me ikonë, titull dhe nëntitull të lexueshëm; tekstet e FilePond-it në të dyja gjuhët.
6. Testet: pritja (shto, hiq, ruaj, anulo), adresa e FilePond-it (përgjigjet, kufiri, skedari i pavlefshëm), butonat sipas skedës.

## Mos bëj

- Mos ndrysho ngarkimin e CSV-së (Faza 12) as konfigurimin e dataset-it.
- Mos fshi asgjë nga `storage/images/` apo `www/images/`.
- Mos ndrysho mënyrën si zgjidhet fotoja e sfondit ("Përdor foton").
- Mos bëj merge, tag apo push.

## Kriteret e përfundimit

- Q29 dhe Q30 kalojnë.
- Në browser: disa foto njëherësh dhe një nga një, me progres; heqja e njërës; "Ruaj fotot" → Galeria me fotot e reja; "Anulo" → asnjë foto e re; foto mbi 5 MB dhe skedar jo-foto refuzohen me mesazh; console 0.

## Dorëzimi

STATUS.md, TASKS.md, ISSUES.md, DECISIONS.md, HANDOFF.md, Obsidian.
