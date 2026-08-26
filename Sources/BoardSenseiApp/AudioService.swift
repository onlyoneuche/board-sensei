@preconcurrency import AVFAudio
import AudioToolbox
import CBoardSenseiBridge
import Foundation
import MusicCore

@MainActor
final class AudioService: ObservableObject {
    private struct PreviewTransport {
        let timeline: PracticePlaybackTimeline
        let startSampleTime: AUEventSampleTime
        let startHostTime: UInt64
        let clock: PracticePlaybackClock
        let midiChannel: UInt8
        let looping: Bool
        var scheduledCycles: Int
    }

    @Published private(set) var status = "Starting audio engine…"
    @Published var monitoringEnabled = true
    @Published private(set) var outputLevel: Float = 0
    @Published private(set) var selectedInstrument: PracticeInstrument = .acousticGrand
    @Published private(set) var soundBankDescription = "System General MIDI"
    @Published var volume: Float = 0.8 {
        didSet { engine.mainMixerNode.outputVolume = min(max(volume, 0), 1) }
    }
    @Published var metronomeVolume: Float = 0.62 {
        didSet {
            metronomePlayer.volume = min(max(metronomeVolume, 0), 1)
            updatePreviewMetronomeVolume()
        }
    }

    // The engine and nodes are one MainActor-owned domain. None of
    // these Apple audio objects or their callbacks cross an unchecked boundary.
    private let engine = AVAudioEngine()
    private let liveSampler = AVAudioUnitSampler()
    private var previewSampler = AVAudioUnitSampler()
    private let metronomePlayer = AVAudioPlayerNode()
    private let completionChimePlayer = AVAudioPlayerNode()
    private let metronomeFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let accentedClick: AVAudioPCMBuffer
    private let regularClick: AVAudioPCMBuffer
    private let completionChime: AVAudioPCMBuffer
    private let levelMeter = bs_level_meter_create()
    private var previewTransport: PreviewTransport?
    private var previewMetronomeBuffer: AVAudioPCMBuffer?
    private var previewMetronomeEnabled = false
    private var nextPreviewMIDIChannel: UInt8 = 0
    private var activeNotes: Set<UInt16> = []
    private var meterTask: Task<Void, Never>?
    private var hasInstalledMeter = false
    private let selectedInstrumentKey = "practiceInstrument"

    init() {
        BoardSenseiDiagnostics.trace("audio", "initializing audio ownership domain")
        if let stored = UserDefaults.standard.string(forKey: selectedInstrumentKey),
           let instrument = PracticeInstrument(rawValue: stored) {
            selectedInstrument = instrument
        }
        accentedClick = Self.makeClickBuffer(frequency: 1_900, amplitude: 0.9)
        regularClick = Self.makeClickBuffer(frequency: 1_280, amplitude: 0.64)
        completionChime = Self.makeCompletionChimeBuffer()

        engine.attach(liveSampler)
        engine.attach(previewSampler)
        engine.attach(metronomePlayer)
        engine.attach(completionChimePlayer)
        engine.connect(liveSampler, to: engine.mainMixerNode, format: nil)
        engine.connect(previewSampler, to: engine.mainMixerNode, format: nil)
        engine.connect(metronomePlayer, to: engine.mainMixerNode, format: metronomeFormat)
        engine.connect(completionChimePlayer, to: engine.mainMixerNode, format: metronomeFormat)
        engine.mainMixerNode.outputVolume = volume
        metronomePlayer.volume = metronomeVolume
        completionChimePlayer.volume = 0.58
        BoardSenseiDiagnostics.trace("audio", "graph attached; engineRunning=\(engine.isRunning)")
    }

