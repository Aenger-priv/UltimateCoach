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

- **Today** opens the scheduled workout, resumes the active one, or lets you reschedule or skip a missed workout.
- **Program** shows 12 training weeks and a lighter Week 13. Rescheduling moves only the selected workout. Use **End program early** at the bottom of the tab to archive the current cycle and choose a fresh start.
- **Workout** puts **Log next set** within reach. Review the target and your previous set, adjust the prefilled weight and reps, then save. You can undo the latest set or move to the next exercise from the logger. Add 30 seconds or end rest from the timer bar. Use an exercise’s menu to swap it before logging. The finished workout shows saved work and upcoming weight changes.
- **Progress** shows workout history and trends for logged exercises. Charts show logged weights or bodyweight reps, with an optional estimated 1-rep max for weighted exercises. Deloads stay in history. Open a workout to correct individual sets.
- **Settings** sets weight units and increments, previews schedule moves, and exports or restores backups. The optional coach whistle under **Rest timer** uses iPhone notifications, including when the screen is locked. Preferences are stored separately from workout backups.

The rest whistle is a shortened, quieter edit of [Referee whistle blow, gymnasium.wav by SpliceSound](https://freesound.org/people/SpliceSound/sounds/218318/), released under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

Choose Hypertrophy or Strength before starting. After the deload, the app suggests the opposite track and lets you choose either one. See the [programming and research notes](docs/TRAINING_TRACKS.md) and [original revival audit](docs/REVIVAL_PLAN.md).

## Layout

- `UltimateCoach/Features/` contains the SwiftUI screens and shared visual styles.
- `UltimateCoach/Engine/` contains progression, units, phase, and conditioning helpers.
- `UltimateCoach/Models/` and `UltimateCoach/Persistence/` contain the SwiftData models, workout writes, seed, and backup code.
- `UltimateCoachTests/` and `UltimateCoachUITests/` cover engine behavior, data round trips, and user flows. The UI tests use an in-memory store through the `--ui-testing` launch argument.
