# AI Translator — Complete Architecture, Business Logic & UI Blueprint (iOS Porting Specification)

> **Target Audience**: Senior iOS Engineers (Swift 6 / SwiftUI / AVFoundation / Firebase iOS SDK)  
> **Purpose**: Comprehensive, 1-to-1 specification of the **AI Translator** application covering System Architecture, Audio DSP & Half-Duplex Echo Gating State Machine, Gemini Live & Transcription AI Logic, Cloud Firestore Schemas & Security Rules, Local Keychain/AES-256-GCM Storage, and Complete UI/UX Screen & Design Specifications.

---

## 1. Executive Summary & Core Product Concept

**AI Translator** is a real-time, loudspeaker-first, two-way voice-to-voice interpreter designed for a **single phone placed flat on a table between two people**.
- **Supported Language Pairs**:
  1. `vi_en`: **Vietnamese (`vi-VN`) ↔ US English (`en-US`)**
  2. `vi_zhtw`: **Vietnamese (`vi-VN`) ↔ Traditional Chinese, Taiwan Mandarin (`zh-TW`, 繁體中文)** — strictly enforces Taiwan vocabulary (e.g., 計程車, 捷運, 軟體, 悠遊卡, 載具), phrasing, and `zh-TW` pronunciation; never outputs Mainland Simplified Chinese (`zh-CN`) or English when `vi_zhtw` is active.
- **Acoustic Challenge Solved**: Because the phone uses its **Loudspeaker** (`defaultToSpeaker`), the microphone would normally pick up the translated TTS output and re-translate its own voice in an infinite feedback loop. The app solves this with a deterministic **Half-Duplex Echo Gate State Machine (`EchoGateStateMachine`)** + **Pre-Roll Ring Buffer** + **320 ms Reverberation Tail Hold**.
- **Two Interaction Modes**:
  1. **Auto Mode (`AUTO`)**: Hands-free continuous Voice Activity Detection (VAD) with RMS dBFS threshold + peak drop-off tracking, 360 ms pre-roll preservation, 400 ms end-of-speech silence cutoff, 12-second max continuous speech auto-flush, and 2-minute idle session auto-close.
  2. **Two-Button Mode (`TWO_BUTTON`)**: Face-to-face split layout where the top half of the screen is rotated **180°** (`rotationEffect(.degrees(180))`) for the partner sitting across the table. Deterministic tap-to-talk / tap-to-translate for noisy environments.
- **Zero-Retention Privacy by Default**: No raw audio or speech transcripts are stored in Firestore or server logs. Optional local history is **OFF by default** and encrypted on-device with **AES-256-GCM** using hardware-backed keys.

---

## 2. High-Level Architecture & iOS Technology Mapping

### 2.1 System Architecture Diagram

```text
+---------------------------------------------------------------------------------------+
|                              Presentation Layer (SwiftUI)                             |
|  AuthScreen  |  HomeScreen (VI/EN UI + SettingsSheet)  |  ConversationScreen (180°)   |
|  TranscribeStudioScreen  |  AudioPermissionRationaleSheet  |  DebugTelemetryOverlay   |
+-------------------------------------------+-------------------------------------------+
                                            | @Observable / @Published State & Intents
                                            v
+---------------------------------------------------------------------------------------+
|                          InterpreterViewModel (@MainActor)                            |
+-------------------+-----------------------+-----------------------+-------------------+
                    |                       |                       |
                    v                       v                       v
+---------------------------+   +-----------------------+   +---------------------------+
|     audio / DSP Module    |   |    live / AI Module   |   |        data Module        |
|---------------------------|   |-----------------------|   |---------------------------|
| • AudioDspEngine          |   | • GeminiLiveSession   |   | • UserSettingsRepository  |
|   - 16kHz PCM16 Mono Mic  |   |   - FirebaseAI        |   |   (Firestore /users &     |
|   - 30ms Frames (480 smp) |   |   - Structured JSON   |   |    /daily_quotas)         |
|   - 12-Frame Pre-Roll     |   |     & Stream Modes    |   | • LocalPreferencesManager |
|   - DC Offset Removal &   |   |   - Model Fallback    |   |   (UserDefaults/AppStorage|
|     +12dB/+24dB Auto-Gain |   |     Chain (Live/Lite) |   |    + CryptoKit AES-GCM    |
|   - 24-Band Visualizer    |   |   - 60s Sliding RPM   |   |    Keychain History)      |
|   - Cloud Neural TTS +    |   |     Rate Limiter      |   | • BuiltInLanguagePairs    |
|     AVSpeechSynthesizer   |   |   - WebSocket Bidi    |   |   - vi_en (vi-VN<->en-US) |
| • EchoGateStateMachine    |   | • ReconnectPolicy     |   |   - vi_zhtw (vi-VN<->zhTW)|
|   - 7 Deterministic Phases|   | • LatencyStatsTracker |   | • RemoteInterpreterConfig |
+---------------------------+   +-----------------------+   +---------------------------+
```

### 2.2 Android-to-iOS Component Mapping Table

