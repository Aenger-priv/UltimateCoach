# UltimateCoach

An offline iPhone and iPad app for following a strength or hypertrophy track, logging workouts, and reviewing progress.

## Run locally

Use Xcode 27.2 and an installed iOS Simulator. The app uses Swift 6 language mode and targets iOS/iPadOS 26 or later. It uses Apple frameworks and has no third-party packages.

From this repository directory:

```sh
open UltimateCoach.xcodeproj
xcodebuild -project UltimateCoach.xcodeproj -scheme UltimateCoach \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test
```

Use `xcrun simctl list devices available` to choose another installed simulator. The shared scheme runs unit and UI tests with coverage. `.xcode-version` records the verified toolchain.

## Use the app

- **Today** opens the scheduled workout or resumes the active one.
- **Program** shows 12 training weeks and a lighter Week 13. Rescheduling moves only the selected workout. Use **End program early** at the bottom of the tab to archive the current cycle and choose a fresh start.
- **Workout** separates targets, saved sets, and conditioning. Enter or adjust weight, log reps, optionally record reps in reserve, and finish when done. The rest timer follows the active session. Seed loads are examples. Next-workout targets explain why they changed.
- **Progress** shows workout history and trends for logged exercises. Charts show logged weights or bodyweight reps, with an optional estimated 1-rep max for weighted exercises. Deloads stay in history. Open a workout to correct individual sets.
- **Settings** sets weight units and increments, moves upcoming sessions, and exports or restores workout backups. Backups include the current cycle, archived cycles, and workout data. Preferences are stored separately.

Choose Hypertrophy or Strength before starting. After the deload, the app suggests the opposite track and lets you choose either one. See the [programming and research notes](docs/TRAINING_TRACKS.md) and [original revival audit](docs/REVIVAL_PLAN.md).

## Layout

- `UltimateCoach/Features/` contains the SwiftUI screens and shared visual styles.
- `UltimateCoach/Engine/` contains progression, units, phase, and conditioning helpers.
- `UltimateCoach/Models/` and `UltimateCoach/Persistence/` contain the SwiftData models, workout writes, seed, and backup code.
- `UltimateCoachTests/` and `UltimateCoachUITests/` cover engine behavior, data round trips, and user flows. The UI tests use an in-memory store through the `--ui-testing` launch argument.
