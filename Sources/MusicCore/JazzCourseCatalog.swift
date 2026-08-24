import Foundation

public enum JazzCourseCatalog {
    public static let course = PracticeCourse(
        id: "jazz-piano",
        title: "Jazz Course",
        summary: "A guided path from keyboard fundamentals to modern jazz harmony, voicing, improvisation, and comping.",
        stages: [beginner, intermediate, advanced]
    )

    public static let beginner = CourseStage(level: .beginner, modules: [
        module("beginner-notes", "Notes, Intervals & Triads", "Train the ear and hand with the smallest building blocks of harmony.", [
            lesson("b-step-skip", "Step and Skip", "Recognize whole-step and larger melodic distances.", "Play slowly and name each distance from the previous note.", [1], [60, 62, 64, 65, 67, 64]),
            chordLesson("b-major-minor", "Major and Minor Color", "Hear the difference between major and minor triads.", "Press and hold each three-note chord together; release fully before changing quality.", [1], [[60, 64, 67], [60, 63, 67]]),
            chordLesson("b-inversions", "First Inversions", "Reorganize the notes of a triad without changing its identity.", "Play each three-note inversion together and keep common tones physically close.", [1], [[60, 64, 67], [64, 67, 72], [67, 72, 76]]),
        ]),
        module("beginner-major-map", "The Major-Key Map", "Connect scales, diatonic harmony, and the essential jazz cadence.", [
            lesson("b-c-major", "C Major Journey", "Play and hear all seven notes of a major scale.", "Use even timing and listen for the leading tone pulling toward the final tonic.", [2, 11], [60, 62, 64, 65, 67, 69, 71, 72]),
            chordLesson("b-diatonic-thirds", "Diatonic Thirds", "Discover harmony by pairing notes from the major scale.", "Press each dyad together, release it, then move to the next pair.", [2], [[60, 64], [62, 65], [64, 67], [65, 69]]),
            chordLesson("b-first-251", "First II–V–I", "Follow roots and defining chord tones through a basic jazz cadence.", "Play each two-note shell simultaneously and listen for the cadence resolving.", [2, 3], [[50, 53], [55, 59], [48, 52]]),
        ]),
        module("beginner-shells", "Shells & Suspensions", "Say more with fewer notes and hear tension resolve.", [
            chordLesson("b-minor-shell", "Minor-Seventh Shell", "Outline a minor-seventh sound with essential notes.", "Hold each shell as a chord and release before moving to its next inversion.", [3], [[50, 53, 60], [53, 60, 62], [60, 62, 65]]),
            chordLesson("b-dominant-tonic", "Dominant to Tonic", "Hear a dominant shell resolve into a major tonic shell.", "Hold the dominant shell, release, then land all tonic notes together.", [2, 3], [[55, 59, 65], [48, 52, 59]]),
            chordLesson("b-sus-dominant", "Sus to Dominant", "Hear a suspended fourth resolve into a chord-defining third.", "Play both four-note voicings together and notice the single moving voice.", [4], [[55, 60, 62, 65], [55, 59, 62, 65]]),
        ]),
        module("beginner-color", "Adding Jazz Color", "Extend familiar harmony and begin moving ideas between keys.", [
            chordLesson("b-major-nine", "Major-Ninth Voicing", "Add seventh and ninth color to a major chord.", "Press all five tones together, then move to the compact upper inversion.", [5], [[60, 64, 67, 71, 74], [64, 67, 71, 74, 76]]),
            chordLesson("b-minor-nine", "Minor-Ninth Voicing", "Build a richer minor sound with seventh and ninth extensions.", "Hold each five-note voicing long enough to hear its complete minor color.", [5], [[62, 65, 69, 72, 76], [65, 69, 72, 76, 81]]),
            chordLesson("b-transpose", "Move the Shape", "Transpose a familiar chord shape into another key area.", "Play the C voicing together, release it, then reproduce the shape from F.", [11, 23], [[60, 64, 67, 72], [65, 69, 72, 77]]),
        ]),
    ])