    func start() {
        BoardSenseiDiagnostics.trace("audio", "start requested; engineRunning=\(engine.isRunning)")
        guard !engine.isRunning else {
            BoardSenseiDiagnostics.trace("audio", "start skipped; engine already running")
            return
        }
        status = "Loading \(selectedInstrument.name)…"
        do {
            BoardSenseiDiagnostics.trace("audio", "loading melodic bank; instrument=\(selectedInstrument.name)")
            soundBankDescription = try loadInstrument(selectedInstrument)
            BoardSenseiDiagnostics.trace("audio", "melodic bank loaded; source=\(soundBankDescription)")
            installMeterIfNeeded()
            BoardSenseiDiagnostics.trace("audio", "preparing engine")
            engine.prepare()
            BoardSenseiDiagnostics.trace("audio", "starting engine")
            try engine.start()
            updatePreviewMetronomeVolume()
            startMeterPolling()
            status = "Audio ready · \(selectedInstrument.name) · \(soundBankDescription)"
            BoardSenseiDiagnostics.trace("audio", "engine ready")
        } catch {
            status = "Audio unavailable: \(error.localizedDescription)"
            BoardSenseiDiagnostics.trace("audio", "start failed; error=\(error.localizedDescription)")
        }
    }

    func handle(_ event: NormalizedMIDIEvent) {
        guard monitoringEnabled, engine.isRunning else { return }
        switch event {
        case let .noteOn(note, velocity, channel, _):
            liveSampler.startNote(note, withVelocity: velocity, onChannel: channel)
            activeNotes.insert(noteKey(note: note, channel: channel))
        case let .noteOff(note, _, channel, _):
            liveSampler.stopNote(note, onChannel: channel)
            activeNotes.remove(noteKey(note: note, channel: channel))
        case let .sustain(value, channel, _):
            liveSampler.sendController(64, withValue: value, onChannel: channel)
        case let .controlChange(controller, value, channel, _):
            liveSampler.sendController(controller, withValue: value, onChannel: channel)
        }
    }

