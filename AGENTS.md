# Repository Guidelines

This repository contains the UltimateCoach iOS app built with SwiftUI and XCTest.
Use this guide for structure, commands, and contribution practices.

## Project Structure & Module Organization
- App source: `UltimateCoach/` (e.g., `UltimateCoachApp.swift`, `ContentView.swift`).
- Assets: `UltimateCoach/Assets.xcassets`.
- Unit tests: `UltimateCoachTests/` (XCTest).
- UI tests: `UltimateCoachUITests/` (XCUITest).
- Prefer grouping files by feature as the app grows (e.g., `Features/Session/Views`, `Models`).

## Build, Test, and Development Commands
- Open in Xcode: `open UltimateCoach.xcodeproj`.
- Build (CLI): `xcodebuild -project UltimateCoach.xcodeproj -scheme UltimateCoach -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build`.
- Test (CLI): `xcodebuild -project UltimateCoach.xcodeproj -scheme UltimateCoach -destination 'platform=iOS Simulator,name=iPhone 15' test`.
- Run locally: prefer Xcode (select a simulator, then Run). Use the CLI only for CI or quick checks.

## Coding Style & Naming Conventions
- Swift, 4-space indentation; keep lines ≈120 chars.
- Types: UpperCamelCase (e.g., `SessionViewModel`); functions/vars: lowerCamelCase.
- One top-level type per file; filename matches type (e.g., `Item.swift` defines `Item`).
- Favor SwiftUI and value semantics; avoid force unwraps.
- Use `MARK:` for logical sections; prefer protocol-oriented design.

## Testing Guidelines
- Frameworks: XCTest (unit) and XCUITest (UI).
- Name tests descriptively: `test_<unitOfWork>_<expectedBehavior>()`.
- Place unit tests in `UltimateCoachTests` mirroring source structure.
- UI tests live in `UltimateCoachUITests` with clear flows and assertions.
- Aim for meaningful coverage of view models and critical flows.

## Commit & Pull Request Guidelines
- Commits: imperative mood, focused scope (e.g., `Add Item model and list`).
- Prefer small, logically grouped commits; reference issues when relevant.
- PRs include: purpose/summary, before/after screenshots for UI changes, test coverage/notes, and reproduction/validation steps.
- Ensure builds/tests pass (`xcodebuild ... test`) before requesting review.

## Security & Configuration Tips
- Do not commit secrets, signing assets, or DerivedData.
- Configuration via `Info.plist`; document any new keys in the PR.
- Keep assets optimized inside `Assets.xcassets` with clear names.



## Non-Negotiables
- Deterministic progression logic with tests.
- Clear separation of “Targets” vs “Logs.”
- Auto-periodization rules implemented as an explicit FSM.
- Accessibility: dynamic type, color-contrast safe.
- No surprise data deletion; migrations tested.

## Inputs/Artifacts
- PROGRAM_SEED JSON with the initial 12-week plan.
- progression_rules.json defining increments per equipment and deload thresholds.
- Unit test fixtures for main lifts.

## Output/Definition of Done
- App runs locally; “Today” loads from seed; logging a session computes and persists “Next Targets.”
- Tests: ≥80% coverage in engine; green E2E for a sample week.
- README with setup; Settings allow unit toggles and increments.

## Conventions
- Units default kg; increments 2.5 kg barbell, 1–2 kg dumbbells.
- 1RM estimate by Epley: 1RM = w * (1 + reps/30).
- RIR optional; if missing, assume RIR=2 for HYP, RIR=1 for STR.
- Phase switches logged in phase_states.