| Domain | Android Implementation | iOS Equivalent (Recommended) |
| :--- | :--- | :--- |
| **UI Framework** | Jetpack Compose (Material 3) | **SwiftUI** (iOS 17+ `@Observable`) |
| **State Management** | `ViewModel` + `StateFlow` + `collectAsStateWithLifecycle` | `@MainActor @Observable final class InterpreterViewModel` |
| **App Attestation** | `FirebaseAppCheck` (`DebugAppCheckProviderFactory` / `Recaptcha`) | `FirebaseAppCheck` (`AppCheckDebugProviderFactory` / `AppAttestProvider`) |
| **Authentication** | Jetpack `CredentialManager` (`GetSignInWithGoogleOption`) + `FirebaseAuth` | `GoogleSignIn-iOS` (`GIDSignIn`) + `FirebaseAuth` |
| **Cloud AI SDK** | `com.google.firebase:firebase-ai` (`Firebase.ai.generativeModel`) | `FirebaseAI` (`FirebaseAI.firebaseAI().generativeModel(...)`) |
| **Audio Session & Routing** | `AudioManager` (`MODE_NORMAL`, `isSpeakerphoneOn = true`, `AudioFocusRequest`) | `AVAudioSession.sharedInstance()` (`.playAndRecord`, options: `[.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]`) + `AVAudioSession.interruptionNotification` |
| **Audio Capture & DSP** | `AudioRecord` (16 kHz PCM16 mono, 30ms frames) + `AcousticEchoCanceler` / `NoiseSuppressor` / `AutomaticGainControl` | `AVAudioEngine` (`inputNode.installTap`, converted via `AVAudioConverter` to 16 kHz PCM16 mono) + `inputNode.isVoiceProcessingEnabled` (optional) |
| **Audio Playback & TTS** | `AudioTrack` (24 kHz PCM16) + Cloud Neural TTS (`MediaPlayer`) + `TextToSpeech` + `LoudnessEnhancer` | `AVAudioPlayerNode` (24 kHz PCM16) + Cloud Neural TTS (`AVAudioPlayer`) + `AVSpeechSynthesizer` |
| **Local Preferences** | Jetpack `DataStore<Preferences>` | `UserDefaults` / `@AppStorage` |
| **Encrypted History** | `AndroidKeyStore` + `Cipher("AES/GCM/NoPadding")` | **Keychain Services** (256-bit SymmetricKey) + **Apple `CryptoKit` (`AES.GCM`)** |
| **Cloud Database** | `FirebaseFirestore` (`/users/{uid}`, `/users/{uid}/daily_quotas/{dateKey}`) | `FirebaseFirestore` (identical document paths & schema) |
| **Keep Screen Awake** | `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON` | `UIApplication.shared.isIdleTimerDisabled = true` |
| **Lifecycle Background Hook** | `Lifecycle.Event.ON_STOP` | `@Environment(\.scenePhase)` (`.background` / `.inactive`) |

---

## 3. Core Module 1: Audio DSP Engine (`AudioDspEngine`)

### 3.1 Audio Format Constants
- **Input Sample Rate**: `16,000 Hz` (`INPUT_SAMPLE_RATE = 16000`)
- **Input Channels**: Mono (`1 channel`)
- **Input Encoding**: Signed 16-bit Little-Endian PCM (`PCM16`)
- **Frame Duration**: `30 ms` (`FRAME_DURATION_MS = 30`)
- **Samples Per Frame**: `480 samples` (`(16000 * 30) / 1000`)
- **Bytes Per Frame**: `960 bytes` (`480 * 2`)
- **Output Streaming Sample Rate**: `24,000 Hz` (`OUTPUT_SAMPLE_RATE = 24000`, Mono PCM16)

### 3.2 RMS dBFS Calculation with Quiet-Mic Boost (`calculateRmsDb`)
Every 30 ms frame (`480` 16-bit samples), compute the RMS level in decibels relative to full scale (`-90.0 dBFS` to `0.0 dBFS`):
1. **DC Offset Removal**:
   - Compute average sample value: `dcOffset = sum(buffer[0..<readCount]) / readCount`.
   - Center each sample: `centered = clamp(sample - dcOffset, -32768, 32767)`.
2. **Digital Pre-Amplification (+12 dB / 4x) for VAD**:
   - If `abs(centered) > 45` (above digital noise floor), multiply `centered * 4` clamped to `[-32768, 32767]`.
   - Normalize to `[-1.0, 1.0]`: `normSample = boosted / 32768.0`.
3. **RMS to dBFS**:
   - `rms = sqrt(sumSquares / readCount)`
   - If `rms <= 1e-5`, return `-90.0f`.
   - Otherwise return `clamp(20.0 * log10(rms), -90.0f, 0.0f)`.

### 3.3 24-Band Acoustic Waveform Extractor (`extractWaveformBands`)
Used by both `ConversationScreen` and `TranscribeStudioScreen` to render the live 24-bar visualizer at ~33 fps:
- Divide the `480` samples into `24` equal buckets (`20` samples per bucket).
- For each bucket, find the maximum normalized absolute peak: `peak = max(abs(sample) / 32768.0f)`.
- Scale and clamp: `bandValue = clamp(peak * 6.5f, 0.06f, 1.0f)`.
- When idle/stopped, emit `List(24) { 0.08f }`.

### 3.4 Pre-Roll Ring Buffer & Utterance Buffer (`utteranceBuffer` & `preRollFrames`)
- **Problem**: In continuous VAD mode, the first 100–300 ms of a spoken word occurs right before or as the VAD threshold triggers. Without a pre-roll buffer, the first syllable is clipped.
- **Solution**:
  - While `utteranceBuffer.size == 0` (waiting for speech to start), maintain a FIFO ring buffer `preRollFrames` holding the **last 12 frames (`12 * 30 ms = 360 ms`)** of captured PCM16 audio.
  - The moment `appendUtteranceChunk(pcmBytes)` is called for a new utterance (`utteranceBuffer.size == 0`), prepend all `12` frames from `preRollFrames` into `utteranceBuffer` and clear `preRollFrames`.
  - **Max Utterance Cap**: Cap `utteranceBuffer` at `45 seconds` (`16000 * 2 * 45 = 1,440,000 bytes` / `1.44 MB`). Any frames beyond 45s increment `droppedChunksCount`.
  - **Minimum Utterance Length**: When `consumeUtteranceWavBytes()` is called, if `raw.size < 4800` bytes (`< 150 ms` of audio), discard it and return `null` so brief clicks or taps never trigger an API call.

