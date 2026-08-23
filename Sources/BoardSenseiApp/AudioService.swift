@preconcurrency import AVFAudio
import CBoardSenseiBridge
import Foundation
import MusicCore

@MainActor
final class AudioService: ObservableObject {
    @Published private(set) var status = "Starting audio engine…"
    @Published var monitoringEnabled = true
    @Published private(set) var outputLevel: Float = 0
    @Published private(set) var selectedInstrument: PracticeInstrument = .acousticGrand
    @Published var volume: Float = 0.8 {
        didSet { engine.mainMixerNode.outputVolume = min(max(volume, 0), 1) }
    }
    @Published var metronomeVolume: Float = 0.62 {
        didSet { metronomePlayer.volume = min(max(metronomeVolume, 0), 1) }
    }

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private let metronomePlayer = AVAudioPlayerNode()
    private let completionChimePlayer = AVAudioPlayerNode()
    private let metronomeFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let accentedClick: AVAudioPCMBuffer
    private let regularClick: AVAudioPCMBuffer
    private let completionChime: AVAudioPCMBuffer
    private let levelMeter = bs_level_meter_create()
    private var activeNotes: Set<UInt8> = []
    private var previewNotes: Set<UInt8> = []
    private var meterTask: Task<Void, Never>?
    private var hasInstalledMeter = false
    private let selectedInstrumentKey = "practiceInstrument"

    init() {
        if let stored = UserDefaults.standard.string(forKey: selectedInstrumentKey),
           let instrument = PracticeInstrument(rawValue: stored) {
            selectedInstrument = instrument
        }
        accentedClick = Self.makeClickBuffer(frequency: 1_900, amplitude: 0.9)
        regularClick = Self.makeClickBuffer(frequency: 1_280, amplitude: 0.64)
        completionChime = Self.makeCompletionChimeBuffer()
        engine.attach(sampler)
        engine.attach(metronomePlayer)
        engine.attach(completionChimePlayer)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        engine.connect(metronomePlayer, to: engine.mainMixerNode, format: metronomeFormat)
        engine.connect(completionChimePlayer, to: engine.mainMixerNode, format: metronomeFormat)
        engine.mainMixerNode.outputVolume = volume
        metronomePlayer.volume = metronomeVolume
        completionChimePlayer.volume = 0.58
    }

    func start() {
        guard !engine.isRunning else { return }
        do {
            try loadInstrument(selectedInstrument)
            installMeterIfNeeded()
            engine.prepare()
            try engine.start()
            startMeterPolling()
            status = "Audio ready · \(selectedInstrument.name)"
        } catch {
            status = "Audio unavailable: \(error.localizedDescription)"
        }
    }

    func handle(_ event: NormalizedMIDIEvent) {
        guard monitoringEnabled, engine.isRunning else { return }
        switch event {
        case let .noteOn(note, velocity, channel, _):
            sampler.startNote(note, withVelocity: velocity, onChannel: channel)
            activeNotes.insert(note)
        case let .noteOff(note, _, channel, _):
            sampler.stopNote(note, onChannel: channel)
            activeNotes.remove(note)
        case let .sustain(value, channel, _):
            sampler.sendController(64, withValue: value, onChannel: channel)
        case let .controlChange(controller, value, channel, _):
            sampler.sendController(controller, withValue: value, onChannel: channel)
        }
    }

    func panic() {
        for channel in UInt8(0)...15 {
            sampler.sendController(123, withValue: 0, onChannel: channel)
        }
        activeNotes.removeAll()
        previewNotes.removeAll()
        stopCompletionChime()
    }

    func selectInstrument(_ instrument: PracticeInstrument) {
        guard instrument != selectedInstrument else { return }
        let previous = selectedInstrument
        panic()

        if !engine.isRunning {
            selectedInstrument = instrument
            persistSelectedInstrument()
            start()
            return
        }

        do {
            try loadInstrument(instrument)
            selectedInstrument = instrument
            persistSelectedInstrument()
            status = "Audio ready · \(instrument.name)"
        } catch {
            try? loadInstrument(previous)
            status = "Could not load \(instrument.name): \(error.localizedDescription)"
        }
    }

    func beginPreview(_ notes: [UInt8], velocity: UInt8 = 88) {
        if !engine.isRunning { start() }
        guard engine.isRunning else { return }
        for note in notes where !previewNotes.contains(note) {
            sampler.startNote(note, withVelocity: velocity, onChannel: 15)
            previewNotes.insert(note)
        }
    }

