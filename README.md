# POWER UP

Native iPhone-app (SwiftUI, SwiftData, iOS 18+) om training, gewicht en voeding bij te houden, in een originele anime-stijl.

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
| `Packages/PowerCore` | Pure berekeningen met unit-tests: TDEE/BMR, 1RM, gewichtstrend, PR-detectie, XP, power level, schijvencalculator |
| `PowerUp/Models` | SwiftData-modellen |
| `PowerUp/Services` | Oefenbibliotheek, startplannen, historie, XP en power level, rusttimer |
| `PowerUp/Design` | Thema, aura- en scanner-animaties, componenten |
| `PowerUp/Features` | Schermen per tab: Vandaag, Train, Voeding, Voortgang, Held, plus onboarding en instellingen |
| `scripts/make_strings.py` | Genereert de Engelse vertalingen in `PowerUp/Localizable.xcstrings` |

## Fases

1. **MVP** (deze stand): onboarding, trainingen loggen, oefenbibliotheek, rusttimer, gewicht met trend, TDEE-calculator, dashboard, power level en XP, plus een eerste versie van de aanbevelingen uit fase 3 (trainen of rusten met uitleg, schemakeuze, herstel per spiergroep met focus-training, doel per oefening via dubbele progressie)
2. Voeding: Apple Health/MyFitnessPal-sync, macrodoelen, adaptieve TDEE, wekelijkse check-in
3. Coach: programma's, progressive overload, deload, volume per spiergroep, herstelscore
4. Gamification++: transformaties, quests, boss fights, mentor, animaties
5. Polish: widgets, Live Activities, Siri, CloudKit, Watch-app

De app geeft geen medisch advies.
