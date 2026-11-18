# POWER UP

Native iPhone-app (SwiftUI, SwiftData, iOS 18+) om krachttraining, gewicht en voeding bij te houden. Modern en donker van opzet, met één felle accentkleur, en gebouwd rond drie vragen: hoeveel beweeg ik vandaag, wat train ik vandaag, en word ik sterker?

## Wat de app doet

| Onderdeel | Wat het is | Geïnspireerd door |
|---|---|---|
| Stappen | Stappen van vandaag tegen je eigen doel, de afgelopen week als grafiek, dagen op rij op doel | Apple Fitness, Fitbit |
| Slimme training | Workout uit de spiergroepen die het best hersteld zijn (herstel rekent op de achtergrond mee) | Fitbod |
| Aanbeveling | Trainen of rusten, met uitleg en de schemadag die aan de beurt is | Fitbod, Alpha Progression |
| Logscherm | Kolom "Vorige" (tik om over te nemen), live duur/volume/sets, zwevende rusttimer | Strong, Hevy |
| Doel per oefening | Dubbele progressie: eerst reps, dan gewicht | Alpha Progression |
| Records | Melding met confetti bij een nieuw record, vanaf de tweede sessie | Hevy, Strong |
| Samenvatting | Na afloop: cijfers, records, vergelijking, deelbare kaart | Hevy |
| Voortgang | Consistentieraster, gewichtstrend (EMA), volume per week, spierbalans | MacroFactor, Hevy |
| Voeding | Wat je vandaag nog kunt eten, macro's per dag, week in één grafiek, snel toevoegen | MacroFactor, MyFitnessPal |
| Adaptief verbruik | Verbruik uit inname en trendgewicht, met zekerheid; tikfouten in het gewicht tellen niet mee | MacroFactor |
| Wekelijkse check-in | Nieuw caloriedoel op basis van je echte verbruik, in kleine stappen en nooit onder je rustverbranding | MacroFactor |
| Apple Health | Voeding (ook uit MyFitnessPal), weegschaal, slaap en stappen | WHOOP, MacroFactor |
| Profiel | Krachtniveau per lift ten opzichte van lichaamsgewicht, mijlpalen | Strength Level, Hevy |
| Programma's | Blok van 4–6 weken: elke week dichter bij falen (RIR 3 → 1) en voor spiermassa meer sets, met een deloadweek aan het eind | RP Hypertrophy, Alpha Progression |
| Volume per spiergroep | Harde sets deze week tegen een streefbereik dat met het blok meegroeit | RP Hypertrophy |
| Coach | Deload-advies bij stilstand, hoge belasting of lange reeks; melding als een oefening stilstaat | Fitbod, Alpha Progression |
| Oefening vervangen | Alternatief voor dezelfde spiergroep met je materiaal, zonder van hoofdlift te wisselen | Fitbod, Hevy |
| Weekoverzicht | Elke maandag een score voor de vorige week (training, voeding, wegen), hoogtepunten, één focuspunt en een deelbare kaart | WHOOP, MacroFactor |
| Uitdagingen | Drie weekdoelen en een maanddoel die passen bij je eigen schema, met badges; nooit meer trainingen dan gepland | Apple Fitness, Strava |
| Herinneringen | Trainingsherinnering op gekozen dagen en tijd, en een melding als het weekoverzicht klaarstaat; alles lokaal | Strong, Fitbod |
| Widgets | Stappen (beginscherm en toegangsscherm) en Vandaag: stappen, volgende training en reeks | Apple Fitness, Gentler Streak |
| Rusttimer als Live Activity | Aftellen met voortgangsbalk op het toegangsscherm en in het Dynamic Island | Strong, Hevy |
| Siri en Opdrachten | "Start een training in POWER UP" en "Hoeveel stappen heb ik in POWER UP" | Streaks |

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

In testversies staat onder Voeding → Apple Health een knop die drie weken voorbeeldvoeding, -gewicht en -slaap in Health zet, en op Vandaag (zolang er geen stappen zijn) een knop voor een week voorbeeldstappen.

### Op je eigen iPhone

