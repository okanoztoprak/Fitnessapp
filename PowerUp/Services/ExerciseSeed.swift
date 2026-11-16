import Foundation
import PowerCore
import SwiftData

/// Ingebouwde oefenbibliotheek. Formaat per regel:
/// slug|Engelse naam|Nederlandse naam|primaire spier|secundaire spieren|materiaal|hoofdlift
enum ExerciseSeed {
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let known = Set(existing.map(\.slug))
        for exercise in parse() where !known.contains(exercise.slug) {
            context.insert(exercise)
        }
    }

    static func parse() -> [Exercise] {
        table.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 7, let primary = MuscleGroup(rawValue: parts[3]) else { return nil }
            let secondary = parts[4].split(separator: ",").compactMap { MuscleGroup(rawValue: String($0)) }
            return Exercise(slug: parts[0], nameEN: parts[1], nameNL: parts[2], primary: primary,
                            secondary: secondary, gear: parts[5], isCardio: primary == .cardio,
                            mainLift: MainLift(rawValue: parts[6]))
        }
    }

    static let table = """
    bench-press|Bench Press|Bankdrukken|chest|triceps,shoulders|barbell|bench
    incline-bench-press|Incline Bench Press|Schuin bankdrukken|chest|shoulders,triceps|barbell|
    decline-bench-press|Decline Bench Press|Decline bankdrukken|chest|triceps|barbell|
    close-grip-bench-press|Close-Grip Bench Press|Bankdrukken smalle grip|triceps|chest|barbell|
    db-bench-press|Dumbbell Bench Press|Dumbbell bankdrukken|chest|triceps,shoulders|dumbbell|bench
    db-incline-press|Incline Dumbbell Press|Schuin dumbbell drukken|chest|shoulders,triceps|dumbbell|
    db-fly|Dumbbell Fly|Dumbbell fly|chest||dumbbell|
    cable-fly|Cable Fly|Kabel fly|chest||cable|
    machine-chest-press|Machine Chest Press|Chest press machine|chest|triceps|machine|
    pec-deck|Pec Deck|Pec deck|chest||machine|
    push-up|Push-Up|Opdrukken|chest|triceps,core|bodyweight|
    dip|Dip|Dips|chest|triceps,shoulders|bodyweight|
    deadlift|Deadlift|Deadlift|back|hamstrings,glutes|barbell|deadlift
    barbell-row|Barbell Row|Barbell row|back|biceps|barbell|row
    pendlay-row|Pendlay Row|Pendlay row|back|biceps|barbell|row
    t-bar-row|T-Bar Row|T-bar row|back|biceps|barbell|
    db-row|Dumbbell Row|Dumbbell row|back|biceps|dumbbell|row
    chest-supported-row|Chest-Supported Row|Row met borststeun|back|biceps|dumbbell|
    seated-cable-row|Seated Cable Row|Zittende kabel row|back|biceps|cable|
    machine-row|Machine Row|Row machine|back|biceps|machine|
    lat-pulldown|Lat Pulldown|Lat pulldown|back|biceps|cable|
    pull-up|Pull-Up|Optrekken|back|biceps|bodyweight|
    chin-up|Chin-Up|Chin-up|back|biceps|bodyweight|
    inverted-row|Inverted Row|Omgekeerde row|back|biceps|bodyweight|
    straight-arm-pulldown|Straight-Arm Pulldown|Pulldown gestrekte armen|back||cable|
    face-pull|Face Pull|Face pull|shoulders|back|cable|
    back-extension|Back Extension|Rugextensie|back|glutes,hamstrings|bodyweight|
    rack-pull|Rack Pull|Rack pull|back|glutes|barbell|
    overhead-press|Overhead Press|Overhead press|shoulders|triceps|barbell|overheadPress
    push-press|Push Press|Push press|shoulders|triceps,quads|barbell|
    db-shoulder-press|Dumbbell Shoulder Press|Dumbbell schouderdrukken|shoulders|triceps|dumbbell|overheadPress
    arnold-press|Arnold Press|Arnold press|shoulders|triceps|dumbbell|
    machine-shoulder-press|Machine Shoulder Press|Shoulder press machine|shoulders|triceps|machine|
    lateral-raise|Lateral Raise|Zijwaarts heffen|shoulders||dumbbell|
    cable-lateral-raise|Cable Lateral Raise|Kabel zijwaarts heffen|shoulders||cable|
    front-raise|Front Raise|Voorwaarts heffen|shoulders||dumbbell|
    rear-delt-fly|Rear Delt Fly|Reverse fly|shoulders|back|dumbbell|
    reverse-pec-deck|Reverse Pec Deck|Reverse pec deck|shoulders|back|machine|
    upright-row|Upright Row|Upright row|shoulders|biceps|barbell|
    pike-push-up|Pike Push-Up|Pike push-up|shoulders|triceps|bodyweight|
    shrug|Barbell Shrug|Shrugs|back|forearms|barbell|
    db-shrug|Dumbbell Shrug|Dumbbell shrugs|back|forearms|dumbbell|
    barbell-curl|Barbell Curl|Barbell curl|biceps|forearms|barbell|
    ez-bar-curl|EZ-Bar Curl|EZ-bar curl|biceps|forearms|barbell|
    db-curl|Dumbbell Curl|Dumbbell curl|biceps|forearms|dumbbell|
    hammer-curl|Hammer Curl|Hammer curl|biceps|forearms|dumbbell|
    incline-db-curl|Incline Dumbbell Curl|Schuine dumbbell curl|biceps||dumbbell|
    preacher-curl|Preacher Curl|Preacher curl|biceps||machine|
    cable-curl|Cable Curl|Kabel curl|biceps||cable|
    concentration-curl|Concentration Curl|Concentration curl|biceps||dumbbell|
    triceps-pushdown|Triceps Pushdown|Triceps pushdown|triceps||cable|
    rope-pushdown|Rope Pushdown|Pushdown met touw|triceps||cable|
    overhead-triceps-extension|Overhead Triceps Extension|Triceps extensie boven het hoofd|triceps||dumbbell|
    cable-overhead-extension|Cable Overhead Extension|Kabel triceps extensie|triceps||cable|
    skull-crusher|Skull Crusher|Skull crusher|triceps||barbell|
    triceps-kickback|Triceps Kickback|Triceps kickback|triceps||dumbbell|
    bench-dip|Bench Dip|Bench dip|triceps|chest|bodyweight|
    diamond-push-up|Diamond Push-Up|Diamant push-up|triceps|chest|bodyweight|
    wrist-curl|Wrist Curl|Polscurl|forearms||dumbbell|
    farmers-carry|Farmer's Carry|Farmer's walk|forearms|core,back|dumbbell|
    squat|Back Squat|Squat|quads|glutes,hamstrings|barbell|squat
    front-squat|Front Squat|Front squat|quads|glutes,core|barbell|
    goblet-squat|Goblet Squat|Goblet squat|quads|glutes|dumbbell|squat
    leg-press|Leg Press|Leg press|quads|glutes|machine|
    hack-squat|Hack Squat|Hack squat|quads|glutes|machine|
    bulgarian-split-squat|Bulgarian Split Squat|Bulgarian split squat|quads|glutes|dumbbell|
    lunge|Walking Lunge|Lunges|quads|glutes|dumbbell|
    reverse-lunge|Reverse Lunge|Achterwaartse lunge|quads|glutes|dumbbell|
    step-up|Step-Up|Step-up|quads|glutes|dumbbell|
    leg-extension|Leg Extension|Leg extension|quads||machine|
    bodyweight-squat|Bodyweight Squat|Squat zonder gewicht|quads|glutes|bodyweight|
    pistol-squat|Pistol Squat|Pistol squat|quads|glutes,core|bodyweight|
    romanian-deadlift|Romanian Deadlift|Romanian deadlift|hamstrings|glutes,back|barbell|
    db-romanian-deadlift|Dumbbell Romanian Deadlift|Dumbbell Romanian deadlift|hamstrings|glutes|dumbbell|deadlift
    stiff-leg-deadlift|Stiff-Leg Deadlift|Stiff-leg deadlift|hamstrings|glutes,back|barbell|
    good-morning|Good Morning|Good morning|hamstrings|back,glutes|barbell|
    lying-leg-curl|Lying Leg Curl|Liggende leg curl|hamstrings||machine|
    seated-leg-curl|Seated Leg Curl|Zittende leg curl|hamstrings||machine|
    nordic-curl|Nordic Curl|Nordic curl|hamstrings||bodyweight|
    hip-thrust|Hip Thrust|Hip thrust|glutes|hamstrings|barbell|
    glute-bridge|Glute Bridge|Glute bridge|glutes|hamstrings|bodyweight|
    cable-kickback|Cable Glute Kickback|Kabel kickback|glutes||cable|
    hip-abduction|Hip Abduction|Heupabductie|glutes||machine|
    sumo-deadlift|Sumo Deadlift|Sumo deadlift|glutes|hamstrings,back,quads|barbell|deadlift
    kettlebell-swing|Kettlebell Swing|Kettlebell swing|glutes|hamstrings,core|kettlebell|
    standing-calf-raise|Standing Calf Raise|Staande kuitheffing|calves||machine|
    seated-calf-raise|Seated Calf Raise|Zittende kuitheffing|calves||machine|
    db-calf-raise|Dumbbell Calf Raise|Dumbbell kuitheffing|calves||dumbbell|
    plank|Plank|Plank|core||bodyweight|
    side-plank|Side Plank|Zijplank|core||bodyweight|
    crunch|Crunch|Crunch|core||bodyweight|
    cable-crunch|Cable Crunch|Kabel crunch|core||cable|
    hanging-leg-raise|Hanging Leg Raise|Hangend beenheffen|core||bodyweight|
    lying-leg-raise|Lying Leg Raise|Liggend beenheffen|core||bodyweight|
    ab-wheel|Ab Wheel Rollout|Ab wheel|core||bodyweight|
    russian-twist|Russian Twist|Russian twist|core||bodyweight|
    dead-bug|Dead Bug|Dead bug|core||bodyweight|
    pallof-press|Pallof Press|Pallof press|core||cable|
    mountain-climber|Mountain Climber|Mountain climbers|core|cardio|bodyweight|
    running|Running|Hardlopen|cardio||cardio|
    treadmill|Treadmill|Loopband|cardio||cardio|
    cycling|Cycling|Fietsen|cardio||cardio|
    stationary-bike|Stationary Bike|Hometrainer|cardio||cardio|
    rowing-machine|Rowing Machine|Roeitrainer|cardio|back|cardio|
    elliptical|Elliptical|Crosstrainer|cardio||cardio|
    stair-climber|Stair Climber|Stairmaster|cardio|glutes|cardio|
    jump-rope|Jump Rope|Touwtjespringen|cardio|calves|cardio|
    swimming|Swimming|Zwemmen|cardio||cardio|
    walking|Walking|Wandelen|cardio||cardio|
    """
}