### 3.5 Automatic Peak Normalization & WAV Packaging (`normalizePcm16Audio` & `pcm16ToWavBytes`)
Before sending captured PCM16 bytes to Gemini:
1. Remove DC offset across the entire utterance buffer.
2. Find the maximum absolute sample peak `peak` across all samples.
3. If `peak` is between `180` and `22000` (quiet speaker sitting far from the table), apply automatic digital gain:
   - `gain = clamp(26000.0f / peak, 1.0f, 16.0f)` (up to +24 dB boost toward ~80% full scale).
   - Multiply every sample by `gain`, clamped to `[-32767, 32767]`.
4. Prepend a standard **44-byte RIFF WAVE header** (`16000 Hz`, `1 channel`, `16 bits/sample`, `audio/wav`).

### 3.6 Loudspeaker Output & Multi-Tier TTS Pipeline (`speakTranslatedStream`)
1. **Script-Based Locale Resolution (Critical Safety Guard)**:
   Never trust a metadata flag alone if the text contains CJK or Vietnamese characters. Inspect the actual output string first:
   - Contains CJK Unified Ideographs (`U+4E00..U+9FFF` or `U+3400..U+4DBF`) → force `Locale("zh-TW")` (Taiwan Mandarin).
   - Contains Vietnamese diacritics (`ăâđêôơưĂÂĐÊÔƠƯáàảãạ...`) → force `Locale("vi-VN")`.
   - Otherwise fall back to `targetLocale` (`zh-TW`, `vi-VN`, or `en-US`).
2. **Playback Lifecycle Callbacks**:
   - Immediately invoke `onPlaybackStartedCallback()` **before** audio starts playing so `EchoGateStateMachine` transitions to `PLAYING_GATED`.
   - Invoke `onPlaybackEndedCallback()` when playback finishes (or errors) so `EchoGateStateMachine` transitions to `TAIL_HOLD_GATED`.
3. **Two-Tier Synthesis**:
   - **Tier 1 (Cloud Neural TTS)**: Fetches MP3 stream (`tl=zh-TW`, `tl=vi`, or `tl=en`, up to 200 chars) and plays over media loudspeaker with volume boost (`0..12 dB`).
   - **Tier 2 (On-Device Native Synthesizer Fallback)**: On iOS, use `AVSpeechSynthesizer` with `AVSpeechSynthesisVoice(language: "zh-TW")` (Taiwan Mandarin), `AVSpeechSynthesisVoice(language: "vi-VN")`, or `AVSpeechSynthesisVoice(language: "en-US")` at rate `~0.51` (1.02x normal).
4. **Audio Interruption / Phone Call Handling**:
   - On iOS, observe `AVAudioSession.interruptionNotification`. When `.began` arrives, invoke `onAudioFocusLostCallback()` which immediately stops microphone capture and TTS playback.

---

## 4. Core Module 2: Half-Duplex Echo Gate State Machine (`EchoGateStateMachine`)

### 4.1 Gate Phases (`GatePhase`)
```swift
enum GatePhase: String {
    case IDLE                // Session not started or auto-closed after 2m inactivity
    case LISTENING_GATE_OPEN // Mic open, waiting for voice above speechRmsThresholdDb
    case SPEECH_ACTIVE       // Voice detected, forwarding 30ms PCM chunks to utteranceBuffer
    case TRANSLATING         // Utterance ended, waiting for Gemini response (mic gated)
    case PLAYING_GATED       // Loudspeaker playing translation (mic gated unless barge-in)
    case TAIL_HOLD_GATED     // Post-playback reverb suppression window (default 320ms)
    case MUTED               // User manually muted microphone
}
```

### 4.2 Configuration & Threshold Formulas (`EchoGateConfig`)
- `tailHoldMs`: `320 ms` default (configurable `150–800 ms` in UI, `100–1500 ms` in schema)
- `vadSilenceMs`: `400 ms` default (configurable `200–1200 ms` in UI, `150–2000 ms` in schema)
- `vadSensitivityPct`: `65%` default (configurable `10–95%` in UI, `1–100%` in schema)
- `allowBargeIn`: `false` default
- `idleTimeoutMs`: `120,000 ms` (`2 minutes`)
- **Speech RMS Threshold Formula**:
  $$\text{speechRmsThresholdDb} = -22.0 - (\text{clamp}(\text{vadSensitivityPct}, 1, 100) \times 0.30)$$
  *(At 65% sensitivity, threshold is `-41.5 dBFS`. At 100%, `-52.0 dBFS`. At 1%, `-22.3 dBFS`.)*
- **Barge-In RMS Threshold Formula**:
  $$\text{bargeInRmsThresholdDb} = \min(\text{speechRmsThresholdDb} + 14.0, -12.0)$$
  *(Requires a +14 dB stronger signal than normal speech to interrupt active loudspeaker playback.)*

### 4.3 Frame-by-Frame State Transitions (`onAudioFrame(rmsDb, nowElapsedMs)`)

