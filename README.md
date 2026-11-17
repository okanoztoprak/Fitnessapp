# POWER UP

Native iPhone-app (SwiftUI, SwiftData, iOS 18+) om krachttraining, gewicht en voeding bij te houden. Modern en donker van opzet, met één felle accentkleur, en gebouwd rond drie vragen: hoe hersteld ben ik, wat train ik vandaag, en word ik sterker?

## Wat de app doet

| Onderdeel | Wat het is | Geïnspireerd door |
|---|---|---|
| Gereedheid | Dagscore 0–100 uit het herstel per spiergroep en de trainingsbelasting van deze week | WHOOP, Bevel |
| Herstel per spiergroep | Percentage per spiergroep; tik voor een focus-training | Fitbod |
| Slimme training | Workout uit de spiergroepen die het best hersteld zijn | Fitbod |
| Aanbeveling | Trainen of rusten, met uitleg en de schemadag die aan de beurt is | Fitbod, Alpha Progression |
| Logscherm | Kolom "Vorige" (tik om over te nemen), live duur/volume/sets, zwevende rusttimer | Strong, Hevy |
| Doel per oefening | Dubbele progressie: eerst reps, dan gewicht | Alpha Progression |
| Records | Melding met confetti bij een nieuw record, vanaf de tweede sessie | Hevy, Strong |
| Samenvatting | Na afloop: cijfers, records, vergelijking, deelbare kaart | Hevy |
| Voortgang | Consistentieraster, gewichtstrend (EMA), volume per week, spierbalans | MacroFactor, Hevy |
| Profiel | Krachtniveau per lift ten opzichte van lichaamsgewicht, mijlpalen | Strength Level, Hevy |

## Bouwen

```sh
brew install xcodegen
xcodegen generate
open PowerUp.xcodeproj
```

Kies een iPhone-simulator en druk op Run. Het Xcode-project wordt gegenereerd uit `project.yml` en staat niet in git.

Tests van de rekenlaag:

```sh
swift test --package-path Packages/PowerCore
```

## Structuur

| Pad | Inhoud |
|---|---|
| `Packages/PowerCore` | Pure berekeningen met unit-tests: TDEE/BMR, 1RM, gewichtstrend, PR-detectie, progressie, trainen-of-rusten, spierherstel, gereedheid, belasting, weekreeks, krachtniveau, schijvencalculator |
| `PowerUp/Models` | SwiftData-modellen |
| `PowerUp/Services` | Oefenbibliotheek, startschema's, historie, aanbevelingen (`Coach`), statistieken (`Insights`), rusttimer |
| `PowerUp/Design` | Thema en gedeelde componenten (ringen, kaarten, knoppen, confetti) |
| `PowerUp/Features` | Schermen per tab: Vandaag, Training, Voortgang, Voeding, Profiel, plus onboarding en instellingen |
| `scripts/make_strings.py` | Genereert de Engelse vertalingen in `PowerUp/Localizable.xcstrings` |

## Fases

1. **MVP** (deze stand): onboarding, trainingen loggen, oefenbibliotheek, aanbevelingen, gereedheid en herstel, records, samenvatting, voortgang, krachtniveau, gewichtstrend, TDEE-calculator
2. Voeding: Apple Health/MyFitnessPal-sync, macrodoelen, adaptieve TDEE, wekelijkse check-in; slaap en hartslag tellen mee in de gereedheid
3. Coach: volledige programma's, deload, volume-doelen per spiergroep
4. Motivatie: uitdagingen, wekelijkse terugblik, sociale functies
5. Polish: widgets, Live Activities voor de rusttimer, Siri, CloudKit, Watch-app

De app geeft geen medisch advies.
