# Validation — 2026-10-29

Test machine: Apple M4 Pro, 24 GB memory, macOS 27.0.1, Apple Swift 6.4 / macOS SDK 27.0, CLT Python 3.9.6. This is not a low-memory acceptance result.

Verified:

- Installer downloaded checksum-pinned CMake and models, compiled both locked engines, built the native SwiftUI app and AVFoundation converter, and signed the installed app in `~/Applications`.
- Repeated installation completed, reusing model downloads and pinned engine sources. `install.sh --verify` checks the installed manifest and model hashes.
- `codesign --verify --deep --strict` succeeded.
- Native UI launched; Import audio accepted synthetic AIFF, processed it locally, showed completion, and generated notes under `~/Library/Application Support/Local Meeting/meetings`.
- Network-denial test: connecting to public IP port 443 from the runtime sandbox raised PermissionError.
- Synthetic spoken meeting passed actual AVFoundation conversion → Whisper → Qwen inference. Acceptance checks found Alex/report/Friday, Maria/demo/Thursday, the pilot decision and the budget blocker with transcript evidence. `scripts/smoke.sh` reproduces this test with an installed Samantha voice.
- A separate 46-segment transcript spanned three inference chunks. The final chunk retained Jordan's checklist commitment, Monday deadline, and the decision to postpone launch.
- A silent WAV was skipped and processing exited nonzero with no speech recognized; original audio remained.
- Eight unit checks cover evidence validation, fabricated quotes, unsupported owners/dates, invalid segment references, malformed output, long Unicode segmentation, empty results, explicit blocker correction and timestamp formatting (some share a test).
- Shell syntax and Python compilation checks passed.

The small model initially misclassified tasks and channel labels. A simpler prompt with concrete examples improved the synthetic result; explicit blocker wording has a narrow deterministic correction. Notes remain drafts and these tests do not establish general accuracy. Evidence validation only verifies quote/field presence, not semantic entailment. The summary falls back to the first three supported notes if no overview is generated. Long inputs are chunked, not globally reconciled; conflicting or differently worded duplicate commitments may require review.

Observed inference allocations for the low-memory profile: ~1,060 MiB mapped model, 224 MiB KV cache, 303 MiB CPU compute buffer (plus other overhead). One short synthetic extraction generated ~44 tokens/second on this M4 Pro. This does not measure whole-system peak memory, battery use or performance on an 8 GB/Intel Mac. Runtime plus model/build files occupied ~1.6 GB; CMake download cache ~80 MB.

Not physically verified: microphone recording permission flow, system-audio recording permission flow, recording a live Teams/Zoom meeting, two-channel alignment against an actual call, device changes, sleep interruption, or long-duration recording. The app never began live recording during these tests. First use should be a short permitted test recording followed by listening to both raw tracks and checking transcript timing.

Byte-identical cross-Mac builds are not claimed: the destination OS, Apple SDK/compiler and Python come from the host. `lock.json` fixes downloaded dependencies and model artifacts. No production services, external task systems or meeting-platform settings were changed.