```text
                       +------------------------+
                       |          IDLE          |
                       +-----------+------------+
                                   | startSession()
                                   v
         +------------>+------------------------+<------------+
         |             |  LISTENING_GATE_OPEN   |             |
         |             +-----------+------------+             |
         |                         | rmsDb >= speechThreshold |
         |                         v                          |
         |             +------------------------+             |
         |             |     SPEECH_ACTIVE      |             |
         |             +-----------+------------+             |
         |                         | silence >= vadSilenceMs  |
         |                         | OR speech >= 12,000ms    |
         |                         v                          |
         |             +------------------------+             |
         |             |      TRANSLATING       |             |
         |             +-----------+------------+             |
         |                         | onPlaybackStarted()      |
         |                         v                          |
         |             +------------------------+             |
         |             |     PLAYING_GATED      |             |
         |             +-----------+------------+             |
         |                         | onPlaybackFinished()     |
         |                         v                          |
         |             +------------------------+             |
         |             |    TAIL_HOLD_GATED     |             |
         |             +-----------+------------+             |
         |                         | elapsed >= tailHoldMs    |
         +-------------------------+--------------------------+
```

1. **In `LISTENING_GATE_OPEN`**:
   - If `rmsDb >= speechRmsThresholdDb`:
     - Transition to `SPEECH_ACTIVE`.
     - Record `speechStartElapsedMs = now`, `lastVoiceActivityElapsedMs = now`, `peakRmsDuringSpeechDb = rmsDb`.
     - Return `shouldForwardMicChunk = true`.
   - Else:
     - Check if `now - lastInteractionElapsedMs >= idleTimeoutMs` (`2 minutes`). If so, transition to `IDLE` and return `triggeredIdleTimeout = true`.
     - Otherwise stay in `LISTENING_GATE_OPEN` with `shouldForwardMicChunk = false` (never stream silent audio frames).
2. **In `SPEECH_ACTIVE`**:
   - Update `peakRmsDuringSpeechDb = max(peakRmsDuringSpeechDb, rmsDb)`.
   - **Continuing Voice Condition**: Voice is considered continuing only if **BOTH**:
     1. `rmsDb >= speechRmsThresholdDb`
     2. `rmsDb >= peakRmsDuringSpeechDb - 14.0f` *(prevents background hum from holding the utterance open forever after a loud speaker finishes talking)*.
   - If `isContinuingVoice == true`:
     - Update `lastVoiceActivityElapsedMs = now` and return `shouldForwardMicChunk = true`.
   - If `isContinuingVoice == false`:
     - Compute `silenceElapsed = now - lastVoiceActivityElapsedMs`.
     - If `silenceElapsed >= vadSilenceMs` (`400 ms`):
       - Reset `peakRmsDuringSpeechDb = -90f`, transition to `TRANSLATING`, and return `triggeredEndOfSpeech = true, shouldForwardMicChunk = false`.
     - Else (trailing silence inside an utterance before cutoff):
       - Stay in `SPEECH_ACTIVE` and return `shouldForwardMicChunk = true`.
   - **12-Second Continuous Speech Force-Flush (in `InterpreterViewModel`)**:
     - If `SPEECH_ACTIVE` continues uninterrupted for `>= 12,000 ms`, force `forceEndSpeech()`, transition to `TRANSLATING`, and flush the WAV buffer immediately so translation doesn't stall.
3. **In `PLAYING_GATED`**:
   - If `allowBargeIn == true` and `rmsDb >= bargeInRmsThresholdDb`:
     - Transition immediately to `SPEECH_ACTIVE` and return `triggeredBargeIn = true, shouldForwardMicChunk = true` (ViewModel stops TTS playback and clears buffers).
   - Otherwise return `shouldForwardMicChunk = false`.
4. **In `TAIL_HOLD_GATED`**:
   - When `onPlaybackFinished(now)` fires, `ViewModel` schedules a coroutine timer for `echoGatingTailMs` (`320 ms`).
   - While `now - playbackEndedElapsedMs < tailHoldMs`, return `shouldForwardMicChunk = false`.
   - Once `elapsed >= tailHoldMs`, reopen to `LISTENING_GATE_OPEN`.

---

## 5. Core Module 3: Gemini Live & Transcription AI Logic (`GeminiLiveSessionClient`)

### 5.1 Supported Models & Fallback Chains
- **Live Interpreter Models (`AVAILABLE_LIVE_MODELS`)**:
  1. `gemini-3.5-live-translate` *(Default — Live API • Unlimited RPM/RPD • 100K TPM)*
  2. `gemini-2.5-flash-preview-native-audio-dialog` *(Live API • Unlimited RPM/RPD • 1M TPM)*
  3. `gemini-3-flash-live` *(Live API • Unlimited RPM/RPD • 150K TPM)*
  4. `gemini-3.8-live` *(Live API • Unlimited RPM/RPD • 150K TPM)*
  5. `gemini-3.1-flash-lite-preview` *(Standard API • Tier 1 Quota • Flash Lite)*
  6. `gemini-3.5-flash-lite` *(Standard API • Tier 1 Quota • Flash Lite)*
- **Audio Transcription Models (`AVAILABLE_TRANSCRIBE_MODELS`)**:
  1. `gemini-3.5-transcribe-live` *(Default — Live API • Unlimited RPM/RPD • 100K TPM)*
  2. `gemini-3.5-live-translate`
  3. `gemini-3-flash-live`
  4. `gemini-3.8-live`
  5. `gemini-3.1-flash-lite-preview`
  6. `gemini-3.5-transcribe`
- **Automatic Fallback Chain**: Every interpretation or transcription call iterates through `buildCandidateModels(primaryModel)`. If the primary model throws an exception or returns an empty response in the user's region, it transparently falls back to the next model in the list.

### 5.2 Client-Side Sliding-Window Rate Limiter (`checkAndRecordRateLimit`)
- Maintains a 60-second sliding window `ArrayDeque<Long>` of request timestamps.
- Before every request, evicts timestamps older than `now - 60_000 ms`.
- If `recentRequestTimestampsMs.size >= maxRequestsPerMinute` (default `60 RPM`, configurable `5..120 RPM`), throws an `IllegalStateException`:
  `"Quota rate limit reached (60 requests/min). Please wait Xs before the next utterance."`

