# UltimateCoach

An offline iPhone and iPad app for following a 12-week strength program, logging workouts, and reviewing progress.

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
- **Program** shows all 12 weeks. Open a planned workout to set target weights, start, reschedule, or skip it.
- **Workout** separates targets, saved sets, and conditioning. Enter or adjust weight, log reps, optionally record reps in reserve, and finish when done. The rest timer follows the active session. Seed loads are examples. Next-workout targets explain why they changed.
- **Progress** shows workout history and trends for logged exercises. Open a workout to correct individual sets.
- **Settings** sets weight units and increments, moves upcoming sessions, and exports or restores workout backups. Backups include plan and workout data. Preferences are stored separately.

Auto-periodization, scheduled deloads, and automatic conditioning progression are planned. See the [audit and revival plan](docs/REVIVAL_PLAN.md) for design decisions and delivery stages.

## Layout

- `UltimateCoach/Features/` contains the SwiftUI screens and shared visual styles.
- `UltimateCoach/Engine/` contains progression, units, phase, and conditioning helpers.
- `UltimateCoach/Models/` and `UltimateCoach/Persistence/` contain the SwiftData models, workout writes, seed, and backup code.
- `UltimateCoachTests/` and `UltimateCoachUITests/` cover engine behavior, data round trips, and user flows. The UI tests use an in-memory store through the `--ui-testing` launch argument.
