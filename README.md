# UltimateCoach

UltimateCoach is an offline‑first iOS app (SwiftUI + SwiftData) for running a 12‑week strength + hypertrophy program with automatic HYP↔STR periodization, quick set logging, and simple progress tracking.

## Features
- Today: shows the scheduled day with exercises, targets, phase badge, and a fast inline logger with rest timer
- Progression Engine: deterministic pure functions for load/rep progression, deloads, pull‑ups, and rowing rules
- Progress: latest estimated 1RM and recent history (lists; charts optional)
- Settings: units (kg/lb), increments, periodization options, JSON export/import, reset/soft‑restart program
- Privacy: completely offline in v1 (no analytics or tracking)

## Requirements
- Xcode 16 (iOS 26 simulators) • iOS 17+ target runtime
- SwiftUI, SwiftData (ModelContainer provided in app)

## Quick Start
1) Open the project: `open UltimateCoach/UltimateCoach.xcodeproj`
2) Select an iOS 26 Simulator (e.g., iPhone 15) and Run.
3) On first launch, choose a start date (use Today or pick a historical date). Today will render Week 1 · Day 1.

## Build & Test (CLI)
- Build: `xcodebuild -project UltimateCoach/UltimateCoach.xcodeproj -scheme UltimateCoach -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Tests: `xcodebuild -project UltimateCoach/UltimateCoach.xcodeproj -scheme UltimateCoach -destination 'platform=iOS Simulator,name=iPhone 15' test`

## Project Layout
- `UltimateCoach/UltimateCoach/`
  - `App/`: app entry + SwiftData container
  - `Models/`: SwiftData @Model types (Program, DayPlan, Exercises, Logs…)
  - `Engine/`: pure progression logic (unit‑tested)
  - `Persistence/`: seed loader + JSON export/import
  - `Features/`: Today, Logger, Progress, Settings, Onboarding (SwiftUI)
  - `Resources/`: `program_seed.json`, rule defaults, assets
  - `UltimateCoachTests/`: engine + seed tests

## Export / Import
- Settings → Export JSON creates a shareable backup file; Import restores it.
- Reset Program starts over from a chosen date; Soft Restart shifts the schedule without deleting logs.

## Troubleshooting
- If Today shows “Loading program…”, try Settings → Reset Program (use today’s date). During development, Today includes a “Force Seed Now” button and debug line to verify counts.

## Roadmap
- Optional CloudKit sync (feature flag), richer charts, local reminders.