### 5.3 Live Utterance Interpretation (`interpretUtteranceWav`)
Operates in two modes depending on `subtitlesEnabled` (Temperature `0.1`):

#### Mode A: Subtitles OFF (`subtitlesEnabled == false` — Default Ultra-Low Latency Stream)
- Calls `generateContentStream` with `audio/wav` inline data and the strict system instruction + pair enforcement prompt.
- Tracks **TTFT (Time-To-First-Token)** on the first non-blank chunk (`latencyTracker.recordSample(ttftMs)`).
- Assembles `finalTranslated`.
- **Prompt-Echo & Silence Guard (`isPromptEchoOrSilence`)**: If output is empty, `"silence"`, `"null"`, `"none"`, or echoes system prompt phrases (`"silent simultaneous interpreter"`, `"strict language pair rule"`), treats as silence (`SpokenDirection.UNKNOWN`) and reopens the listening gate without speaking.
- **Wrong-Language Post-Generation Guard**:
  - If `pair.id == "vi_en"` and `finalTranslated` contains CJK characters → re-translates into `"English (en-US)"`.
  - If `pair.id == "vi_zhtw"` and `finalTranslated` contains neither CJK nor Vietnamese diacritics (e.g., model accidentally output English) → re-translates into `"Traditional Chinese, Taiwan Mandarin (zh-TW, 繁體中文)"`.
- Fires `onFirstAudioChunkReady(finalTranslated, targetLocale, ttftMs)` to start loudspeaker TTS immediately.

#### Mode B: Subtitles ON (`subtitlesEnabled == true` — Structured JSON Dual-Transcript Mode)
- Uses `responseMimeType = "application/json"` with `subtitleInterpretationSchema`:
  ```json
  {
    "detectedDirection": "A_TO_B | B_TO_A | SILENCE",
    "sourceTranscript": "Exact verbatim transcription in the spoken language",
    "targetTranslation": "Direct translation in the other language of the pair ONLY"
  }
  ```
- **Post-Generation Verification**:
  - For `vi_en`: Ensures neither `sourceTranscript` nor `targetTranslation` is Chinese, and if both `sourceText` and `translatedText` have Vietnamese diacritics, forces translation of `sourceText` into `English (en-US)`.
  - For `vi_zhtw`: If `sourceText` is Vietnamese (`hasVi && !hasCjk`) and `translatedText` lacks CJK characters, forces translation into `Traditional Chinese, Taiwan Mandarin (zh-TW, 繁體中文)`. If both `sourceText` and `translatedText` have CJK characters, forces translation into `natural everyday Vietnamese (vi-VN)`.

### 5.4 Deterministic Direction Inference (`inferDirectionFromOutput`)
Never rely solely on the LLM's `detectedDirection` enum, which can occasionally invert `A_TO_B` and `B_TO_A`. Infer direction deterministically from character scripts:
- For `vi_zhtw` (`langA = vi-VN`, `langB = zh-TW`):
  1. `translatedText` has CJK → `A_TO_B` (Vietnamese spoken → Chinese output)
  2. `sourceText` has CJK → `B_TO_A` (Chinese spoken → Vietnamese output)
  3. `translatedText` has Vietnamese diacritics → `B_TO_A`
  4. `sourceText` has Vietnamese diacritics → `A_TO_B`
- For `vi_en` (`langA = vi-VN`, `langB = en-US`):
  1. `translatedText` has Vietnamese diacritics & `sourceText` does not → `B_TO_A` (English spoken → Vietnamese output)
  2. `sourceText` has Vietnamese diacritics & `translatedText` does not → `A_TO_B` (Vietnamese spoken → English output)

### 5.5 Dedicated Audio Transcription Studio (`transcribeAudioWav`)
- Sends normalized `audio/wav` to `getStructuredTranscribeModel(candidateModel)` with `structuredTranscribeSchema`:
  ```json
  {
    "detectedLanguage": "vi-VN | en-US | zh-TW | SILENCE",
    "transcript": "Complete verbatim transcription",
    "translation": "Natural translation into the other language of the active pair"
  }
  ```
- If structured JSON returns empty on a model, attempts a secondary plain-text transcription call on the same model before moving to the next fallback model.

### 5.6 Session Warm-Up, Renewal & Exponential Backoff (`ReconnectPolicy`)
- **Warm-Up**: When entering `ConversationScreen`, `warmUpSession()` marks `isSessionWarm = true` and records `sessionOpenedElapsedMs`.
- **Proactive 9-Minute Renewal**: Live sessions have a 10-minute server limit. `shouldRenewSession()` checks if `now - sessionStartedElapsedMs >= 9 * 60 * 1000 ms` (`540s`) and seamlessly renews the session counter (`sessionRenewalsCount++`).
- **Exponential Backoff**: `baseDelayMs = 400 ms`, `maxDelayMs = 12,000 ms`, `maxAttempts = 6` (`400ms, 800ms, 1600ms, 3200ms, 6400ms, 12000ms`).

---

## 6. Core Module 4: Data Layer, Cloud Firestore & Security Rules

### 6.1 Cloud Firestore Schema & Security Rules (`firestore.rules`)
All Firestore paths require Google Sign-In (`request.auth != null && request.auth.uid == userId`). Zero audio or transcript fields exist in Firestore.

