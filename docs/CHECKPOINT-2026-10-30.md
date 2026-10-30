# Mac wipe preservation checkpoint — 2026-10-30

Scope: repository preservation only. Further development, installation, recording, inference and repair are paused. This checkpoint does not authorize replaying native actions, permission grants, workflow execution or deployment.

## Preserved source

Repository: https://github.com/adroiteck/local-meeting (public, explicitly requested by the owner).

Checkpoint branch: `checkpoint/mac-wipe-2026-10-30`.

Starting source commit: `5f99665c4417b473d87f750378f2c9895d073194` on `main`, verified present on the remote before this checkpoint.

All project-owned source, installer/build scripts, dependency/model locks, tests, plan, README and prior validation documentation were already tracked with no outstanding tracked changes or untracked nonignored drafts at checkpoint inspection. This branch adds this sanitized handoff; no other chat's files were changed. This is a dedicated project repository, with no shared dirty paths observed. No tests, application actions, model runs or infrastructure changes were performed for this checkpoint.

## Completed versus unverified

Implemented: native SwiftUI meeting UI; microphone/system-audio capture code; audio import and conversion; local Whisper transcription; local Qwen extraction with transcript references; conservative evidence checks; network-denied processing; pinned model/source installer; source-only packaging and CLI recovery paths. Source was previously pushed and the repository made public at the owner's request.

Prior validation is recorded in `VALIDATION.md` (2026-10-29), including actual synthetic audio inference, native UI import, network-denial checks, repeated installation and multiple-chunk extraction. These are historical test results, not fresh verification on the destination Mac. The current checkpoint did not rerun them.

Held/unverified: live microphone and system-audio permission/capture flows; a real Teams/Zoom meeting; physical two-track alignment; device changes, sleep interruption and long recordings; performance or memory acceptance on an 8 GB/Intel Mac. No claim of complete production readiness or byte-identical cross-Mac builds. AI notes remain drafts; source-quote matching does not prove semantic correctness.

## Local-only preservation gap

The following remain outside Git and were not copied, deleted or uploaded:

- `~/Library/Application Support/Local Meeting/meetings/`: app-created recordings/imports, transcripts, notes, prompts and logs. Treat the entire directory as private regardless of synthetic test history.
- Project-local ignored `data/`: test or meeting evidence, transcripts and model outputs. Do not assume all contents are safe to publish.
- `.runtime/`: downloaded models, engine checkouts/builds, install manifest and possible processing lock state.
- `.cache/`: installer download cache.
- `.install.log`, `.smoke.log` and `local-meeting-source.tar.gz`: local build/test logs and generated source package. The existing archive may lag subsequent README changes; it is not the authoritative checkpoint.
- `~/Applications/Local Meeting.app`: generated, machine-specific installed application.
- Prior synthetic smoke-test artifacts under `/tmp/local-meeting-smoke.*` and `/tmp/local-meeting-silence-test`, if still present. Temporary directories are not durable preservation.

A Mac wipe can remove these local artifacts. Source preservation does not preserve meeting history or local test evidence. No private-artifact backup/readback/restore proof exists in this checkpoint; a separate explicitly authorized private backup is required if those artifacts must survive. No artifact data movement is released by this handoff. Public models, engine builds and the app are intended to be recreated from source, subject to network access and host tooling availability.

## Exact next steps after explicit resume

1. Clone the repository into a local nonsynchronized directory and check out `checkpoint/mac-wipe-2026-10-30`. Verify the remote checkpoint commit against the SHA reported with the handoff.
2. Read `README.md`, `lock.json` and `VALIDATION.md`. Determine the destination Mac's OS, chip, memory and available disk. The initial profile requires macOS 15+ and English speech; 8 GB is a design target, not measured acceptance.
3. When installation is authorized, run `./install.sh`. Initial public dependency/model downloads require Internet access and Apple Command Line Tools; compile/framework/Python dependencies remain host-owned. Keep the source directory in place because the installed app records its location.
4. Run `./install.sh --verify`. Only after test execution is authorized, run the documented unit checks and `./scripts/smoke.sh`; inspect failures without bypassing hooks or changing the lock opportunistically.
5. Explicitly authorize a short permitted test recording. Grant microphone and system-audio permissions on that Mac, then verify both raw tracks, transcription and timestamp alignment before actual work meetings. Do not auto-grant or assume prior Mac permissions transfer.
6. Review generated deliverables, owners and deadlines against transcript evidence. No automatic external task-system, email, calendar or publishing actions are implemented or authorized.

## Expired and one-use boundaries

Permission grants, installed signatures, process IDs, local paths and runtime locks from this Mac are not portable acceptance evidence. Inspect any restored lock/PID before recovery; do not blindly remove it or replay a prior recording/import. No live recording was started during this checkpoint. Prior synthetic tests and GUI-import actions do not authorize recording new conversations. Resume only the explicitly requested next scope; otherwise remain paused.
