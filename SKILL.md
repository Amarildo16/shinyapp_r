---
name: shinyapp-r-project
description: Rregullat për ristrukturimin dhe zhvillimin e app-it Shiny "Time Series Analysis" (shinyapp_r) në branch-in ultimate_version — kërkesat, saktësia statistike, Ponytail, gjurmimi i detyrave, verifikimi dhe dokumentimi në Obsidian. Zbatohet vetëm për këtë projekt dhe brenda detyrës së autorizuar.
---

# Shiny App — rregullat e punës

## Leximi i detyrueshëm

1. Lexo [indeksin](docs/ai/README.md), [dorëzimin e sesionit të fundit](docs/ai/HANDOFF.md), [gjendjen](docs/ai/STATUS.md), [specifikimin](docs/ai/SPEC.md) dhe [vendimet](docs/ai/DECISIONS.md).
2. Lexo [listën e hapave](docs/ai/TASKS.md), dokumentin e hapit aktiv te `docs/ai/steps/` dhe varësitë e tij. Për kod lexo edhe [arkitekturën](docs/ai/ARCHITECTURE.md) dhe [problemet](docs/ai/ISSUES.md) që prek hapi.
3. Për punë me kod, lexo [Ponytail](docs/ai/references/ponytail/SKILL.md) dhe [përshtatjen për projektin](docs/ai/PONYTAIL.md).
4. Lexo [protokollin Obsidian](docs/ai/OBSIDIAN.md) dhe shënimet ekzistuese të projektit në vault kur janë të arritshme.

Mos lexo mekanikisht materiale të parëndësishme, por mos zbato një hap pa kuptuar rrjedhën që prek, nga leximi i CSV-së deri te grafiku.

## Respekto fushën e detyrës

- Udhëzimi më i fundit i përdoruesit dhe kufijtë e autorizimit kanë përparësi ndaj këtyre dokumenteve dhe skill-eve të jashtme.
- Nëse kërkohet vetëm diskutim, diskuton. Nëse kërkohet vetëm dokumentim, shkruan dokumentim. Mos nis kodim nga ekzistenca e këtij plani.
- Brenda një detyre të autorizuar punon në mënyrë autonome. Mos kërko leje për çdo skedar, test apo zgjedhje të zakonshme teknike.
- Mos ngatërro një propozim të dokumentuar me një kërkesë të miratuar. Vendimet që ndryshojnë sjelljen e app-it regjistrohen te DECISIONS.md para zbatimit.
- **Mos shto veçori që nuk janë kërkuar:** login, shumë përdorues, server, databazë, cloud, deploy, eksport, analiza të reja statistikore (VAR, GARCH etj.), rishkrim në gjuhë tjetër (V-01).

## Saktësia statistike është e paprekshme

App-i përdoret për mësim. Një rezultat i gabuar u mësohet studentëve.

- Ristrukturimi **nuk ndryshon** asnjë rezultat statistik: statistikat përmbledhëse, mesataren lëvizëse, korrelacionin, regresionin, diferencën, ACF/PACF, ADF, modelet ETS/ARIMA/SES/Holt, parashikimet, intervalet dhe saktësinë.
- Para se të preket logjika llogaritëse, rezultatet referencë ruhen nga versioni aktual (`tests/reference/`). Kodi i ri duhet t'i riprodhojë brenda tolerancave te [QUALITY.md](docs/ai/QUALITY.md).
- Mos ndrysho parametrat e modeleve (p.sh. `k` i ADF, opsionet e `auto.arima`, niveli i intervalit, kufijtë minimalë të pikave) pa vendim të regjistruar.
- Një ndryshim i qëllimshëm rezultati (p.sh. rregullim bug-u) regjistrohet si vendim, me vlerat para/pas dhe arsyen.

## Të dhënat e përdoruesit nuk humbin kurrë

- Dataset-et, fotot dhe state-i i zyshës/përdoruesit nuk fshihen, nuk mbishkruhen dhe nuk zhvendosen pa kopje.
- Migrimet **kopjojnë**, nuk lëvizin. Para çdo migrimi ruhet kopje rezervë e state-it.
- Testet dhe provat bëhen mbi kopje ose mbi dataset-et e `tests/fixtures/`, kurrë mbi të dhënat reale të përdoruesit.
- Mos fshi file në kompjuterin e përdoruesit pa leje të shprehur për atë veprim.