1. Xcode → Settings → Accounts: voeg je Apple ID toe. Een gratis account werkt; de app verloopt dan na 7 dagen en installeer je opnieuw vanuit Xcode.
2. Zoek je team-ID op (10 tekens, in Accounts bij je team) en kies een eigen bundle-ID, bijvoorbeeld `nl.jouwnaam.powerup`.
3. Draai `scripts/setup_iphone.sh TEAM_ID nl.jouwnaam.powerup`. Dat schrijft `Config/Signing.local.xcconfig` (niet in git) en genereert het project; widget-ID en app-group volgen automatisch.
4. Sluit je iPhone aan, tik op Vertrouw en zet Ontwikkelaarsmodus aan (Instellingen → Privacy en beveiliging).
5. Open `PowerUp.xcodeproj`, kies je iPhone en druk op Run. Eerste keer: vertrouw je profiel onder Instellingen → Algemeen → VPN en apparaatbeheer.

Tests van de rekenlaag:

```sh
swift test --package-path Packages/PowerCore
```

## Structuur

| Pad | Inhoud |
|---|---|
| `Packages/PowerCore` | Pure berekeningen met unit-tests: mesocyclus, volumedoelen, stilstand en deload, TDEE/BMR, macro's, adaptief verbruik, wekelijkse check-in, slaap, 1RM, gewichtstrend, PR-detectie, progressie, trainen-of-rusten, spierherstel, gereedheid, belasting, weekreeks, krachtniveau, schijvencalculator, weekscore, uitdagingen, stappen |
| `PowerUp/Models` | SwiftData-modellen |
| `PowerUp/Services` | Oefenbibliotheek, startschema's, historie, aanbevelingen (`Coach`), programma's en volume (`ProgramCoach`), statistieken (`Insights`), voedingsplan en sync (`NutritionPlan`, `HealthSync`), weekoverzicht en uitdagingen (`MotivationService`), meldingen (`ReminderService`), rusttimer |
| `PowerUp/Services/Health` | `NutritionSource`-protocol en de Apple Health-koppeling |
| `PowerUp/Design` | Thema en gedeelde componenten (ringen, kaarten, knoppen, confetti) |
| `Widgets` | Widget-extensie: stappen- en Vandaag-widget en de Live Activity van de rusttimer |
| `Brand` | App-icoon (`make_icon.swift` tekent het opnieuw) en de huisstijlpagina |
| `Config` | Ondertekening: standaard-bundle-ID voor simulator en CI, met een lokaal bestand voor je eigen team |
| `Shared` | Code die app en widgets delen: de gegevens voor de widgets (via de app-group) en de Live Activity |
| `PowerUp/Features` | Schermen per tab: Vandaag, Training, Voortgang, Voeding, Profiel, plus motivatie (weekoverzicht, uitdagingen), onboarding en instellingen |
| `scripts/make_strings.py` | Genereert de Engelse vertalingen in `PowerUp/Localizable.xcstrings`, `PowerUp/InfoPlist.xcstrings` en `Widgets/Localizable.xcstrings` |

## Fases

1. **MVP**: onboarding, trainingen loggen, oefenbibliotheek, aanbevelingen, gereedheid en herstel, records, samenvatting, voortgang, krachtniveau, gewichtstrend, TDEE-calculator
2. **Voeding**: Apple Health/MyFitnessPal-sync achter `NutritionSource`, snel toevoegen, instelbare macrodoelen, adaptieve TDEE, wekelijkse check-in, gewicht en slaap uit Health (slaap telt mee in de gereedheid). Nog niet: hartslagvariabiliteit, een directe MyFitnessPal-koppeling zonder Health
3. **Coach**: programma's met mesocyclus en deloadweek, doel en RIR per oefening per week, volume per spiergroep, deload-advies, stilstand per oefening, oefening vervangen. Nog niet: eigen programma's samenstellen per oefening, automatisch sets bijstellen op basis van gemelde RIR
4. **Motivatie**: weekoverzicht met score, hoogtepunten en focus, deelbare weekkaart, week- en maanduitdagingen met badges, lokale herinneringen, stappen met eigen stappendoel. De gereedheidskaart op Vandaag en het herstelraster op Training zijn vervangen door stappen; herstel stuurt alleen nog de slimme training. Nog niet: een sociale feed met vrienden, want die vraagt een server en accounts
5. **Polish** (deze stand): stappen- en Vandaag-widget, rusttimer als Live Activity met Dynamic Island, Siri-opdrachten. Nog niet: CloudKit-sync (vraagt een betaald developer-account en iCloud-container), een Watch-app, Engelse Siri-zinnen

De app geeft geen medisch advies.
