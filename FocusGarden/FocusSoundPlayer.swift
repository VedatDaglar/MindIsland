import Foundation
import CoreAudio
import AVFoundation

final class FocusSoundPlayer {
    static let shared = FocusSoundPlayer()

    enum Cue { case start, complete, breakStart, breakEnd }

    private var audioPlayer: AVAudioPlayer?
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    private var configured = false
    private var interruptionObserver: NSObjectProtocol?

    init() {
        setupInterruptionHandling()
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func play(_ cue: Cue) {
        guard let format else { return }
        configureIfNeeded(format: format)
        guard let buffer = makeBuffer(for: cue, format: format) else { return }
        if player.isPlaying { player.stop() }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    func startAmbient() {
        // Ensure audio session is active for background playback
        activateAudioSession()

        if let format {
            configureIfNeeded(format: format)
        }

        let activeSoundId = UserDefaults(suiteName: SharedStore.suiteName)?
            .string(forKey: "activeSoundId")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let soundName = (activeSoundId?.isEmpty == false) ? activeSoundId! : "zen_garden"

        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            return
        }

        startLoop(at: url)
    }

    func stopAmbient() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    /// Activate the audio session for background playback.
    /// Must be called before starting any audio that should persist in background.
    /// IMPORTANT: Do NOT use .mixWithOthers — it can cause iOS to kill background audio.
    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            print("Audio session activation failed: \(error)")
        }
    }

    private func startLoop(at url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.4
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Ambient sound failed: \(error)")
        }
    }

    private func configureIfNeeded(format: AVAudioFormat) {
        guard !configured else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.55
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
            try engine.start()
            configured = true
        } catch {
            print("Audio engine config failed: \(error)")
        }
    }

    /// Handle audio session interruptions (phone calls, Siri, etc.)
    /// so we can resume playback after the interruption ends.
    private func setupInterruptionHandling() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            switch type {
            case .began:
                // Interruption began - audio is paused automatically
                break
            case .ended:
                // Interruption ended - try to resume
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self?.resumeAfterInterruption()
                    }
                }
            @unknown default:
                break
            }
        }
    }

    private func resumeAfterInterruption() {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("Failed to reactivate audio session: \(error)")
        }

        // Resume ambient if it was playing
        if let player = audioPlayer, !player.isPlaying {
            player.play()
        }

        // Restart engine if needed
        if configured && !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("Failed to restart audio engine: \(error)")
            }
        }
    }

    private func makeBuffer(for cue: Cue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let storedSoundId = UserDefaults(suiteName: SharedStore.suiteName)?
            .string(forKey: "activeSoundId")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let activeSoundId = (storedSoundId?.isEmpty == false) ? storedSoundId! : "zen_garden"

        let notes: [(frequency: Double, duration: Double, amplitude: Double)] = {
            if cue == .breakStart { return [(440.00, 0.10, 0.08), (523.25, 0.12, 0.07)] }
            if cue == .breakEnd   { return [(659.25, 0.09, 0.08), (523.25, 0.10, 0.08), (440.00, 0.12, 0.07)] }

            switch activeSoundId {
            case "heavy_rain":
                switch cue {
                case .start: return [(400, 0.05, 0.03), (450, 0.06, 0.04)]
                case .complete: return [(400, 0.05, 0.03), (550, 0.1, 0.03)]
                default: return [(440, 0.1, 0.0)]
                }
            case "cafe":
                switch cue {
                case .start: return [(300, 0.1, 0.05), (350, 0.15, 0.03)]
                case .complete: return [(300, 0.1, 0.05), (400, 0.15, 0.07)]
                default: return [(440, 0.1, 0.0)]
                }
            default:
                switch cue {
                case .start: return [(523.25, 0.09, 0.10), (659.25, 0.10, 0.08)]
                case .complete: return [(523.25, 0.08, 0.08), (659.25, 0.09, 0.08), (783.99, 0.12, 0.07)]
                default: return [(440.0, 0.1, 0.0)]
                }
            }
        }()

        let sr = format.sampleRate
        let gap = 0.025
        let totalFrames = Int((notes.reduce(0) { $0 + $1.duration } + gap * Double(notes.count - 1)) * sr)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(totalFrames)
        guard let ch = buffer.floatChannelData?[0] else { return nil }

        var cursor = 0
        for note in notes {
            let nf = Int(note.duration * sr)
            let af = max(Int(0.018 * sr), 1)
            let rf = max(Int(0.030 * sr), 1)

            for f in 0..<nf {
                let raw = sin(2 * .pi * note.frequency * Double(f) / sr)
                let env = min(Double(f) / Double(af), 1) * min(Double(nf - f) / Double(rf), 1)
                ch[cursor + f] = Float(raw * note.amplitude * env)
            }

            cursor += nf + Int(gap * sr)
        }

        return buffer
    }
}