    func endPreview(_ notes: [UInt8]) {
        for note in notes {
            sampler.stopNote(note, onChannel: 15)
            previewNotes.remove(note)
        }
    }

    func stopPreview() {
        for note in previewNotes {
            sampler.stopNote(note, onChannel: 15)
        }
        previewNotes.removeAll()
    }

    func playMetronomeClick(accented: Bool) {
        if !engine.isRunning { start() }
        guard engine.isRunning else { return }
        metronomePlayer.scheduleBuffer(accented ? accentedClick : regularClick)
        if !metronomePlayer.isPlaying { metronomePlayer.play() }
    }

    func playCompletionChime() {
        if !engine.isRunning { start() }
        guard engine.isRunning else { return }
        completionChimePlayer.stop()
        completionChimePlayer.scheduleBuffer(completionChime)
        completionChimePlayer.play()
    }

    func stopCompletionChime() {
        completionChimePlayer.stop()
    }

    private func loadInstrument(_ instrument: PracticeInstrument) throws {
        let candidatePaths = [
            Bundle.main.url(forResource: "Piano", withExtension: "sf2"),
            URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"),
        ].compactMap { $0 }

        var lastError: Error?
        for bank in candidatePaths where FileManager.default.fileExists(atPath: bank.path) {
            do {
                try sampler.loadSoundBankInstrument(
                    at: bank,
                    program: instrument.program,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                )
                return
            } catch {
                lastError = error
            }
        }

        if let lastError { throw lastError }
        throw NSError(
            domain: "BoardSensei.AudioService",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No compatible SoundFont or General MIDI bank was found"]
        )
    }

    private func persistSelectedInstrument() {
        UserDefaults.standard.set(selectedInstrument.rawValue, forKey: selectedInstrumentKey)
    }

    private func installMeterIfNeeded() {
        guard !hasInstalledMeter else { return }
        hasInstalledMeter = true
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 512,
            format: nil,
            block: makeLevelMeterTap(levelMeter)
        )
    }

    private func startMeterPolling() {
        guard meterTask == nil else { return }
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let measured = bs_level_meter_load(levelMeter)
                outputLevel = max(measured, outputLevel * 0.82)
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private static func makeClickBuffer(frequency: Double, amplitude: Float) -> AVAudioPCMBuffer {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * 0.035)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let envelope = Float(exp(-time * 105))
            samples[frame] = sin(Float(2 * Double.pi * frequency * time)) * envelope * amplitude
        }
        return buffer
    }

    private static func makeCompletionChimeBuffer() -> AVAudioPCMBuffer {
        let sampleRate = 44_100.0
        let duration = 1.05
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        let strikes: [(start: Double, frequency: Double, amplitude: Double)] = [
            (0.00, 1_568.0, 0.38), // G6
            (0.16, 2_093.0, 0.34), // C7
            (0.32, 2_637.0, 0.30), // E7
        ]

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            var sample = 0.0

            for strike in strikes where time >= strike.start {
                let elapsed = time - strike.start
                let attack = min(elapsed / 0.004, 1)
                let decay = exp(-elapsed * 5.7)
                let fundamental = sin(2 * Double.pi * strike.frequency * elapsed)
                let shimmer = 0.34 * sin(2 * Double.pi * strike.frequency * 2.01 * elapsed)
                let bellPartial = 0.14 * sin(2 * Double.pi * strike.frequency * 3.91 * elapsed)
                sample += (fundamental + shimmer + bellPartial) * attack * decay * strike.amplitude
            }

            samples[frame] = Float(tanh(sample))
        }
        return buffer
    }
}

private func makeLevelMeterTap(_ meter: OpaquePointer?) -> AVAudioNodeTapBlock {
    { buffer, _ in
        guard let samples = buffer.floatChannelData?.pointee else {
            bs_level_meter_store(meter, 0)
            return
        }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else {
            bs_level_meter_store(meter, 0)
            return
        }

        var sumOfSquares: Float = 0
        for index in 0..<frameCount {
            let sample = samples[index]
            sumOfSquares += sample * sample
        }
        let rms = sqrt(sumOfSquares / Float(frameCount))
        let decibels = 20 * log10(max(rms, 0.000_001))
        let normalized = min(max((decibels + 60) / 60, 0), 1)
        bs_level_meter_store(meter, normalized)
    }
}
