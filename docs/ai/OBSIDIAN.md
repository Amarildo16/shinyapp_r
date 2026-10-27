# Protokolli i kujtesës në Obsidian

## Kufiri

Përdoruesi kërkon që puna e projektit të dokumentohet në Obsidian dhe të rilexohet. Ky protokoll zbatohet si pjesë e çdo detyre të autorizuar, përveçse kur përdoruesi e ndalon shprehimisht.

## Vendndodhja

- Vault: `C:\Users\User\Documents\Obsidian\Amarildo Workspace\Amarildo Workspace`
- Folderi i vetëm i synuar: `10 - Projects\Shiny App`
- Mos ndrysho projekte të tjera, `.obsidian`, temat, plugin-et, shabllonet apo strukturën e workspace-it. `40 - Templates` lexohet vetëm si model.
- Kontrollo rrugën reale para shkrimit në një kompjuter tjetër.

## Shënimet ekzistuese dhe roli i secilit

| Shënimi | Roli | Kur përditësohet |
|---|---|---|
| `Shiny App.md` | Faqja kryesore sipas shabllonit "Project Dashboard": status, fokusi, hapat e radhës, vendimet kryesore | Në fund të çdo faze ose kur ndryshon fokusi |
| `01 - Analiza e gjendjes aktuale.md` | Fotografia e kodit para ristrukturimit | Nuk mbishkruhet. Në fund shtohet seksioni "Gjendja pas ristrukturimit". |
| `02 - Problemet e gjetura.md` | Problemet me ID | Kur një problem mbyllet (kuti + faza + prova) ose gjendet problem i ri |
| `03 - Arkitektura e re.md` | Struktura e synuar | Kur një vendim e ndryshon strukturën |
| `04 - Plani i punës.md` | Fazat dhe statuset | Në fillim (🟨) dhe në fund (✅) të çdo faze |
| `05 - Vendimet.md` | Vendimet V-xx | Kur merret ose ndryshon një vendim |
| `06 - Ditari i punës.md` | Një hyrje për çdo seancë, më e reja lart | Në fund të çdo seance pune |
| `screenshots/para/`, `screenshots/pas/` | Pamjet për krahasim vizual | Faza 0 (para), pas fazave 5–8 (pas) |

Mos krijo dublikatë të një shënimi ekzistues. Shënimet e reja shtohen vetëm kur kanë rol të qartë dhe lidhen nga `Shiny App.md`.

## Çfarë do të thotë "çdo gjë të shënohet"

Ruaj çdo kërkesë, vendim, ndryshim me rëndësi, pengesë, rezultat verifikimi dhe detyrë të pambyllur që duhet për vazhdimin e saktë. Nuk kërkohet kopjimi i çdo daljeje terminali apo i kodit.

Shëno edhe ndryshimet e drejtimit, p.sh.: "u diskutua rishkrimi në C++, u refuzua (V-01)". Mos paraqit një ide të hequr si kërkesë aktive.

Mos kopjo në Obsidian të dhënat e dataset-eve të zyshës.

## Para një detyre

1. Lexo STATUS.md, vendimet dhe hapin aktiv në projekt.
2. Lexo `Shiny App.md`, hyrjen e fundit te `06 - Ditari i punës.md` dhe shënimet relevante.
3. Kontrollo punën e pambyllur. Mos përsërit hapa të kryer pa arsye të re.
4. Nëse dokumentet kundërshtojnë njëri-tjetrin, gjej udhëzimin më të fundit të përdoruesit dhe provat reale. Mos i zgjidh konfliktet me hamendje ose fshirje.

## Hyrja e ditarit për një seancë

Përmbajtja minimale:
1. Data (zona kohore Europe/Berlin) dhe faza.
2. Kërkesa e përdoruesit dhe fusha e autorizuar.
3. Kërkesat Rxx dhe problemet (P/B/D/U) që u prekën.
4. Vendimet e marra, arsyet dhe pyetjet që mbeten.
5. Ndryshimet konkrete dhe skedarët kryesorë.
6. Kontrollet e ekzekutuara me rezultatet dhe kush i ekzekutoi.
7. Defektet, kufizimet dhe pikat e pambyllura.
8. Hapi i radhës dhe kushtet që kërkon.
9. Commit-i vetëm nëse ekziston realisht; mos shpik identifikues.

## Shkrimi dhe verifikimi

- Lexo përmbajtjen para editimit. Ruaj shënimet e përdoruesit; përditëso seksionin përkatës ose shto seksion të qartë.
- Mos fshi historinë e vendimeve. Shëno "Zëvendësuar nga V-xx" dhe lidh vendimin e ri.
- Pas shkrimit rilexo skedarët e prekur dhe kontrollo datat, statuset dhe lidhjet `[[...]]`.
- Përditëso STATUS.md me gjendjen: "pasqyruar", "në pritje" ose "ndaluar për këtë detyrë".

## Kur nuk mund të shkruhet

Nëse lejet, rruga ose ndalimi i përdoruesit e pengojnë, mos krijo vault të dytë. Ruaj shënimin te `docs/ai/pending-obsidian/` vetëm kur ka përmbajtje reale; mos e krijo folderin bosh. Regjistro mungesën në STATUS.md. Kur pengesa hiqet, pasqyroji një herë, verifikoji dhe shëno që janë pasqyruar.