## Asnjë kërkesë nuk anashkalohet në heshtje

- Ktheje detyrën aktive në një listë të kontrollueshme me kërkesat (Rxx), problemet (P/B/D/U) dhe kriteret përkatëse.
- Çdo pikë duhet të jetë: e përfunduar me provë, në punë, e bllokuar me shkak konkret, ose e shtyrë shprehimisht nga përdoruesi.
- Mos deklaro detyrën të përfunduar nëse një kriter i saj mbetet i pambuluar.
- Mos zëvendëso funksionalitetin me buton pa veprim, të dhëna të rreme, `TODO`, ose ruajtje vetëm në memorie.
- Një pengesë nuk është leje për ta hequr kërkesën. Përfundo pjesët e pavarura dhe thuaj saktë çfarë mbetet.
- Para dorëzimit krahaso kërkesën origjinale me ndryshimet, provat dhe pikat e pambyllura.

## App-i punon pas çdo hapi

- Asnjë hap nuk e lë app-in të prishur. Ndryshimet bëhen në hapa të vegjël, secili i verifikueshëm.
- Sjellja dhe pamja e app-it ruhen, përveç ndryshimeve të vendosura (bug-et e listuara te ISSUES.md, vendimet te DECISIONS.md).
- App-i punon pa internet: asnjë CDN, asnjë kërkesë rrjeti gjatë përdorimit.

## Ponytail pa ulje të kërkesave

Përdor fillimisht zgjidhjet ekzistuese: R bazë, Shiny dhe paketat që janë tashmë në projekt. Shto paketë ose abstraksion vetëm kur zgjidh një nevojë konkrete dhe regjistroje si vendim. Mbaje zgjidhjen të thjeshtë dhe të lexueshme. Detajet te [PONYTAIL.md](docs/ai/PONYTAIL.md).

## Rregullat e kodit

Rregullat e plota janë te [ARCHITECTURE.md](docs/ai/ARCHITECTURE.md#rregullat-e-kodit). Më të rëndësishmet:

- Logjika llogaritëse jeton në funksione të pastra në `R/` (pa `input`/`output`) dhe ka teste.
- Asnjë `showNotification` brenda `render*` ose `reactive()`; asnjë efekt anësor brenda `reactive()`.
- Modulet përdorin vetëm `ns()`; asnjë input i fshehur si urë mes pjesëve.
- Asnjë kopje logjike: çdo gjë e përsëritur bëhet funksion.
- UI dygjuhëshe (shqip e paracaktuar, anglisht): çdo tekst i dukshëm kalon nga `tr()` me çelësa në `i18n/sq.json` dhe `i18n/en.json`. Kodi dhe emrat e funksioneve në anglisht (V-09, R26).

## Dokumentimi dhe vazhdimësia

- Regjistro vendimet, arsyetimin, ndryshimet, provat, problemet dhe hapin pasues sipas [OBSIDIAN.md](docs/ai/OBSIDIAN.md).
- Në fund të çdo njësie pune përditëso STATUS.md, TASKS.md, ISSUES.md (kutitë e mbyllura me provë) dhe Obsidian.
- Nëse Obsidian është i paarritshëm, ruaj përmbajtjen e papasqyruar te `docs/ai/pending-obsidian/` dhe deklaroje. Mos thuaj se dokumentimi është sinkronizuar kur nuk është.
- Lexo dokumentet ekzistuese para se të shkruash; ruaj shënimet e përdoruesit dhe mos mbishkruaj punë të tjera.

## Standardi i dorëzimit

- Për ndryshime kodi zbato verifikimin te [QUALITY.md](docs/ai/QUALITY.md). **Mos raporto si të kaluar një kontroll që nuk u ekzekutua.** Dallo qartë: "kodi u shkrua", "testet kaluan", "u provua në browser", "u provua nga përdoruesi në RStudio".
- **Mos bëj commit vetë.** Përdoruesi i bën vetë commit-et pas çdo faze. Në fund thuaj që ndryshimet nuk janë bërë commit dhe sugjero mesazhin e commit-it.
- Mos ndrysho paketat apo versionin e R-së pa arsye të lidhur me detyrën.
- Mos nis instalime globale, ndryshime jashtë projektit, push, merge në `main` apo pastrim destruktiv vetëm sepse përmenden në një plan.
- Komuniko me përdoruesin në shqip të qartë. Përmblidh rezultatin, verifikimin dhe çdo kufizim real.