    public static let intermediate = CourseStage(level: .intermediate, modules: [
        module("intermediate-motion", "Guide Tones & Dominant Motion", "Create strong resolutions with compact inner voices and altered dominants.", [
            chordLesson("i-guide-chain", "Guide-Tone Chain", "Connect II–V–I harmony using compact third-and-seventh movement.", "Play each guide-tone pair together and connect the smallest possible movement.", [7], [[53, 60], [53, 59], [52, 59]]),
            chordLesson("i-tritone", "Dominant Detour", "Hear how a tritone-substitute dominant can lead to the same tonic.", "Hold each guide-tone pair as a chord and compare both dominant routes home.", [6], [[59, 65], [53, 59], [52, 59]]),
            chordLesson("i-altered", "Altered Tension Release", "Add altered dominant colors and resolve them clearly.", "Press the altered voicing together, release, then resolve to the tonic voicing.", [8], [[59, 65, 68, 75], [60, 64, 67, 72]]),
        ]),
        module("intermediate-scales", "Chord-Scale Fluency", "Relate chord tones to major, melodic-minor, and symmetric collections.", [
            lesson("i-major-mode", "Major-Mode Anchor", "Relate a complete major scale to stable chord tones.", "Play evenly and gently accent the root, third, fifth, and seventh.", [9], [60, 62, 64, 65, 67, 69, 71, 72]),
            lesson("i-melodic-minor", "Melodic-Minor Color", "Internalize the raised sixth and seventh of melodic minor.", "Play the ascent, sing its final four notes, then repeat.", [9], [57, 59, 60, 62, 64, 66, 68, 69]),
            lesson("i-symmetric", "Symmetric Dominant Steps", "Recognize the alternating intervals of a diminished sound.", "Use a steady pulse and count the alternating half-step and whole-step motion.", [9, 10, 11], [55, 56, 58, 59, 61, 62, 64, 65]),
        ]),
        module("intermediate-colors", "Modal & Stacked Colors", "Explore open voicings, fourths, and upper harmonic structures.", [
            chordLesson("i-modal-shift", "Modal Voicing Shift", "Hear a minor modal voicing move upward by one semitone.", "Play the first four-note voicing together, then shift the entire shape upward.", [12], [[57, 62, 67, 72], [58, 63, 68, 73]]),
            chordLesson("i-fourths", "Fourth-Stack Voicings", "Build spacious voicings from consecutive fourths.", "Press each four-note stack as one sound and keep the interval shape intact.", [13], [[48, 53, 58, 63], [58, 63, 68, 73]]),
            chordLesson("i-upper-structure", "Upper-Structure Resolution", "Combine dominant guide tones with an upper triad and resolve.", "Sound the full dominant color together, then release into the tonic voicing.", [14], [[59, 65, 68, 72, 75], [60, 64, 67, 71]]),
        ]),
        module("intermediate-pentatonics", "Pentatonic Application", "Turn compact note collections into flexible melodic vocabulary.", [
            lesson("i-major-pentatonic", "Major Pentatonic Shape", "Develop an open-sounding melodic vocabulary without semitone clashes.", "Keep the rhythm even, then repeat with accents grouped in threes.", [15], [60, 62, 64, 67, 69, 72, 69, 67]),
            lesson("i-minor-pentatonic", "Minor Pentatonic Arc", "Shape a minor-pentatonic line across more than one octave.", "Crescendo toward the highest note and relax on the descent.", [15], [62, 65, 67, 69, 72, 74, 72, 69]),
            lesson("i-pentatonic-251", "Pentatonic II–V–I Route", "Switch color collections across a progression and resolve deliberately.", "Hear the sequence as minor color, dominant color, then a clear major arrival.", [10, 15], [62, 65, 69, 65, 68, 70, 72, 64]),
        ]),
    ])