    func panic() {
        silence(sampler: liveSampler)
        activeNotes.removeAll()
        stopPreview()
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
            soundBankDescription = try loadInstrument(instrument)
            selectedInstrument = instrument
            persistSelectedInstrument()
            status = "Audio ready · \(instrument.name) · \(soundBankDescription)"
        } catch {
            soundBankDescription = (try? loadInstrument(previous)) ?? soundBankDescription
            status = "Could not load \(instrument.name): \(error.localizedDescription)"
        }
    }

    func stopPreview() {
        BoardSenseiDiagnostics.trace(
            "preview",
            "stop requested; hasTransport=\(previewTransport != nil) playing=\(isPreviewSequencePlaying)"
        )
        let stoppedChannel = previewTransport?.midiChannel
        metronomePlayer.stop()
        silence(sampler: previewSampler)
        previewSampler.auAudioUnit.reset()
        if let stoppedChannel {
            mutePreviewChannel(stoppedChannel)
        }
        previewTransport = nil
        previewMetronomeBuffer = nil
        metronomePlayer.volume = min(max(metronomeVolume, 0), 1)
        BoardSenseiDiagnostics.trace("preview", "stopped and released")
    }

    /// Discards the sampler that owns scheduled packets from the previous
    /// lesson/hand/range projection. A replacement is connected immediately but
    /// remains silent until an explicit preview start schedules a new timeline.
    func resetPreviewPlaybackGeneration() {
        BoardSenseiDiagnostics.trace("preview", "resetting scheduled playback generation")
        stopPreview()

        let retiredSampler = previewSampler
        engine.disconnectNodeOutput(retiredSampler)
        engine.detach(retiredSampler)

        let replacement = AVAudioUnitSampler()
        previewSampler = replacement
        engine.attach(replacement)
        engine.connect(replacement, to: engine.mainMixerNode, format: nil)

        do {
            _ = try loadInstrument(selectedInstrument, into: [replacement])
            BoardSenseiDiagnostics.trace("preview", "replacement sampler ready")
        } catch {
            status = "Preview audio unavailable: \(error.localizedDescription)"
            BoardSenseiDiagnostics.trace(
                "preview",
                "replacement sampler load failed; error=\(error.localizedDescription)"
            )
        }
    }

    func startPreview(
        timeline: PracticePlaybackTimeline,
        tempo: Int,
        looping: Bool,
        metronomeEnabled: Bool
    ) throws {
        BoardSenseiDiagnostics.trace(
            "preview",
            "start requested; events=\(timeline.events.count) tempo=\(tempo) loop=\(looping) metronome=\(metronomeEnabled)"
        )
        if !engine.isRunning { start() }
        guard engine.isRunning else {
            throw NSError(
                domain: "BoardSensei.AudioService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "The audio engine is not running"]
            )
        }

        stopPreview()
        guard let samplerRenderTime = previewSampler.lastRenderTime,
              samplerRenderTime.isSampleTimeValid,
              samplerRenderTime.isHostTimeValid,
              let outputRenderTime = engine.outputNode.lastRenderTime,
              outputRenderTime.isHostTimeValid else {
            throw NSError(
                domain: "BoardSensei.AudioService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "The audio render timeline is not ready"]
            )
        }
        guard previewSampler.auAudioUnit.scheduleMIDIEventBlock != nil else {
            throw NSError(
                domain: "BoardSensei.AudioService",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "The preview sampler cannot schedule MIDI events"]
            )
        }

        let sampleRate = previewSampler.outputFormat(forBus: 0).sampleRate
        let clock = PracticePlaybackClock(
            tempoBeatsPerMinute: Double(tempo),
            sampleRate: sampleRate
        )
        let midiChannel = nextPreviewMIDIChannel
        nextPreviewMIDIChannel = (nextPreviewMIDIChannel + 1) % 16
        activatePreviewChannel(midiChannel)
        let startDelaySeconds = 0.12
        let latestRenderHostTime = max(
            samplerRenderTime.hostTime,
            outputRenderTime.hostTime
        )
        let startHostTime = latestRenderHostTime
            + AVAudioTime.hostTime(forSeconds: startDelaySeconds)
        let samplerLeadSeconds = AVAudioTime.seconds(
            forHostTime: startHostTime - samplerRenderTime.hostTime
        )
        let transport = PreviewTransport(
            timeline: timeline,
            startSampleTime: samplerRenderTime.sampleTime
                + AUEventSampleTime((sampleRate * samplerLeadSeconds).rounded()),
            startHostTime: startHostTime,
            clock: clock,
            midiChannel: midiChannel,
            looping: looping,
            scheduledCycles: 0
        )
        previewTransport = transport
        previewMetronomeEnabled = metronomeEnabled
        updatePreviewMetronomeVolume()
        BoardSenseiDiagnostics.trace("preview", "scheduling MIDI render events")
        try schedulePreviewCycles(looping ? 8 : 1)
        BoardSenseiDiagnostics.trace("preview", "rendering PCM metronome cycle")
        let clickBuffer = makePreviewMetronomeBuffer(
            timeline: timeline,
            tempo: tempo,
            looping: looping
        )
        previewMetronomeBuffer = clickBuffer
        metronomePlayer.scheduleBuffer(
            clickBuffer,
            at: nil,
            options: looping ? .loops : []
        )
        BoardSenseiDiagnostics.trace("preview", "starting render-timeline transport")
        metronomePlayer.play(at: AVAudioTime(hostTime: transport.startHostTime))
        BoardSenseiDiagnostics.trace("preview", "transport started; playing=\(isPreviewSequencePlaying)")
    }

    func setPreviewMetronomeEnabled(_ enabled: Bool) {
        BoardSenseiDiagnostics.trace("preview", "set metronome enabled=\(enabled)")
        previewMetronomeEnabled = enabled
        updatePreviewMetronomeVolume()
    }

    var previewPositionInQuarterNotes: Double {
        replenishPreviewScheduleIfNeeded()
        guard let previewTransport,
              let renderTime = engine.outputNode.lastRenderTime,
              renderTime.isHostTimeValid,
              renderTime.hostTime >= previewTransport.startHostTime else { return 0 }
        let elapsedSeconds = AVAudioTime.seconds(
            forHostTime: renderTime.hostTime - previewTransport.startHostTime
        )
        return previewTransport.clock.quarterNotes(forElapsedSeconds: elapsedSeconds)
    }

    var isPreviewSequencePlaying: Bool {
        guard let previewTransport else { return false }
        if previewTransport.looping { return true }
        guard let renderTime = engine.outputNode.lastRenderTime,
              renderTime.isHostTimeValid else { return false }
        guard renderTime.hostTime >= previewTransport.startHostTime else { return true }
        let elapsedSeconds = AVAudioTime.seconds(
            forHostTime: renderTime.hostTime - previewTransport.startHostTime
        )
        return previewTransport.clock.quarterNotes(forElapsedSeconds: elapsedSeconds)
            < previewTransport.timeline.durationQuarterNotes
    }

    func playMetronomeClick(accented: Bool) {
        BoardSenseiDiagnostics.trace("metronome", "practice click; accented=\(accented)")
        if !engine.isRunning { start() }
        guard engine.isRunning else { return }
        metronomePlayer.volume = min(max(metronomeVolume, 0), 1)
        metronomePlayer.scheduleBuffer(accented ? accentedClick : regularClick)
        if !metronomePlayer.isPlaying { metronomePlayer.play() }
    }

    func playCompletionChime() {
        BoardSenseiDiagnostics.trace("completion-audio", "play requested")
        if !engine.isRunning { start() }
        guard engine.isRunning else { return }
        completionChimePlayer.stop()
        completionChimePlayer.scheduleBuffer(completionChime)
        completionChimePlayer.play()
    }

    func stopCompletionChime() {
        completionChimePlayer.stop()
    }

    private func loadInstrument(_ instrument: PracticeInstrument) throws -> String {
        try loadInstrument(instrument, into: [liveSampler, previewSampler])
    }

    private func loadInstrument(
        _ instrument: PracticeInstrument,
        into samplers: [AVAudioUnitSampler]
    ) throws -> String {
        let candidatePaths = [
            Bundle.module.url(forResource: "BoardSensei", withExtension: "sf2", subdirectory: "Instruments"),
            Bundle.module.url(forResource: "Piano", withExtension: "sf2", subdirectory: "Instruments"),
            Bundle.main.url(forResource: "BoardSensei", withExtension: "sf2"),
            Bundle.main.url(forResource: "Piano", withExtension: "sf2"),
            URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"),
        ].compactMap { $0 }

        var lastError: Error?
        for bank in candidatePaths where FileManager.default.fileExists(atPath: bank.path) {
            do {
                for sampler in samplers {
                    try sampler.loadSoundBankInstrument(
                        at: bank,
                        program: instrument.program,
                        bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                        bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                    )
                }
                return bank.pathExtension.lowercased() == "sf2"
                    ? "Studio SoundFont"
                    : "System General MIDI"
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

    private func makePreviewMetronomeBuffer(
        timeline: PracticePlaybackTimeline,
        tempo: Int,
        looping: Bool
    ) -> AVAudioPCMBuffer {
        let quarterNotes = looping
            ? timeline.loopDurationQuarterNotes
            : timeline.durationQuarterNotes
        let secondsPerQuarterNote = 60.0 / Double(tempo)
        let frameCount = max(
            AVAudioFrameCount(1),
            AVAudioFrameCount(ceil(quarterNotes * secondsPerQuarterNote * metronomeFormat.sampleRate))
        )
        let buffer = AVAudioPCMBuffer(
            pcmFormat: metronomeFormat,
            frameCapacity: frameCount
        )!
        buffer.frameLength = frameCount
        let destination = buffer.floatChannelData![0]
        destination.initialize(repeating: 0, count: Int(frameCount))

        let beatUnit = 4.0 / Double(timeline.timeSignature.denominator)
        var beatPosition = 0.0
        var beatIndex = 0
        while beatPosition < quarterNotes - 0.000_1 {
            let click = beatIndex == 0 ? accentedClick : regularClick
            let source = click.floatChannelData![0]
            let destinationStart = Int(
                (beatPosition * secondsPerQuarterNote * metronomeFormat.sampleRate).rounded()
            )
            let availableFrames = max(0, Int(frameCount) - destinationStart)
            let copiedFrames = min(Int(click.frameLength), availableFrames)
            if copiedFrames > 0 {
                for frame in 0..<copiedFrames {
                    destination[destinationStart + frame] += source[frame]
                }
            }
            beatPosition += beatUnit
            beatIndex = (beatIndex + 1) % timeline.timeSignature.numerator
        }
        return buffer
    }

    private func schedulePreviewCycles(_ count: Int) throws {
        guard count > 0, var transport = previewTransport,
              let scheduleMIDI = previewSampler.auAudioUnit.scheduleMIDIEventBlock else { return }
        let firstCycle = transport.scheduledCycles
        let cycleCount = transport.looping ? count : min(count, 1 - firstCycle)
        guard cycleCount > 0 else { return }

        for cycle in firstCycle..<(firstCycle + cycleCount) {
            let cycleOffset = Double(cycle) * transport.timeline.loopDurationQuarterNotes
            for event in transport.timeline.events {
                let noteOnSample = transport.startSampleTime
                    + AUEventSampleTime(
                        transport.clock.sampleOffset(
                            forQuarterNotes: cycleOffset + event.startQuarterNote
                        )
                    )
                let noteOffSample = noteOnSample
                    + AUEventSampleTime(
                        transport.clock.sampleOffset(
                            forQuarterNotes: event.audibleDurationQuarterNotes
                        )
                    )
                for pitch in event.pitches {
                    scheduleMIDIMessage(
                        scheduleMIDI,
                        sampleTime: noteOnSample,
                        status: 0x90 | transport.midiChannel,
                        data1: pitch,
                        data2: 88
                    )
                    scheduleMIDIMessage(
                        scheduleMIDI,
                        sampleTime: noteOffSample,
                        status: 0x80 | transport.midiChannel,
                        data1: pitch,
                        data2: 0
                    )
                }
            }
        }
        transport.scheduledCycles += cycleCount
        previewTransport = transport
        BoardSenseiDiagnostics.trace(
            "preview",
            "scheduled cycles=\(transport.scheduledCycles)"
        )
    }

    private func replenishPreviewScheduleIfNeeded() {
        guard let transport = previewTransport, transport.looping else { return }
        let currentQuarterNote = rawPreviewPosition(using: transport)
        let scheduledThrough = Double(transport.scheduledCycles)
            * transport.timeline.loopDurationQuarterNotes
        let refillThreshold = transport.timeline.loopDurationQuarterNotes * 2
        if scheduledThrough - currentQuarterNote <= refillThreshold {
            do {
                try schedulePreviewCycles(8)
            } catch {
                BoardSenseiDiagnostics.trace(
                    "preview",
                    "schedule refill failed; error=\(error.localizedDescription)"
                )
            }
        }
    }

    private func rawPreviewPosition(using transport: PreviewTransport) -> Double {
        guard let renderTime = engine.outputNode.lastRenderTime,
              renderTime.isHostTimeValid,
              renderTime.hostTime >= transport.startHostTime else { return 0 }
        let elapsedSeconds = AVAudioTime.seconds(
            forHostTime: renderTime.hostTime - transport.startHostTime
        )
        return transport.clock.quarterNotes(forElapsedSeconds: elapsedSeconds)
    }

    private func scheduleMIDIMessage(
        _ scheduleMIDI: AUScheduleMIDIEventBlock,
        sampleTime: AUEventSampleTime,
        status: UInt8,
        data1: UInt8,
        data2: UInt8
    ) {
        let bytes = [status, data1, data2]
        bytes.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            scheduleMIDI(sampleTime, 0, buffer.count, baseAddress)
        }
    }

    private func updatePreviewMetronomeVolume() {
        metronomePlayer.volume = previewMetronomeEnabled && previewTransport != nil
            ? min(max(metronomeVolume, 0), 1)
            : 0
    }

    private func activatePreviewChannel(_ channel: UInt8) {
        previewSampler.sendController(7, withValue: 127, onChannel: channel)
        previewSampler.sendController(11, withValue: 127, onChannel: channel)
    }

    private func mutePreviewChannel(_ channel: UInt8) {
        previewSampler.sendController(64, withValue: 0, onChannel: channel)
        previewSampler.sendController(120, withValue: 0, onChannel: channel)
        previewSampler.sendController(123, withValue: 0, onChannel: channel)
        previewSampler.sendController(7, withValue: 0, onChannel: channel)
        previewSampler.sendController(11, withValue: 0, onChannel: channel)
    }

    private func silence(sampler: AVAudioUnitSampler) {
        guard engine.isRunning else { return }
        for channel in UInt8(0)...15 {
            sampler.sendController(64, withValue: 0, onChannel: channel)
            sampler.sendController(120, withValue: 0, onChannel: channel)
            sampler.sendController(123, withValue: 0, onChannel: channel)
        }
    }

    private func noteKey(note: UInt8, channel: UInt8) -> UInt16 {
        UInt16(channel) << 8 | UInt16(note)
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
            (0.00, 1_568.0, 0.38),
            (0.16, 2_093.0, 0.34),
            (0.32, 2_637.0, 0.30),
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