#### Collection 1: `/users/{userId}` (`UserSettingsProfile`)
| Field | Type | Validation Rule in `firestore.rules` | Default |
| :--- | :--- | :--- | :--- |
| `userId` | `string` | `size 1..128`, `== request.auth.uid`, immutable on update | UID |
| `preferredPairId` | `string` | `in ['vi_en', 'vi_zhtw']` | `"vi_en"` |
| `interactionMode` | `string` | `in ['AUTO', 'TWO_BUTTON']` | `"AUTO"` |
| `subtitlesEnabled` | `bool` | `is bool` | `false` |
| `echoGatingTailMs` | `int` | `100 <= val <= 1500` | `320` |
| `vadSilenceMs` | `int` | `150 <= val <= 2000` | `400` |
| `vadSensitivityPct` | `int` | `1 <= val <= 100` | `65` |
| `volumeBoostDb` | `int` | `0 <= val <= 12` | `3` |
| `createdAt` | `timestamp` | `<= request.time`, immutable on update | `FieldValue.serverTimestamp()` |
| `updatedAt` | `timestamp` | `<= request.time` | `FieldValue.serverTimestamp()` |

#### Subcollection 2: `/users/{userId}/daily_quotas/{dateKey}` (`DailyUsageQuota`)
- `dateKey`: UTC date string in `YYYY-MM-DD` format (`^[0-9]{4}-[0-9]{2}-[0-9]{2}$`).
- **Monotonic Counter Enforcement**: On `update`, `firestore.rules` strictly enforces that counters can never decrease:
  - `incoming().audioSecondsUsed >= existing().audioSecondsUsed` (`0..86400`)
  - `incoming().sessionsCount >= existing().sessionsCount` (`0..10000`)
  - `incoming().transcribeCount >= existing().transcribeCount` (`0..50000`)
  - `dailyCapSeconds`: `60..86400` (default `3600` seconds = 60 minutes/day).

### 6.2 Local Preferences & Hardware-Backed AES-256-GCM History (`LocalPreferencesManager`)
- **Client Preferences (`LocalAppPreferences`)**:
  - `uiLanguage`: `VIETNAMESE` (default) or `ENGLISH`
  - `preferredPairId`: `"vi_en"` (default) or `"vi_zhtw"`
  - `interactionMode`: `AUTO` (default) or `TWO_BUTTON`
  - `subtitlesEnabled`: `false` (default)
  - `echoGatingTailMs`: `320L` (`100..1500`)
  - `vadSilenceMs`: `400L` (`150..2000`)
  - `vadSensitivityPct`: `65` (`1..100`)
  - `volumeBoostDb`: `3` (`0..12`)
  - `subtitleFontSizeSp`: `20` (`14..32`)
  - `keepScreenOn`: `true`
  - `saveEncryptedHistory`: `false` (default OFF)
  - `hasAcceptedPrivacyConsent`: `false`
  - `showDebugOverlay`: `false`
  - `twoSessionFixedAbMode`: `false`
  - `allowBargeIn`: `false`
  - `liveModelName`: `"gemini-3.5-live-translate"`
  - `transcribeModelName`: `"gemini-3.5-transcribe-live"`
  - `dailyCapSeconds`: `3600L` (`60..14400`)
  - `maxRequestsPerMinute`: `60` (`5..120`)
- **On-Device Encrypted History (`SavedHistoryTurn`)**:
  - Only written when `saveEncryptedHistory == true`. Capped at the **most recent 50 turns**.
  - Toggling `saveEncryptedHistory` to `false` or tapping **Delete All Local Data** immediately wipes the encrypted ciphertext blob.
  - **Encryption Format**: `AES/GCM/NoPadding` with a 256-bit key stored in hardware Keystore/Keychain (`alias = "ai_translator_history_aes_key"`), serialized as `base64(iv):base64(ciphertext + tag)`.

### 6.3 Cloud Functions Backend (`functions/src/index.ts`)
1. `mintEphemeralLiveToken` (`onCall`, region `asia-northeast1`, `enforceAppCheck: true`):
   - Verifies Firebase Auth UID and checks `/users/{uid}/daily_quotas/{dateKey}`.
   - If `audioSecondsUsed >= dailyCapSeconds`, throws `resource-exhausted`.
   - Mints a short-lived (300s) OAuth2 access token for fallback WebSocket `BidiGenerateContent` connections.
2. `onBudgetAlertKillSwitch` (`onMessagePublished`, topic `billing-budget-alerts`):
   - Listens to Google Cloud Billing budget alerts. If `costAmount >= budgetAmount`, automatically publishes `kill_switch_active = true` to Firebase Remote Config.

---

## 7. Complete UI/UX & Design System Specification

### 7.1 Color Palette (`Color.kt` & `Theme.kt`)

| Role | Dark Theme (Default) | Light Theme |
| :--- | :--- | :--- |
| **Background** | `DeepNavy` (`#0B132B`) | `LightBackground` (`#F6F8FC`) |
| **Surface** | `SurfaceNavy` (`#141E3C`) | `LightSurface` (`#FFFFFF`) |
| **Surface Variant / Cards** | `CardNavy` (`#1C284E`) | `LightCard` (`#EEF2F9`) |
| **Elevated Surface** | `ElevatedNavy` (`#253463`) | — |
| **Primary (Speaker A / VI)** | `ElectricCyan` (`#00E5FF`) | `PrimaryCyanLight` (`#007A8C`) |
| **Primary Container** | `CyanContainer` (`#003B46`) | `#D6F7FF` |
| **Secondary (Speaker B / EN / ZH)** | `WarmCoral` (`#FF6B4A`) | `SecondaryCoralLight` (`#D94726`) |
| **Secondary Container** | `CoralContainer` (`#4F190D`) | `#FFDBD2` |
| **Tertiary (Translating)** | `AmberGold` (`#FFC400`) | `#B28900` |
| **Success / Accent** | `JadeMint` (`#00E676`) | — |
| **Error / Muted / Stop** | `ErrorCrimson` (`#FF5252`) | `#D32F2F` |
| **On Background / Surface** | `#F2F6FF` | `DeepInk` (`#0D1528`) |
| **On Surface Variant** | `#B8C5E0` | `#44526E` |