    public static let advanced = CourseStage(level: .advanced, modules: [
        module("advanced-color", "Harmonic Color", "Control upper structures, altered resolution, and superimposed collections.", [
            chordLesson("a-upper-colors", "Upper-Structure Colors", "Hear a major triad as extensions over a dominant foundation.", "Hold the root and upper triad as one chord, then change the upper inversion.", [14], [[48, 62, 66, 69], [48, 66, 69, 74]]),
            chordLesson("a-altered-resolution", "Altered Dominant Resolution", "Connect altered dominant tensions to stable tonic tones.", "Press the altered dominant together and resolve all voices into the tonic chord.", [8, 9, 10, 14], [[56, 59, 62, 65], [48, 52, 55, 60]]),
            lesson("a-pentatonic-super", "Pentatonic Superimposition", "Use a bright pentatonic collection as an improvisational color.", "Play evenly, then repeat with a shifting accent every three notes.", [15], [62, 64, 66, 69, 71, 74, 71, 69]),
        ]),
        module("advanced-voicings", "Advanced Voicing Movement", "Shape efficient inner voices and modern multi-note textures.", [
            chordLesson("a-guide-turnaround", "Guide-Tone Turnaround", "Trace compact inner-voice movement through a II–V–I.", "Play each guide-tone pair simultaneously and minimize movement between chords.", [7, 8, 16], [[53, 60], [59, 65], [59, 64], [48, 55]]),
            chordLesson("a-quartal-planing", "Quartal Planing", "Move stacked-fourth shapes while retaining an open sound.", "Play each four-note stack together, releasing cleanly before shifting upward.", [12, 13, 16], [[50, 55, 60, 65], [52, 57, 62, 67]]),
            chordLesson("a-block-melody", "Block-Chord Melody", "Move a harmonized melody with locked-hand chord shapes.", "Press each four-note block together while bringing out its highest note.", [19], [[48, 55, 59, 64], [52, 59, 64, 67], [55, 60, 64, 71], [59, 64, 67, 72]]),
        ]),
        module("advanced-language", "Piano Language & Groove", "Coordinate historical piano textures with Latin rhythmic vocabulary.", [
            chordLesson("a-stride", "Stride Reach", "Coordinate bass-register targets with upper-register chords.", "Alternate each single bass note with its full three-note chord response.", [17], [[36], [52, 55, 60], [43], [59, 62, 65]]),
            chordLesson("a-bebop-shells", "Bebop Left-Hand Shells", "Connect sparse left-hand support to compact chord responses.", "Play each shell or chord together, keeping the left-hand attacks light and short.", [17], [[50, 57], [60, 64, 67], [55, 65], [71, 76]]),
            chordLesson("a-montuno", "Montuno Cell", "Internalize repeated chord cells suited to Latin jazz accompaniment.", "Play each voicing as one attack and keep the transitions rhythmically even.", [20], [[60, 64, 67], [60, 64, 69], [60, 64, 67], [59, 62, 67]]),
        ]),
        module("advanced-integration", "Integration & Improvisation", "Combine space, pattern language, and personal voice in practical phrases.", [
            chordLesson("a-comping", "Interactive Comping", "Practice leaving space between compact harmonic targets.", "Play each voicing together, release it, then leave a silent count before the next.", [21], [[50, 60], [59, 65], [64, 69]]),
            lesson("a-four-note-cells", "Four-Note Melodic-Minor Cells", "Sequence compact melodic-minor fragments through a wider range.", "Hear each group of four as one unit, then transpose it after mastering the pattern.", [9, 18], [60, 62, 63, 65, 62, 63, 65, 67]),
            chordLesson("a-personal-etude", "Personal Turnaround Etude", "Combine shells, extensions, and voice leading into a reusable progression.", "Play each dyad as a chord, then vary the rhythm while preserving the progression.", [16, 22, 23], [[62, 65], [60, 64], [59, 65], [60, 64]]),
        ]),
    ])

    public static var firstLesson: PracticeLesson {
        beginner.modules[0].lessons[0]
    }

    public static func lesson(id: String) -> PracticeLesson? {
        course.lesson(id: id)
    }

    public static func navigation(forLessonID id: String) -> CourseLessonNavigation? {
        course.navigation(forLessonID: id)
    }

