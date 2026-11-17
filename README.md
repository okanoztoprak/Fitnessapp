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
| Voeding | Wat je vandaag nog kunt eten, macro's per dag, week in één grafiek, snel toevoegen | MacroFactor, MyFitnessPal |
| Adaptief verbruik | Verbruik uit inname en trendgewicht, met zekerheid; tikfouten in het gewicht tellen niet mee | MacroFactor |
| Wekelijkse check-in | Nieuw caloriedoel op basis van je echte verbruik, in kleine stappen en nooit onder je rustverbranding | MacroFactor |
| Apple Health | Voeding (ook uit MyFitnessPal), weegschaal en slaap; slaap telt mee in de gereedheid | WHOOP, MacroFactor |
| Profiel | Krachtniveau per lift ten opzichte van lichaamsgewicht, mijlpalen | Strength Level, Hevy |
| Programma's | Blok van 4–6 weken: elke week dichter bij falen (RIR 3 → 1) en voor spiermassa meer sets, met een deloadweek aan het eind | RP Hypertrophy, Alpha Progression |
| Volume per spiergroep | Harde sets deze week tegen een streefbereik dat met het blok meegroeit | RP Hypertrophy |
| Coach | Deload-advies bij stilstand, hoge belasting of lange reeks; melding als een oefening stilstaat | Fitbod, Alpha Progression |
| Oefening vervangen | Alternatief voor dezelfde spiergroep met je materiaal, zonder van hoofdlift te wisselen | Fitbod, Hevy |

## Bouwen

```sh
brew install xcodegen
xcodegen generate
open PowerUp.xcodeproj
```

Kies een iPhone-simulator en druk op Run. Het Xcode-project wordt gegenereerd uit `project.yml` en staat niet in git.

Apple Health testen in de simulator: de app heeft de HealthKit-entitlement nodig, dus bouw met een lokale handtekening in plaats van `CODE_SIGNING_ALLOWED=NO`:

```sh
xcodebuild build -project PowerUp.xcodeproj -scheme PowerUp \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build-signed CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
```

In testversies staat onder Voeding → Apple Health een knop die drie weken voorbeeldvoeding, -gewicht en -slaap in Health zet. Voor een echt toestel zijn een eigen bundle-ID en een ontwikkelaarsteam nodig.

Tests van de rekenlaag:

```sh
swift test --package-path Packages/PowerCore
```

## Structuur

| Pad | Inhoud |
|---|---|
| `Packages/PowerCore` | Pure berekeningen met unit-tests: mesocyclus, volumedoelen, stilstand en deload, TDEE/BMR, macro's, adaptief verbruik, wekelijkse check-in, slaap, 1RM, gewichtstrend, PR-detectie, progressie, trainen-of-rusten, spierherstel, gereedheid, belasting, weekreeks, krachtniveau, schijvencalculator |
| `PowerUp/Models` | SwiftData-modellen |
| `PowerUp/Services` | Oefenbibliotheek, startschema's, historie, aanbevelingen (`Coach`), programma's en volume (`ProgramCoach`), statistieken (`Insights`), voedingsplan en sync (`NutritionPlan`, `HealthSync`), rusttimer |
| `PowerUp/Services/Health` | `NutritionSource`-protocol en de Apple Health-koppeling |
| `PowerUp/Design` | Thema en gedeelde componenten (ringen, kaarten, knoppen, confetti) |
| `PowerUp/Features` | Schermen per tab: Vandaag, Training, Voortgang, Voeding, Profiel, plus onboarding en instellingen |
| `scripts/make_strings.py` | Genereert de Engelse vertalingen in `PowerUp/Localizable.xcstrings` en `PowerUp/InfoPlist.xcstrings` |

## Fases

1. **MVP**: onboarding, trainingen loggen, oefenbibliotheek, aanbevelingen, gereedheid en herstel, records, samenvatting, voortgang, krachtniveau, gewichtstrend, TDEE-calculator
2. **Voeding**: Apple Health/MyFitnessPal-sync achter `NutritionSource`, snel toevoegen, instelbare macrodoelen, adaptieve TDEE, wekelijkse check-in, gewicht en slaap uit Health (slaap telt mee in de gereedheid). Nog niet: hartslagvariabiliteit, een directe MyFitnessPal-koppeling zonder Health
3. **Coach** (deze stand): programma's met mesocyclus en deloadweek, doel en RIR per oefening per week, volume per spiergroep, deload-advies, stilstand per oefening, oefening vervangen. Nog niet: eigen programma's samenstellen per oefening, automatisch sets bijstellen op basis van gemelde RIR
4. Motivatie: uitdagingen, wekelijkse terugblik, sociale functies
5. Polish: widgets, Live Activities voor de rusttimer, Siri, CloudKit, Watch-app

De app geeft geen medisch advies.