### 7.2 Typography (`Type.kt`)
Uses 3 bundled Google Fonts:
1. **Space Grotesk** (Headings & Display):
   - `displayLarge`: `36sp`, Bold, lineHeight `44sp`, letterSpacing `-0.5sp`
   - `headlineLarge`: `28sp`, Bold, lineHeight `34sp`
   - `headlineMedium`: `22sp`, SemiBold, lineHeight `28sp`
   - `titleLarge`: `19sp`, Bold, lineHeight `26sp`
2. **Plus Jakarta Sans** (Body & UI Controls):
   - `titleMedium`: `16sp`, SemiBold, lineHeight `22sp`
   - `bodyLarge`: `16sp`, Normal, lineHeight `24sp`
   - `bodyMedium`: `14sp`, Normal, lineHeight `20sp`
   - `labelLarge`: `14sp`, SemiBold, lineHeight `20sp`
3. **JetBrains Mono** (Telemetry, Badges & Timestamps):
   - `labelSmall`: `11sp`, Medium, lineHeight `16sp`

---

### 7.3 Screen-by-Screen Breakdown

#### Screen 1: `AuthScreen` (Google Sign-In Gate)
- **Behavior**: Automatically attempts silent credential sign-in on launch (`attemptAutoSignIn`).
- **Layout**:
  - Top-right `OutlinedButton` to toggle UI language (`Tiếng Việt • EN` ↔ `English • VI`).
  - Hero illustration banner (`200.dp` height, `24.dp` corner radius).
  - App title (`AI Translator` with `GraphicEq` icon) + bilingual subtitle.
  - Feature highlights card:
    - `Tiếng Việt (vi-VN) ↔ English (en-US) & 繁體中文 (zh-TW)`
    - `App Check Enforced • Loudspeaker Echo Gating • Zero Voice Retention`
  - Primary `56.dp` height **Sign in with Google** button with loading spinner and error banner display.

#### Screen 2: `HomeScreen` & `SettingsSheet`
- **First-Launch Privacy Consent Modal**: Non-dismissible `AlertDialog` explaining Zero Voice Retention, App Check attestation, Taiwan Mandarin (`繁體中文`) enforcement, and automatic background microphone cutoff.
- **Top App Bar**:
  - Title + `VI / EN` language toggle button + `BugReport` Debug Overlay toggle icon + `Settings` gear icon.
- **Main Scrollable Content (`maxWidth = 600.dp`)**:
  1. **Hero Banner Card**: `132.dp` height image + app tagline.
  2. **Microphone Permission Status Banner**: Shows ready state (`Microphone Ready • Hardware AEC & Echo Gate Active`) or interactive prompt banner if permission is missing.
  3. **Language Pair Selector Cards**:
     - `pair_card_vi_en`: `Tiếng Việt ↔ Tiếng Anh (Mỹ)` (`VI ↔ EN`)
     - `pair_card_vi_zhtw`: `Tiếng Việt ↔ Tiếng Trung Phồn Thể (Đài Loan)` (`VI ↔ 繁中(TW)`)
  4. **Interaction Mode Selector (2-Column Row)**:
     - `mode_auto_card`: **Auto Mode (Continuous VAD + Echo Gate)** (Primary Cyan border when selected).
     - `mode_two_button_card`: **Two-Button Mode (180° Face-to-Face)** (Secondary Coral border when selected).
  5. **Optional Two-Sided Subtitles Switch Card**: Default `OFF`.
  6. **Primary CTA Button (`60.dp` height)**: **Start Live Interpreter Session** → warms up `GeminiLiveSessionClient`, increments daily session count, and navigates to `ConversationScreen`.
  7. **Secondary CTA Card**: **Audio Transcription (`gemini-3.5-transcribe-live`)** → navigates to `TranscribeStudioScreen`.
  8. **Daily Usage Quota Meter Card**: Shows `usedSec / capSec`, active Live and Transcribe model badges, and a `LinearProgressIndicator`.
  9. **Encrypted Local History Preview Card**: Shown only if `saveEncryptedHistory == true` and history is non-empty (displays latest 3 turns).
- **Modal Settings Bottom Sheet (`showSettingsSheet`)**:
  - Live Interpreter Model selector (`6` models with quota badges).
  - Transcribe Model selector (`6` models with quota badges).
  - Sliders:
    - **Daily Audio Safety Cap**: `300s..14400s` (`5m..240m`, default `3600s`)
    - **Max Requests Per Minute (RPM)**: `5..120 RPM` (default `60 RPM`)
    - **Loudspeaker Volume Boost**: `0..12 dB` (default `+3 dB`)
    - **Subtitle Font Size**: `14..32 sp` (default `20 sp`)
    - **Half-Duplex Echo Gating Tail**: `150..800 ms` (default `320 ms`)
    - **End-of-Speech VAD Silence**: `200..1200 ms` (default `400 ms`)
    - **VAD Voice Sensitivity**: `10..95%` (default `65%`)
  - Toggles:
    - **Keep Screen On During Session** (default `ON`)
    - **Save Encrypted Local History** (default `OFF`)
    - **2-Session Fixed Direction Mode (A/B Test)** (default `OFF`)
    - **Allow Barge-In While Speaking** (default `OFF`)
  - Footer Actions: **Delete All Local Data** (red destructive outlined button) + **Sign Out**.

