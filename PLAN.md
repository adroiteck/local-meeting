# Local Meeting implementation

Approved outcome: local-only Mac meeting capture, transcription, deliverables and action items, installed here and reproducible via install.sh on another Mac. Dedicated repository; no changes to other apps or services.

1. Pin whisper.cpp, llama.cpp, CMake and two model artifacts in lock.json. Installer verifies SHA-256, builds isolated dependencies, installs app in project directory. Preconditions: macOS 15+, Command Line Tools, 8 GB RAM target (performance unverified). Verify repeat installation and --verify. Download failures stop installation; existing meeting data is never removed.
2. Native SwiftUI app captures system and microphone audio using ScreenCaptureKit, writing separate audio tracks. Permission requests occur only on explicit Record. Native AVFoundation conversion produces 16 kHz mono WAV. Verify build and import conversion; physical capture/permissions require user acceptance. Stop/recover retains raw tracks.
3. Python stdlib pipeline invokes pinned local CLI engines sequentially. Chunk long transcripts; JSON grammar and evidence checks constrain outputs. Store transcript, raw AI output, notes and provenance locally. Verify synthetic meeting and negative tests. Fail closed on invalid output, retain transcript.
4. Test installer, model integrity, real inference on generated synthetic speech, long-input splitting and validation. Record current-machine evidence. Do not claim real meeting capture or low-memory performance without observation.

No auto-start, network listener, remote API, calendar integration or publishing. Runtime offline sandbox denies network. Remove installed app/build/model directories to uninstall; data requires separate explicit removal.