    private static func module(_ id: String, _ title: String, _ summary: String, _ lessons: [PracticeLesson]) -> CourseModule {
        CourseModule(id: id, title: title, summary: summary, lessons: lessons)
    }

    private static func lesson(
        _ id: String,
        _ title: String,
        _ objective: String,
        _ instruction: String,
        _ chapters: [Int],
        _ pitches: [UInt8]
    ) -> PracticeLesson {
        let theory = theoryByLessonID[id] ?? objective
        return PracticeLesson(
            id: id,
            title: title,
            objective: objective,
            theory: theory,
            studyGuide: studyGuide(for: id, theory: theory),
            practiceInstruction: instruction,
            sourceChapters: chapters,
            pitches: pitches
        )
    }

    private static func chordLesson(
        _ id: String,
        _ title: String,
        _ objective: String,
        _ instruction: String,
        _ chapters: [Int],
        _ chords: [[UInt8]]
    ) -> PracticeLesson {
        let theory = theoryByLessonID[id] ?? objective
        return PracticeLesson(
            id: id,
            title: title,
            objective: objective,
            theory: theory,
            studyGuide: studyGuide(for: id, theory: theory),
            practiceInstruction: instruction,
            sourceChapters: chapters,
            chords: chords
        )
    }

    private static func studyGuide(for id: String, theory: String) -> String {
        guard let detail = studyDetailByLessonID[id] else { return theory }
        return "\(theory) \(detail)"
    }

    private static let theoryByLessonID: [String: String] = [
        "b-step-skip": "Melodies move by intervals. Steps connect neighboring scale tones, while skips create wider shapes that the ear learns to recognize.",
        "b-major-minor": "A triad's third determines its basic major or minor quality. Keeping the root and fifth fixed makes that one-note contrast easy to hear.",
        "b-inversions": "An inversion keeps the same chord tones but places a different member in the bass. This creates smoother movement and new keyboard shapes.",
        "b-c-major": "The major scale is the reference map for diatonic harmony. Its seventh degree has a strong tendency to resolve upward to the tonic.",
        "b-diatonic-thirds": "Diatonic thirds use alternating notes from one scale. Their changing major and minor sizes reveal the harmony contained inside the key.",
        "b-first-251": "II–V–I is jazz's central cadence: pre-dominant motion creates tension, the dominant intensifies it, and the tonic provides release.",
        "b-minor-shell": "A shell voicing reduces a chord to the tones that communicate its function most efficiently, usually the root, third, and seventh.",
        "b-dominant-tonic": "Dominant harmony contains unstable guide tones that resolve by small steps into a tonic chord, producing a clear sense of arrival.",
        "b-sus-dominant": "A suspended chord replaces the defining third with the fourth. Resolving that note downward reveals the dominant quality.",
        "b-major-nine": "A major ninth chord extends the major-seventh sound with the ninth, adding brightness without changing its tonic function.",
        "b-minor-nine": "A minor ninth combines a minor third and minor seventh with the ninth, producing a spacious minor color common in jazz voicing.",
        "b-transpose": "Transposition preserves a musical idea's interval pattern while moving it to a new tonal center.",
        "i-guide-chain": "Thirds and sevenths define chord quality and function. Their half-step connections make a progression sound continuous even without roots.",
        "i-tritone": "Dominant chords a tritone apart share their essential guide tones in reversed roles, allowing one dominant to substitute for the other.",
        "i-altered": "Altered dominants intensify resolution by changing tensions such as the ninth or fifth while preserving dominant function.",
        "i-major-mode": "Modes of a major scale contain the same notes but organize them around different tonal centers and chord functions.",
        "i-melodic-minor": "Jazz melodic minor uses a raised sixth and seventh in both directions, creating several important modern dominant colors.",
        "i-symmetric": "The diminished scale alternates half and whole steps. Its symmetry lets a compact idea repeat at minor-third intervals.",
        "i-modal-shift": "Modal voicings emphasize color and interval structure rather than conventional dominant-to-tonic resolution.",
        "i-fourths": "Quartal voicings stack fourths instead of thirds, creating open harmony whose function depends strongly on context.",
        "i-upper-structure": "An upper-structure triad places a familiar triad above a chord's guide tones to organize complex extensions into a playable shape.",
        "i-major-pentatonic": "The major pentatonic removes the scale's two semitone tensions, leaving an open five-note collection suited to melodic development.",
        "i-minor-pentatonic": "Minor pentatonic centers the minor third and seventh, giving a compact melodic vocabulary that remains flexible across several harmonies.",
        "i-pentatonic-251": "Changing pentatonic collections over a cadence lets a solo line follow the harmony without spelling every full chord.",
        "a-upper-colors": "Upper structures make altered extensions easier to hear and voice by grouping them into recognizable triads above a harmonic foundation.",
        "a-altered-resolution": "The strength of an altered sound comes from voice leading: each tension should have a convincing short path into the tonic.",
        "a-pentatonic-super": "Superimposing a pentatonic from a non-root chord tone highlights selected extensions while retaining a coherent melodic shape.",
        "a-guide-turnaround": "A convincing turnaround can be reduced to interacting inner voices whose small movements imply the complete harmony.",
        "a-quartal-planing": "Planing moves a fixed interval shape in parallel. The repeated structure supplies unity while each position changes its harmonic meaning.",
        "a-block-melody": "Block-chord technique harmonizes each melody note with a coordinated chord so the line and harmony move as one texture.",
        "a-stride": "Stride separates a low bass attack from a mid-register chord response, creating both harmonic foundation and rhythmic momentum.",
        "a-bebop-shells": "Sparse left-hand shells leave room for melodic activity while still marking the progression's essential harmonic changes.",
        "a-montuno": "A montuno develops rhythmic energy through repeated, syncopated chord cells and clear voice leading between inversions.",
        "a-comping": "Comping is conversational accompaniment. Chord choice matters, but placement, duration, dynamics, and silence shape the interaction.",
        "a-four-note-cells": "Short scale cells are easier to transpose and transform than long runs, making them useful building blocks for improvised lines.",
        "a-personal-etude": "An etude turns harmonic vocabulary into a repeatable musical phrase that can later be varied in rhythm, register, and articulation.",
    ]

