import Foundation

/// Uitvoering per ingebouwde oefening: drie stappen, één tip en de meest gemaakte fout.
/// Formaat per regel: slug|stap; stap; stap|tip|fout
struct ExerciseGuide {
    let steps: [String]
    let tip: String
    let mistake: String

    static func guide(for slug: String) -> ExerciseGuide? { all[slug] }

    private static let all: [String: ExerciseGuide] = {
        var result: [String: ExerciseGuide] = [:]
        for line in table.split(separator: "\n") {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 4 else { continue }
            let steps = parts[1].split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            result[parts[0]] = ExerciseGuide(steps: steps, tip: parts[2], mistake: parts[3])
        }
        return result
    }()

    private static let table = """
    bench-press|Lig op de bank met je ogen onder de stang, voeten plat op de grond; pak de stang iets breder dan schouderbreedte, trek je schouderbladen naar achteren en omlaag; laat de stang gecontroleerd zakken naar je onderborst en druk hem recht omhoog terug|Houd je billen op de bank en je polsen recht boven je ellebogen.|Ellebogen helemaal naar buiten (90°) laten wijzen; dat belast je schouders.
    incline-bench-press|Zet de bank op 30 tot 45 graden en lig met je ogen onder de stang; pak de stang iets breder dan schouderbreedte, schouderbladen naar achteren; laat de stang zakken naar je bovenborst en druk recht omhoog|Een lagere hoek (30°) houdt de nadruk op je borst in plaats van je schouders.|De bank te steil zetten, waardoor het een schouderdruk wordt.
    decline-bench-press|Haak je voeten achter de steunen en lig op de schuine bank; pak de stang op schouderbreedte en til hem uit het rek; laat hem zakken naar je onderborst en druk terug|Laat je spotter de stang aangeven; uitrekken vanuit deze hoek is lastig.|De stang naar je nek laten zakken in plaats van je onderborst.
    close-grip-bench-press|Lig op de bank en pak de stang op schouderbreedte; houd je ellebogen dicht langs je lichaam; laat de stang zakken naar je onderborst en druk uit met je triceps|Schouderbreedte is smal genoeg; nog smaller belast je polsen.|Handen vlak naast elkaar zetten.
    db-bench-press|Ga liggen met een dumbbell op elke dij en kantel ze op je borst; druk de dumbbells omhoog tot je armen gestrekt zijn; laat ze gecontroleerd zakken tot naast je borst|Laat de dumbbells bovenin licht naar elkaar toe bewegen, zonder te tikken.|Te ver zakken waardoor je schouders naar voren rollen.
    db-incline-press|Zet de bank op 30 tot 45 graden met een dumbbell in elke hand; druk de dumbbells boven je bovenborst omhoog; laat ze zakken tot je een rek in je borst voelt|Houd je onderarmen verticaal tijdens de hele beweging.|Je onderrug hol trekken om meer gewicht te drukken.
    db-fly|Lig op de bank met de dumbbells boven je borst, handpalmen naar elkaar; open je armen in een wijde boog met licht gebogen ellebogen; breng ze in dezelfde boog terug alsof je een boom omarmt|Kies een licht gewicht; het gaat om de rek, niet om het gewicht.|De ellebogen buigen en strekken, waardoor het een drukoefening wordt.
    cable-fly|Zet de kabels op schouderhoogte en stap een pas naar voren; breng je handen in een boog naar elkaar voor je borst; laat ze gecontroleerd terug naar buiten gaan tot je een rek voelt|Houd een kleine buiging in je ellebogen die niet verandert.|Met je lichaam meebewegen in plaats van alleen je armen.
    machine-chest-press|Stel de stoel zo af dat de handgrepen op borsthoogte zitten; druk de grepen naar voren tot je armen bijna gestrekt zijn; laat ze rustig terugkomen tot je een rek in je borst voelt|Houd je schouderbladen tegen de rugleuning.|Je ellebogen bovenin op slot zetten met een klap.
    pec-deck|Stel de stoel zo af dat je armen op schouderhoogte zitten; breng de armen of handgrepen voor je borst samen; laat ze gecontroleerd terug naar buiten gaan|Knijp een tel samen in het midden.|Je schouders naar voren laten komen.
    push-up|Zet je handen iets breder dan schouderbreedte, lichaam in een rechte lijn; zak tot je borst net boven de grond is; duw jezelf weer omhoog|Span je billen en buik aan, dan blijft je lichaam een plank.|Doorzakkende heupen of je billen in de lucht.
    dip|Steun op de stangen met gestrekte armen; zak tot je bovenarmen ongeveer horizontaal zijn, iets voorovergeleund; duw jezelf weer omhoog|Leun voorover voor borst, blijf rechtop voor triceps.|Te diep zakken zodat je schouders naar voren rollen.
    deadlift|Sta met je middenvoet onder de stang, pak hem net buiten je benen; zet je rug recht, borst omhoog, en duw de vloer weg met je benen; strek heupen en knieën tegelijk tot je rechtop staat|Houd de stang de hele tijd tegen je benen.|Met een bolle onderrug tillen.
    barbell-row|Pak de stang op schouderbreedte en buig voorover tot je romp bijna horizontaal is; trek de stang naar je onderbuik; laat hem gecontroleerd zakken|Trek met je ellebogen, niet met je handen.|Rechtop komen en het gewicht omhoog zwaaien.
    pendlay-row|Buig voorover met een horizontale romp, de stang op de grond; trek de stang explosief naar je onderborst; zet hem elke herhaling terug op de grond|Elke herhaling begint stil vanaf de vloer.|Je romp omhoog laten komen tijdens het trekken.
    t-bar-row|Ga over de stang staan en buig voorover met een rechte rug; trek het handvat naar je borst; laat het gecontroleerd zakken|Houd je borst omhoog en je nek in lijn met je rug.|Met je onderrug rukken om het gewicht te bewegen.
    db-row|Zet een knie en hand op de bank, dumbbell in je andere hand; trek de dumbbell naar je heup; laat hem zakken tot je arm gestrekt is|Trek richting je heup, niet recht omhoog naar je schouder.|Je romp draaien om het gewicht omhoog te krijgen.
    chest-supported-row|Lig met je borst op een schuine bank, dumbbells hangend; trek de dumbbells naar je zij; laat ze rustig zakken|Je onderrug rust, dus alle kracht komt uit je rug.|Je borst van de bank tillen.
    seated-cable-row|Zit rechtop met licht gebogen knieën en pak het handvat; trek het handvat naar je buik en knijp je schouderbladen samen; laat het gecontroleerd terug naar voren gaan|Laat je schouders naar voren rekken voor een volledige beweging.|Met je romp naar achteren leunen om te trekken.
    machine-row|Stel de borststeun zo af dat je de grepen net kunt pakken; trek de grepen naar je toe; laat ze gecontroleerd terugkomen|Denk aan je ellebogen naar achteren brengen.|Je borst van de steun halen.
    lat-pulldown|Zet je knieën onder de steun en pak de stang breder dan schouderbreedte; trek de stang naar je bovenborst; laat hem gecontroleerd omhoog gaan tot je armen gestrekt zijn|Leun een klein beetje achterover en trek je ellebogen naar je zij.|De stang achter je nek trekken.
    pull-up|Hang aan de stang met je handpalmen van je af, iets breder dan schouderbreedte; trek jezelf omhoog tot je kin boven de stang is; zak gecontroleerd tot je armen gestrekt zijn|Lukt het nog niet, gebruik een elastiek of doe alleen het zakken.|Halve herhalingen zonder volledig te strekken.
    chin-up|Hang aan de stang met je handpalmen naar je toe op schouderbreedte; trek jezelf omhoog tot je kin boven de stang is; zak gecontroleerd terug|Houd je benen stil; slingeren haalt het werk weg.|Zwaaien met je benen om omhoog te komen.
    inverted-row|Hang onder een stang of ringen met gestrekte armen en je lichaam recht; trek je borst naar de stang; zak gecontroleerd terug|Hoe horizontaler je lichaam, hoe zwaarder.|Je heupen laten doorzakken.
    straight-arm-pulldown|Sta voor de kabel en pak de stang met gestrekte armen; duw de stang in een boog naar je dijen; laat hem gecontroleerd terug omhoog gaan|Houd je armen bijna gestrekt; het werk komt uit je lats.|De ellebogen buigen waardoor het een triceps-oefening wordt.
    face-pull|Zet de kabel op ooghoogte met een touw; trek het touw naar je gezicht en trek de uiteinden uit elkaar; laat het gecontroleerd terug gaan|Eindig met je handen naast je oren, duimen naar achteren.|Te zwaar gewicht waardoor je met je rug trekt.
    back-extension|Zet je heupen op het kussen en kruis je armen; zak met een rechte rug naar beneden; kom omhoog tot je lichaam een rechte lijn is|Knijp je billen aan bovenin.|Verder doorbuigen dan een rechte lijn.
    rack-pull|Zet de stang op kniehoogte in het rek; pak hem vast met een rechte rug; strek je heupen tot je rechtop staat|Goed om je lockout te trainen met zwaarder gewicht.|Je schouders naar achteren laten hangen bovenin.
    overhead-press|Sta met de stang op je voorste schouders, handen net buiten je schouders; druk de stang recht omhoog en breng je hoofd naar voren onder de stang; laat hem gecontroleerd terug naar je schouders zakken|Span je billen en buik aan om niet achterover te hellen.|Ver achterover leunen waardoor het een schuine bankdruk wordt.
    push-press|Begin zoals bij de overhead press; zak een klein stukje door je knieën; strek explosief je benen en druk de stang omhoog|De benen geven de start, de armen maken het af.|Te diep doorzakken zoals bij een squat.
    db-shoulder-press|Zit of sta met de dumbbells op schouderhoogte; druk ze omhoog tot je armen gestrekt zijn; laat ze gecontroleerd terug zakken|Houd je onderarmen verticaal.|Je onderrug hol trekken.
    arnold-press|Begin met de dumbbells voor je gezicht, handpalmen naar je toe; draai je handen naar buiten terwijl je omhoog drukt; draai terug tijdens het zakken|Beweeg rustig; de draai maakt het zwaarder dan je denkt.|Te zwaar beginnen en de draai overslaan.
    machine-shoulder-press|Stel de stoel zo af dat de grepen op schouderhoogte zitten; druk de grepen omhoog; laat ze gecontroleerd terugkomen|Houd je rug tegen de leuning.|Bovenin met een klap op slot gaan.
    lateral-raise|Sta met een dumbbell in elke hand langs je zij; til je armen zijwaarts tot schouderhoogte met licht gebogen ellebogen; laat ze langzaam zakken|Denk aan je ellebogen omhoog brengen, niet je handen.|Zwaaien met je lichaam om het gewicht omhoog te krijgen.
    cable-lateral-raise|Sta zijwaarts naast de kabel en pak het handvat met de verste hand; til je arm zijwaarts tot schouderhoogte; laat hem langzaam terug zakken|De kabel geeft spanning onderin, waar dumbbells dat niet doen.|Je schouder optrekken naar je oor.
    front-raise|Sta met de dumbbells voor je dijen; til je armen recht vooruit tot schouderhoogte; laat ze langzaam zakken|Licht gewicht volstaat; je voorste schouders werken al veel bij drukoefeningen.|Achterover leunen om het gewicht omhoog te zwaaien.
    rear-delt-fly|Buig voorover met een rechte rug en de dumbbells hangend; til je armen zijwaarts in een boog; laat ze langzaam zakken|Houd je pinken iets hoger dan je duimen.|Je schouderbladen samenknijpen in plaats van je achterste schouder te gebruiken.
    reverse-pec-deck|Zit met je borst tegen het kussen en pak de grepen; breng je armen in een boog naar achteren; laat ze gecontroleerd terugkomen|Houd je armen bijna gestrekt.|Te zwaar gewicht waardoor je met je rug trekt.
    upright-row|Pak de stang met een grip iets breder dan schouderbreedte; trek de stang langs je lichaam omhoog tot borsthoogte; laat hem langzaam zakken|Een bredere grip spaart je schouders.|Te hoog trekken met een smalle grip.
    pike-push-up|Zet je handen en voeten op de grond met je heupen hoog; zak met je hoofd richting de grond tussen je handen; druk jezelf weer omhoog|Zet je voeten op een verhoging om het zwaarder te maken.|Je heupen laten zakken waardoor het een gewone push-up wordt.
    shrug|Sta met de stang voor je dijen; trek je schouders recht omhoog naar je oren; laat ze langzaam zakken|Houd bovenin een tel vast.|Je schouders rondjes laten draaien.
    db-shrug|Sta met een dumbbell in elke hand langs je zij; trek je schouders recht omhoog; laat ze langzaam zakken|Dumbbells laten je armen vrij langs je lichaam hangen.|Met je armen trekken in plaats van je schouders.
    barbell-curl|Sta met de stang op schouderbreedte, handpalmen naar voren; buig je ellebogen en krul de stang omhoog; laat hem langzaam zakken|Houd je ellebogen vast langs je zij.|Met je rug zwaaien om de stang omhoog te krijgen.
    ez-bar-curl|Pak de EZ-stang op de schuine delen; krul de stang omhoog; laat hem langzaam zakken|De schuine grip is prettiger voor je polsen.|Je ellebogen naar voren laten komen bovenin.
    db-curl|Sta met de dumbbells langs je zij, handpalmen naar voren; krul de dumbbells omhoog; laat ze langzaam zakken|Draai je pink iets omhoog bovenin voor extra spanning.|Zwaaien met je bovenlichaam.
    hammer-curl|Sta met de dumbbells langs je zij, handpalmen naar elkaar; krul ze omhoog zonder je handen te draaien; laat ze langzaam zakken|Traint ook je onderarmen.|Je ellebogen naar voren laten komen.
    incline-db-curl|Zit op een schuine bank met de armen naar beneden hangend; krul de dumbbells omhoog; laat ze helemaal zakken|De hangende armen geven een grote rek op je biceps.|Je schouders naar voren laten komen.
    preacher-curl|Leg je bovenarmen op het kussen; krul de stang of grepen omhoog; laat ze langzaam zakken tot je armen bijna gestrekt zijn|Onderin langzaam; daar is je biceps het kwetsbaarst.|Onderin je ellebogen met een klap strekken.
    cable-curl|Sta voor de kabel met de stang laag; krul de stang omhoog; laat hem langzaam zakken|De kabel houdt spanning door de hele beweging.|Achterover leunen.
    concentration-curl|Zit met je elleboog tegen de binnenkant van je dij; krul de dumbbell omhoog; laat hem langzaam zakken|Volledige focus op één arm tegelijk.|Je bovenarm van je dij laten komen.
    triceps-pushdown|Sta voor de kabel met de stang op borsthoogte; druk de stang omlaag tot je armen gestrekt zijn; laat hem gecontroleerd omhoog gaan|Houd je ellebogen vast langs je zij.|Je ellebogen naar voren laten komen.
    rope-pushdown|Pak het touw met de duimen boven; druk het omlaag en trek de uiteinden onderin uit elkaar; laat het gecontroleerd terug gaan|Het uit elkaar trekken onderin geeft extra spanning.|Met je schouders meedrukken.
    overhead-triceps-extension|Houd een dumbbell met beide handen boven je hoofd; laat hem achter je hoofd zakken door je ellebogen te buigen; strek je armen weer|Houd je ellebogen naar voren gericht.|Je ellebogen ver naar buiten laten wijzen.
    cable-overhead-extension|Sta met je rug naar de kabel, touw achter je hoofd; strek je armen naar voren en omhoog; laat het touw gecontroleerd terugkomen|De rek achter je hoofd traint de lange kop van je triceps.|Je onderrug hol trekken.
    skull-crusher|Lig op de bank met de stang boven je borst; laat de stang zakken naar je voorhoofd door je ellebogen te buigen; strek je armen weer|Laat de stang iets achter je hoofd zakken voor meer rek.|Je ellebogen naar buiten laten wijzen.
    triceps-kickback|Buig voorover met je bovenarm langs je zij; strek je arm naar achteren; laat hem gecontroleerd terug buigen|Je bovenarm blijft stil.|Zwaaien met je bovenarm.
    bench-dip|Zet je handen op een bank achter je, benen gestrekt; zak tot je ellebogen ongeveer 90 graden zijn; druk jezelf weer omhoog|Buig je knieën om het lichter te maken.|Te diep zakken zodat je schouders gaan klemmen.
    diamond-push-up|Zet je handen dicht bij elkaar onder je borst; zak tot je borst je handen bijna raakt; duw jezelf weer omhoog|Houd je ellebogen dicht bij je lichaam.|Doorzakkende heupen.
    wrist-curl|Leg je onderarmen op je dijen met de dumbbells in je handen; krul je polsen omhoog; laat ze langzaam zakken|Kleine beweging, hoge herhalingen.|Te zwaar gewicht waardoor je met je armen meetrekt.
    farmers-carry|Pak een zware dumbbell in elke hand; loop rechtop met korte, stevige passen; zet ze gecontroleerd neer|Schouders omlaag en naar achteren, borst omhoog.|Voorover leunen of je schouders laten hangen.
    squat|Zet de stang op je bovenrug en sta op schouderbreedte, tenen licht naar buiten; zak door je heupen en knieën tot je dijen minstens horizontaal zijn; duw jezelf recht omhoog|Druk je knieën in de richting van je tenen.|Je knieën naar binnen laten vallen.
    front-squat|Leg de stang op je voorste schouders met je ellebogen hoog; zak rechtop tot je dijen horizontaal zijn; duw jezelf omhoog|Houd je ellebogen omhoog; dan blijft je romp rechtop.|Je ellebogen laten zakken waardoor de stang naar voren rolt.
    goblet-squat|Houd een dumbbell tegen je borst; zak tussen je knieën door tot je dijen horizontaal zijn; duw jezelf omhoog|Ideaal om de squat te leren.|Op je tenen gaan staan.
    leg-press|Zet je voeten op schouderbreedte midden op het platform; laat het platform zakken tot je knieën ongeveer 90 graden zijn; druk het weer weg zonder je knieën op slot te zetten|Hogere voeten trainen meer billen en hamstrings.|Je onderrug van het kussen laten komen onderin.
    hack-squat|Zet je rug tegen het kussen en je voeten op schouderbreedte; zak tot je dijen horizontaal zijn; duw jezelf omhoog|Houd je hele voet op het platform.|Je hielen van het platform tillen.
    bulgarian-split-squat|Zet je achterste voet op een bank, voorste voet een grote pas naar voren; zak tot je voorste dij horizontaal is; duw jezelf omhoog via je voorste been|Iets voorover leunen legt meer nadruk op je billen.|Je voorste knie naar binnen laten vallen.
    lunge|Stap een grote pas naar voren; zak tot je achterste knie bijna de grond raakt; duw jezelf omhoog en stap door met je andere been|Houd je romp rechtop en je passen even lang.|Te kleine passen waardoor je knie ver over je tenen gaat.
    reverse-lunge|Stap een grote pas naar achteren; zak tot je achterste knie bijna de grond raakt; duw jezelf terug naar de start via je voorste been|Prettiger voor je knieën dan een lunge naar voren.|Je gewicht op je achterste been leggen.
    step-up|Zet een voet op een bank of kist; duw jezelf omhoog via dat been; stap gecontroleerd terug|Duw af met je hiel van het bovenste been.|Afzetten met je onderste been.
    leg-extension|Stel de machine zo af dat je knie bij het draaipunt zit; strek je benen tot ze bijna gestrekt zijn; laat ze langzaam zakken|Houd een tel vast bovenin.|Het gewicht omhoog zwaaien.
    bodyweight-squat|Sta op schouderbreedte met je armen naar voren; zak tot je dijen horizontaal zijn; duw jezelf omhoog|Goed als warming-up of om techniek te oefenen.|Je hielen van de grond laten komen.
    pistol-squat|Sta op één been met het andere been gestrekt naar voren; zak gecontroleerd zo diep als je kunt; duw jezelf weer omhoog|Oefen eerst naar een bank of met een steun.|Je knie naar binnen laten vallen.
    romanian-deadlift|Sta met de stang voor je dijen en licht gebogen knieën; duw je heupen naar achteren en laat de stang langs je benen zakken; kom omhoog door je heupen naar voren te duwen|Zak tot je een flinke rek in je hamstrings voelt, met een rechte rug.|Je knieën ver buigen waardoor het een squat wordt.
    db-romanian-deadlift|Sta met de dumbbells voor je dijen; duw je heupen naar achteren en laat de dumbbells langs je benen zakken; kom omhoog door je heupen naar voren te duwen|Houd de dumbbells dicht bij je benen.|Met een bolle rug zakken.
    stiff-leg-deadlift|Sta met de stang voor je dijen en bijna gestrekte benen; buig voorover vanuit je heupen; kom terug omhoog|Ga alleen zo ver als je rug recht blijft.|Je rug rond maken om lager te komen.
    good-morning|Zet de stang op je bovenrug zoals bij de squat; buig voorover vanuit je heupen met licht gebogen knieën; kom terug omhoog|Begin licht; deze oefening is zwaarder dan je denkt.|Met een bolle rug voorover buigen.
    lying-leg-curl|Lig op je buik met het kussen net boven je hielen; krul je benen naar je billen; laat ze langzaam zakken|Houd je heupen op het kussen.|Je heupen omhoog laten komen.
    seated-leg-curl|Zit met het kussen net boven je hielen en de bovenste steun op je dijen; krul je benen naar beneden en achteren; laat ze langzaam terug gaan|Zittend geeft een betere rek op je hamstrings.|Te snel terug laten komen.
    nordic-curl|Kniel met je enkels vast; laat je lichaam zo langzaam mogelijk naar voren zakken; vang jezelf op met je handen en duw terug|Begin met alleen het zakken; dat is al zwaar genoeg.|In je heupen knikken in plaats van recht te blijven.
    hip-thrust|Zit met je bovenrug tegen een bank en de stang op je heupen; duw je heupen omhoog tot je lichaam een rechte lijn is; laat ze gecontroleerd zakken|Kijk naar voren en knijp je billen aan bovenin.|Je onderrug hol trekken in plaats van je heupen te strekken.
    glute-bridge|Lig op je rug met gebogen knieën en voeten plat; duw je heupen omhoog; laat ze gecontroleerd zakken|Duw door je hielen.|Je onderrug hol trekken bovenin.
    cable-kickback|Zet een enkelband aan de kabel en sta voorover leunend; duw je been naar achteren; laat het gecontroleerd terug komen|Houd je romp stil.|Je onderrug hol trekken om verder te komen.
    hip-abduction|Zit in de machine met de kussens aan de buitenkant van je knieën; duw je benen uit elkaar; laat ze langzaam terug komen|Iets voorover leunen traint meer van je billen.|Het gewicht laten terugklappen.
    sumo-deadlift|Sta breed met je tenen naar buiten en pak de stang tussen je benen; duw je knieën naar buiten en houd je rug recht; duw de vloer weg tot je rechtop staat|Houd je heupen dicht bij de stang.|Je heupen te vroeg laten omhoog schieten.
    kettlebell-swing|Sta breed met de kettlebell voor je; zwaai hem tussen je benen door met een rechte rug; duw je heupen explosief naar voren zodat hij tot borsthoogte zwaait|De kracht komt uit je heupen, niet uit je armen.|Squatten in plaats van je heupen naar achteren te duwen.
    standing-calf-raise|Sta met de bal van je voet op de rand; kom zo hoog mogelijk op je tenen; zak langzaam tot onder de rand|Houd een tel vast bovenin en onderin.|Snel op en neer veren.
    seated-calf-raise|Zit met het kussen op je dijen en de bal van je voet op de rand; duw je hielen omhoog; zak langzaam terug|Zittend traint vooral je diepere kuitspier.|Te kleine beweging maken.
    db-calf-raise|Sta met een dumbbell in je hand op de rand van een trede; kom zo hoog mogelijk op je tenen; zak langzaam terug|Houd je vast met je andere hand voor balans.|Met je knieën meebuigen.
    plank|Steun op je onderarmen en tenen; houd je lichaam in een rechte lijn; adem rustig door|Span je billen aan en duw je ellebogen richting je tenen.|Je heupen laten zakken.
    side-plank|Lig op je zij en steun op een onderarm; til je heupen op tot je lichaam recht is; houd vast|Voeten op elkaar of voor elkaar voor meer balans.|Je heupen naar achteren laten zakken.
    crunch|Lig op je rug met gebogen knieën; rol je schouders van de grond richting je bekken; zak langzaam terug|Denk aan je ribben naar je heupen brengen.|Aan je nek trekken met je handen.
    cable-crunch|Kniel voor de kabel met het touw naast je hoofd; rol je romp naar beneden richting je knieën; kom langzaam terug|Je heupen blijven stil; alleen je romp rolt.|Met je heupen naar achteren zitten.
    hanging-leg-raise|Hang aan een stang met gestrekte armen; til je benen omhoog tot heuphoogte of hoger; laat ze langzaam zakken|Kantel je bekken bovenin naar je toe.|Slingeren om je benen omhoog te krijgen.
    lying-leg-raise|Lig op je rug met je handen onder je billen; til je gestrekte benen omhoog tot verticaal; laat ze langzaam zakken zonder de grond te raken|Houd je onderrug tegen de grond.|Je onderrug hol laten komen.
    ab-wheel|Kniel met het wiel voor je; rol langzaam naar voren met een rechte rug; trek jezelf terug met je buik|Begin met een korte afstand.|Je heupen laten doorzakken.
    russian-twist|Zit met je knieën gebogen en leun iets achterover; draai je romp naar links en rechts; houd je rug recht|Til je voeten op om het zwaarder te maken.|Alleen je armen bewegen in plaats van je romp.
    dead-bug|Lig op je rug met je armen omhoog en knieën boven je heupen; strek tegelijk je ene arm en andere been; kom terug en wissel|Houd je onderrug tegen de grond.|Te snel bewegen.
    pallof-press|Sta zijwaarts naast de kabel met het handvat tegen je borst; druk het handvat recht vooruit; breng het terug zonder te draaien|Het gaat om niet draaien; houd je romp stil.|Met je lichaam meedraaien richting de kabel.
    mountain-climber|Begin in een push-uphouding; trek afwisselend je knieën naar je borst; houd een stevig tempo|Houd je heupen laag.|Je billen omhoog steken.
    running|Begin rustig om op te warmen; loop met korte, snelle passen en ontspannen schouders; bouw rustig af|De meeste looptrainingen horen op een tempo waarop je nog kunt praten.|Te snel beginnen.
    treadmill|Begin met een paar minuten wandelen; voer de snelheid op tot je trainingstempo; bouw aan het eind af|Zet de helling op 1% voor een buitengevoel.|Je vasthouden aan de handgrepen.
    cycling|Stel je zadel zo af dat je knie licht gebogen is onderin; trap in een rustig, rond ritme; bouw de weerstand op|Een hoge cadans (80 tot 90) spaart je knieën.|Het zadel te laag zetten.
    stationary-bike|Stel het zadel op heuphoogte als je ernaast staat; trap rustig in om op te warmen; verhoog de weerstand voor je intervallen|Houd je bovenlichaam ontspannen.|Te zware weerstand met een lage cadans.
    rowing-machine|Begin met gestrekte armen en gebogen knieën; duw eerst met je benen, leun dan iets achterover en trek met je armen; keer in omgekeerde volgorde terug|Benen, romp, armen; en terug: armen, romp, benen.|Alleen met je armen trekken.
    elliptical|Stap op en pak de handgrepen; beweeg in een rustig, rond ritme; verhoog de weerstand als het te makkelijk wordt|Duw ook actief met je armen voor meer werk.|Op je tenen staan.
    stair-climber|Stap op en houd je licht vast; stap in een rustig tempo met je hele voet; bouw het tempo op|Laat je handgrepen los als je balans goed is.|Zwaar op de handgrepen leunen.
    jump-rope|Houd je ellebogen dicht bij je lichaam; draai het touw vanuit je polsen; spring laag op de bal van je voet|Kleine sprongetjes zijn genoeg.|Te hoog springen.
    swimming|Warm in met een paar rustige baantjes; zwem in een gelijkmatig tempo; adem regelmatig|Wissel slagen af om verschillende spieren te trainen.|Je adem inhouden.
    walking|Loop rechtop met ontspannen schouders; zwaai je armen mee; houd een tempo waarop je nog kunt praten|Elke stap telt mee voor je dagdoel.|Te langzaam lopen om er energie in te krijgen.
    """
}
