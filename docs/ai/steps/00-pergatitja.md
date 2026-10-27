# Faza 00 — Përgatitja

Statusi: **i përfunduar** (2026-10-27): veprimet 1–8 u kryen nga Claude Code; Q01 kalon sipas V-13. Kërkesat: R21, R24, R25. Problemet: U-03, U-06. Vendimet: V-06, V-07, V-12 (discard), V-13, T-01 – T-04.

> [!note] Ndryshime nga plani fillestar (2026-10-27)
> - R ishte i arritshëm nga Claude Code (QUALITY rruga 0), prandaj `renv::init()`, `make_reference.R` dhe screenshot-et u bënë nga Claude, jo nga përdoruesi.
> - Veprimi 1: me `core.autocrlf=input` git nuk tregonte ndryshim, prandaj nuk kishte çfarë të hidhej poshtë.
> - Veprimi 6: logjika llogaritëse është te `tests/reference/compute_results.R` (T-03); `make_reference.R` dhe `compare_reference.R` e përdorin.
> - Rezultatet e plota: STATUS.md "Faza 0 — rezultati".

## Qëllimi

Terren i sigurt para çdo ndryshimi kodi: versione të fiksuara, një "fotografi" e saktë e rezultateve dhe e pamjes aktuale, dhe git pa zhurmë line endings.

## Para se të fillosh

- Lexo CLAUDE.md, SKILL.md, HANDOFF.md, STATUS.md, DECISIONS.md.
- Konfirmo me `git status` dhe `git log` që `ultimate_version` është ende te `976dce0` plus vetëm udhëzimet. Nëse kodi ka ndryshuar, ndalo dhe pyet.

## Veprimet

1. V-12: hidh poshtë ndryshimin e line endings (`git checkout -- data/datasets_state.json` ose `git restore`). Kontrollo më parë që `git diff --ignore-cr-at-eol` është bosh; nëse jo, ndalo dhe pyet.
2. `.gitattributes`: `* text=auto eol=lf`. Shëno si `binary` fotot, fontet, `.rds`, `.xlsx`, `.ico`.
3. `.gitignore`: `*.Rproj` (në vend të `.Rproj`), `storage/`, `renv/library/`, `renv/staging/`, `renv/local/`. Mos hiq rreshtat ekzistues.
4. `install_packages.R`: kodi i instalimit nga README, **pa** `vars` dhe `rugarch` (D-04). README nuk ndryshohet ende.
5. `renv`: përdoruesi ekzekuton `renv::init()` në RStudio (Claude nuk ka R). Commit-ohen `renv.lock`, `renv/activate.R`, `.Rprofile`. Versionet që ka zysha / përdoruesi sot janë referenca.
6. `tests/reference/make_reference.R`: përdor **kodin aktual** (`helpers.R`, logjika e `server_plots.R` e riprodhuar me të njëjtat thirrje) mbi të dy dataset-et shembull dhe ruan në `tests/reference/<dataset>.rds`:
   - `df_dyn` (të dhënat e përgatitura)
   - statistikat përmbledhëse
   - mesataren lëvizëse (k = 3, 5)
   - korrelacionin dhe regresionin (çiftet e para)
   - diferencën e parë, ACF dhe PACF
   - ADF (statistika, p-value, nivel dhe Δ)
   - ETS dhe `auto.arima` (forma, koeficientët, parashikimet për h = 1, 5, max)
   - SES dhe Holt (parashikimet + intervalet)
   - saktësinë (`accuracy`)
   - `sessionInfo()`
7. `tests/reference/compare_reference.R`: rillogarit me kodin e ri dhe krahason me tolerancat e QUALITY.md. Në këtë fazë kodi i ri = kodi i vjetër, prandaj krahasimi duhet të kalojë 100%.
8. Screenshot-e të çdo faqeje, me të dy dataset-et, në Settings dhe në Media Library → Obsidian `Shiny App/screenshots/para/`. Bëhen nga përdoruesi, ose nga Claude me browser-in e integruar nëse përdoruesi e nis app-in.

## Mos bëj

- Mos ndrysho asnjë rresht në `app.R`, `helpers.R`, `server_plots.R`, `www/`.
- Mos e rigjenero referencën më vonë për të kaluar një test.

## Kriteret e përfundimit

- `git status` nuk tregon ndryshime line endings pa ndryshim real.
- `renv.lock` ekziston dhe `renv::status()` është i pastër.
- `make_reference.R` u ekzekutua nga përdoruesi; `.rds` janë në repo. `compare_reference.R` kalon mbi kodin aktual.
- Screenshot-et "para" janë në Obsidian.
- Q01 kalon (në Fazat 0–4 sipas V-13: lejohen vetëm B-11/B-12).

## Dorëzimi

STATUS.md (me `sessionInfo()` kryesor), TASKS.md, Obsidian (ditari, plani, `Shiny App.md`). Sugjero mesazhin e commit-it: `chore(faza-0): renv, referenca, gitattributes`.
