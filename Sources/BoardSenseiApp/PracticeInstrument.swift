import Foundation

enum PracticeInstrumentCategory: String, CaseIterable, Identifiable {
    case grandPianos = "Grand pianos"
    case electricPianos = "Electric pianos"
    case synths = "Synths"

    var id: Self { self }
}

enum PracticeInstrument: String, CaseIterable, Identifiable {
    case acousticGrand
    case brightGrand
    case electricGrand
    case honkyTonk
    case classicElectricPiano
    case chorusedElectricPiano
    case squareLead
    case sawLead
    case synthBrass
    case warmPad
    case polysynthPad

    var id: Self { self }

    var name: String {
        switch self {
        case .acousticGrand: "Acoustic Grand"
        case .brightGrand: "Bright Grand"
        case .electricGrand: "Electric Grand"
        case .honkyTonk: "Honky-tonk Piano"
        case .classicElectricPiano: "Classic Electric Piano"
        case .chorusedElectricPiano: "Chorused Electric Piano"
        case .squareLead: "Square Lead"
        case .sawLead: "Saw Lead"
        case .synthBrass: "Synth Brass"
        case .warmPad: "Warm Pad"
        case .polysynthPad: "Polysynth Pad"
        }
    }

    var category: PracticeInstrumentCategory {
        switch self {
        case .acousticGrand, .brightGrand, .honkyTonk: .grandPianos
        case .electricGrand, .classicElectricPiano, .chorusedElectricPiano: .electricPianos
        case .squareLead, .sawLead, .synthBrass, .warmPad, .polysynthPad: .synths
        }
    }

    /// Zero-based General MIDI program number.
    var program: UInt8 {
        switch self {
        case .acousticGrand: 0
        case .brightGrand: 1
        case .electricGrand: 2
        case .honkyTonk: 3
        case .classicElectricPiano: 4
        case .chorusedElectricPiano: 5
        case .synthBrass: 62
        case .squareLead: 80
        case .sawLead: 81
        case .warmPad: 89
        case .polysynthPad: 90
        }
    }

    var symbol: String {
        category == .synths ? "waveform.path" : "pianokeys"
    }
}
