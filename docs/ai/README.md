# Udhëzuesi i projektit për AI

Ky dokumentacion përmbledh analizën dhe bisedat për Shiny App (Time Series Analysis) dhe i shndërron në hapa të zbatueshëm për ristrukturimin në branch-in `ultimate_version`.

## Leximi

| Dokumenti | Çfarë përmban |
|---|---|
| [HANDOFF.md](HANDOFF.md) | Rruga e sesioneve, mënyra e punës me përdoruesin, pika e vazhdimit. **Lexoje i pari në një bisedë të re.** |
| [SPEC.md](SPEC.md) | Kërkesat e konfirmuara (Rxx) dhe sjellja që duhet ruajtur. |
| [DECISIONS.md](DECISIONS.md) | Vendimet e pranuara (V-xx) dhe pyetjet e hapura. |
| [STATUS.md](STATUS.md) | Gjendja reale, detyra e fundit, pika e vazhdimit. |
| [TASKS.md](TASKS.md) | Fazat, varësitë, gjurmimi i kërkesave dhe problemeve. |
| [steps/](steps/) | Një dokument për çdo fazë (00–08). |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Struktura e synuar, kontratat mes pjesëve, rregullat e kodit. |
| [ISSUES.md](ISSUES.md) | Problemet e gjetura (P/B/D/U) me vendndodhje dhe zgjidhje. |
| [QUALITY.md](QUALITY.md) | Si verifikohet çdo ndryshim, toleranca, skenarët Qxx. |
| [PONYTAIL.md](PONYTAIL.md) | Si përdoret Ponytail pa hequr pjesë të kërkesës. |
| [OBSIDIAN.md](OBSIDIAN.md) | Kujtesa e projektit dhe dokumentimi gjatë zhvillimit. |

## Si interpretohen dokumentet

**Kërkesë e konfirmuar:** vjen nga kërkesat e përdoruesit, nga zgjedhjet e pranuara në bisedë, ose nga sjellja ekzistuese e app-it që duhet ruajtur.

**Propozim zbatimi:** mënyrë e sugjeruar për realizim. AI mund ta përmirësojë brenda fushës së autorizuar dhe duhet të dokumentojë arsyen. Nuk është kërkesë shtesë nga përdoruesi.

**Vendim i hapur:** sjellja ende nuk është përcaktuar. Para zbatimit të pjesës që varet prej saj, vendimi merret me përdoruesin. Pjesët e pavarura vazhdojnë.

**Kriter pranimi:** provë që një sjellje e konfirmuar punon. Pa provë, kriteri nuk është plotësuar.

## Vendndodhjet

- Projekti: `C:\Users\User\Documents\shinyapp_r` (repo `https://github.com/Amarildo16/shinyapp_r`).
- Branch-i i punës: `ultimate_version`. Versioni që përdor zysha: `main`.
- Vault-i: `C:\Users\User\Documents\Obsidian\Amarildo Workspace\Amarildo Workspace`.
- Folderi i projektit në vault: `10 - Projects\Shiny App`.
- Projekti referencë për këto rregulla: `C:\Users\User\Desktop\beach_works` (vetëm si model; mos e ndrysho).
- Këto rrugë janë të këtij kompjuteri. Në një pajisje tjetër gjenden përsëri, nuk krijohen verbërisht.

## Parimi i versionimit

Dokumentet në projekt mbajnë specifikimin aktual dhe provat e lidhura me kodin. Obsidian mban vazhdimësinë e punës dhe vendimet për t'u rilexuar. Nëse ndryshojnë, kontrollo udhëzimin më të fundit të përdoruesit dhe provat, pastaj pajto dokumentet. Asnjë shënim i vjetër nuk autorizon fshirje kodi, të dhënash apo historiku.