    private static let studyDetailByLessonID: [String: String] = [
        "b-step-skip": "Compare the distance and physical feel of each move before naming it. The aim is to connect the sound, the interval, and the keyboard shape rather than memorizing isolated notes.",
        "b-major-minor": "Play each complete triad as one event and notice how only the middle note changes the emotional color. Keep the outer notes steady so the third remains the clear point of comparison.",
        "b-inversions": "Follow the bass note as each chord tone rotates to the bottom. Although the spacing changes, the pitch collection and chord identity remain constant.",
        "b-c-major": "Treat the scale as a map of tendencies, not merely a finger pattern. Hear the seventh degree leaning toward the tonic and use that pull to orient yourself in the key.",
        "b-diatonic-thirds": "Listen to the sequence as harmony implied by pairs of notes. Some thirds sound wider and brighter while others sound narrower and darker because the scale supplies different interval qualities.",
        "b-first-251": "Hear the three chords as one directed gesture instead of three unrelated shapes. Smooth voice leading and a stable final tonic make the cadence intelligible.",
        "b-minor-shell": "The third and seventh carry most of the chord's identity while the root supplies context. Learning this compact skeleton prepares the left hand to support richer right-hand colors later.",
        "b-dominant-tonic": "Pay special attention to semitone resolution between the guide tones. That small movement creates more harmonic direction than large jumps between chord roots.",
        "b-sus-dominant": "Let the suspended fourth remain unresolved long enough to hear its ambiguity, then move it to the third. The resolution should sound like the harmony coming into focus.",
        "b-major-nine": "Hear the ninth as an extension of the tonic color rather than an added random note. Balance the voicing so the new color is present without obscuring the third and seventh.",
        "b-minor-nine": "Compare this sonority with the minor seventh shell beneath it. The ninth opens the register and adds color while the guide tones continue to define the chord.",
        "b-transpose": "Think in distances and functions instead of fixed letter names. A successful transposition preserves the contour, chord quality, and relationship between every voice.",
        "i-guide-chain": "Track each inner voice independently through the progression. Minimal movement makes the changes sound connected and gives the hand dependable landmarks even when roots are omitted.",
        "i-tritone": "Compare the original dominant with its substitute and identify their shared third-and-seventh pair. The bass changes dramatically while the guide-tone resolution remains persuasive.",
        "i-altered": "An alteration earns its place through its destination. Hear each tense note first as color, then as a voice with a specific short resolution into the tonic voicing.",
        "i-major-mode": "Hold the shared parent collection in mind while shifting the note that feels like home. Characteristic tones and the supporting chord are what distinguish one modal sound from another.",
        "i-melodic-minor": "Relate every color to the same melodic-minor parent collection, then hear how a different tonal center changes its function. Avoid treating the modes as unrelated fingering patterns.",
        "i-symmetric": "Notice how the alternating step pattern repeats and divides the octave evenly. This regularity makes a short cell portable, but phrasing and resolution are still needed to give it direction.",
        "i-modal-shift": "Listen for changes in color rather than a traditional cadence. Sustain common tones where possible so the changing interval structure is easy to hear.",
        "i-fourths": "Keep the fourths balanced and compare their open sound with familiar tertian chords. Context, bass placement, and melody determine whether the shape feels settled or suspended.",
        "i-upper-structure": "Hear the upper triad as one recognizable unit while the lower voices establish the dominant function. This layered view makes dense tensions easier to remember, transpose, and voice cleanly.",
        "i-major-pentatonic": "The omitted semitone tensions give the collection room to breathe. Practice hearing the five notes as a melodic color that can be reordered, sequenced, and rhythmically developed.",
        "i-minor-pentatonic": "Anchor the sound with the minor third and seventh, then notice how the remaining notes support bends, repetition, and rhythmic variation. The collection is a vocabulary, not a single stock pattern.",
        "i-pentatonic-251": "Make each collection reflect the current chord while preserving a connected melodic line. The change of color should be audible without interrupting the phrase.",
        "a-upper-colors": "Separate the foundation from the color layer when studying the voicing, then recombine them. Name the tensions contributed by the upper triad and listen for their individual resolutions.",
        "a-altered-resolution": "Judge the voicing by the clarity of its release, not by tension alone. Map every altered pitch to a nearby tonic tone and keep common tones stable where they strengthen the arrival.",
        "a-pentatonic-super": "Identify which chord extensions the displaced pentatonic emphasizes. Its internal shape should remain coherent even when its root is not the harmonic root.",
        "a-guide-turnaround": "Reduce the progression to its essential moving lines before adding roots or extensions. If the inner voices sing convincingly, the complete turnaround will feel inevitable rather than mechanical.",
        "a-quartal-planing": "Maintain the interval shape accurately as it moves, and listen to the changing relationship with the tonal center. Parallel motion supplies a consistent texture while rhythm gives the passage purpose.",
        "a-block-melody": "Treat each attack as a unified vertical sonority whose top voice remains the melody. Balance the inner notes below it so the harmonization supports rather than masks the line.",
        "a-stride": "The bass and chord are two halves of one pulse. Practice their register changes slowly, keeping the arm loose and the time steady before increasing speed.",
        "a-bebop-shells": "Use economical left-hand information to leave rhythmic and registral space for the right hand. The shells should mark form and function without competing with the line.",
        "a-montuno": "Accuracy includes placement as well as pitch. Lock the syncopated cell to an even pulse, then connect inversions with the smallest practical voice movements.",
        "a-comping": "Think in phrases and responses rather than continuous chord coverage. Vary attack, length, density, and silence while preserving the harmonic information the ensemble needs.",
        "a-four-note-cells": "Hear the cell as a manipulable idea with a clear contour. Transpose it, displace its rhythm, and connect successive versions so repetition develops rather than stalls the line.",
        "a-personal-etude": "Use the written route as raw material for a short musical statement. Once it is secure, vary one dimension at a time—rhythm, register, articulation, or harmonic placement—while retaining its identity.",
    ]
}