#### Screen 3: `ConversationScreen` (180° Tabletop Split-Screen)
```text
+-------------------------------------------------------------------+
| [● MIC ACTIVE • LOUDSPEAKER ECHO GATE ON]         [CC]   [Debug]  |
+-------------------------------------------------------------------+
| (Optional DebugTelemetryOverlay: TTFT, RTT, p50, p90, RMS, Cost)  |
+-------------------------------------------------------------------+
|  +-------------------------------------------------------------+  |
|  |         PARTNER B ZONE (ROTATED 180° UPSIDE DOWN)           |  |
|  |  • Optional SubtitleCard (Lang B primary, Lang A secondary) |  |
|  |    with one-tap TTS Replay icon button                      |  |
|  |  • (If TWO_BUTTON mode): Large Coral Talk Button (B -> A)   |  |
|  +-------------------------------------------------------------+  |
+-------------------------------------------------------------------+
|  +-------------------------------------------------------------+  |
|  |        CENTER STATUS & 24-BAND ACOUSTIC WAVEFORM HUB        |  |
|  |  • Dynamic GatePhase Icon & Animated Color Status Label     |  |
|  |  • 24-Bar Real-Time Canvas Waveform                         |  |
|  |  • (If AUTO mode): Manual Tap-to-Record / Stop-and-Translate|  |
|  |    override button for soft-spoken environments             |  |
|  +-------------------------------------------------------------+  |
+-------------------------------------------------------------------+
|  +-------------------------------------------------------------+  |
|  |              PARTNER A ZONE (UPRIGHT 0° NORMAL)             |  |
|  |  • Optional SubtitleCard (Lang A primary, Lang B secondary) |  |
|  |    with one-tap TTS Replay icon button                      |  |
|  |  • (If TWO_BUTTON mode): Large Cyan Talk Button (A -> B)    |  |
|  +-------------------------------------------------------------+  |
+-------------------------------------------------------------------+
|  [       Mute / Unmute Mic       ]   [       End Session       ]  |
+-------------------------------------------------------------------+
```
- **Key UX Behaviors**:
  - **Keep Screen On**: Active while on `ConversationScreen` if `prefs.keepScreenOn == true`.
  - **Immediate Background Cutoff**: Observing `ON_STOP` (or `.background` on iOS) immediately halts microphone capture and loudspeaker playback.
  - **Subtitle Highlighting & Auto-Scroll**: When `direction == A_TO_B`, Partner B's card is highlighted and displays the translated text in large bold font (`fontSizeSp`) with the original source text underneath (`fontSizeSp - 3`), while Partner A's card shows what Partner A said. Each card includes a speaker icon to replay the utterance via TTS.
  - **Debug Telemetry Overlay**: Displays live `Warm`, `GatePhase`, `t_end_speech`, `t_first_audio`, `TTFT`, `RTT`, `p50` (`<1200ms` target), `p90` (`<2000ms` target), `droppedChunks`, `reconnects`, `HW AEC/NS/AGC`, `AudioRoute`, `RMS dBFS`, and `Estimated Cost ($0.008/min)`.

#### Screen 4: `TranscribeStudioScreen`
- Dedicated push-to-record transcription & translation studio:
  - Quick 2-column model switcher chip grid (`gemini-3.5-transcribe-live`, `gemini-3.5-live-translate`, `gemini-3-flash-live`, `gemini-3.8-live`, `gemini-3.1-flash-lite-preview`, `gemini-3.5-transcribe`).
  - Live 24-band waveform visualizer card (`56.dp` height).
  - Result card showing `Detected language tag • Latency ms • Model used`, **Speak Transcript** button (TTS), **Copy Transcript** button (copies both transcript and translation to clipboard), primary verbatim transcript (`headlineMedium`), and secondary translation box (`secondaryContainer`).
  - If recording is `< 150 ms` or silent, displays a diagnostic hint including the measured peak microphone level in `dBFS`.

---

## 8. Bilingual Localization Dictionary (`I18nStrings.kt`)

The entire UI supports instant in-app switching between **Vietnamese (`vi`)** and **English (`en`)** without restarting the app. On iOS, bind a `@Observable` or environment-injected `AppStrings` struct selected via `BilingualStrings.forLang(prefs.uiLanguage)`.

---

## 9. iOS Implementation Checklist for Senior Engineers

1. **Firebase Project & App Check**:
   - Download `GoogleService-Info.plist` from the same Firebase project.
   - Register `AppAttestProvider` (Release) and `AppCheckDebugProviderFactory` (Debug/Simulator) **before** `FirebaseApp.configure()`.
2. **Audio Session Configuration (`AVAudioSession`)**:
   ```swift
   let session = AVAudioSession.sharedInstance()
   try session.setCategory(
       .playAndRecord,
       mode: .default,
       options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
   )
   try session.setPreferredSampleRate(16000)
   try session.setPreferredIOBufferDuration(0.030) // 30ms frames
   try session.setActive(true)
   ```
3. **16 kHz Mono PCM16 Tap (`AVAudioEngine`)**:
   - Install a tap on `engine.inputNode`, convert buffers to `AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)` using `AVAudioConverter`, slice into 480-sample (`960-byte`) chunks, compute `calculateRmsDb`, and feed `EchoGateStateMachine.onAudioFrame(rmsDb, nowElapsedMs)`.
4. **180° Tabletop Rotation in SwiftUI**:
   - Apply `.rotationEffect(.degrees(180))` to the top `PartnerBZone` container inside `ConversationScreen`.
5. **Keychain + CryptoKit History Encryption**:
   - Generate a `SymmetricKey(size: .bits256)` stored in the iOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) and seal/open the JSON array of `SavedHistoryTurn` using `AES.GCM.seal(plainData, using: key)`.
