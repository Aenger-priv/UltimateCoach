import CoreBluetooth
import SwiftUI

struct RowErgSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let conditioning: Conditioning
    let prescription: RowingPrescription?
    @State private var minutes: Int
    @State private var connection = PM5Connection()
    @State private var manualExpanded = false

    init(conditioning: Conditioning) {
        self.conditioning = conditioning
        let parsed = RowingPrescription(conditioning.protocolText)
        prescription = parsed
        let range = parsed?.minuteRange
        let preferred = conditioning.durationMin ?? range?.lowerBound ?? 0
        _minutes = State(initialValue: range?.contains(preferred) == true ? preferred : range?.lowerBound ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(conditioning.protocolText).font(.title3.bold())
                        if let range = prescription?.minuteRange, range.lowerBound < range.upperBound {
                            Stepper("Duration · \(minutes) min", value: $minutes, in: range)
                                .disabled(connection.state == .connecting || connection.state == .sending)
                                .onChange(of: minutes) { connection.stop() }
                        }
                        if let workout = prescription?.workout(minutes: minutes) {
                            if prescription?.minuteRange == nil {
                                Text(workout.summary).foregroundStyle(CoachStyle.muted)
                            }
                        }
                        if let pace = conditioning.targetPace { Text("Pace cue · \(pace)") }
                        if let zone = conditioning.targetZone { Text("Effort cue · \(zone)") }
                    }
                    .coachCard()
                    if let workout = prescription?.workout(minutes: minutes) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Send to a PM5", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.headline).accessibilityAddTraits(.isHeader)
                            connectionControls(workout)
                        }
                        .coachCard()
                        DisclosureGroup("Set up manually", isExpanded: $manualExpanded) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("On the PM5, open Select Workout → New Workout. In ErgData, open Workout → Create.")
                                Text("Choose \(workout.manualMode.lowercased()) and enter \(workout.summary).")
                                if case .intervals = workout {
                                    Text("Set the last rest to zero so the workout ends after the final effort.")
                                }
                            }
                            .font(.subheadline).foregroundStyle(CoachStyle.muted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                        }
                        .coachCard()
                    } else {
                        Text("Use the prescription above to create this workout in ErgData or on the PM5 under Select Workout → New Workout.")
                            .coachCard()
                    }
                }.coachPage()
            }
            .coachBackground()
            .navigationTitle("RowErg setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onDisappear { connection.stop() }
    }

    @ViewBuilder private func connectionControls(_ workout: RowingWorkout) -> some View {
        switch connection.state {
        case .idle, .failed:
            if case let .failed(message) = connection.state {
                Text(message).foregroundStyle(CoachStyle.muted)
            } else {
                Text("Open Connect on your RowErg monitor. Choose its number here to load your targets.")
                    .foregroundStyle(CoachStyle.muted)
            }
            Button("Find a PM5", systemImage: "magnifyingglass") { connection.search() }
                .buttonStyle(CoachActionStyle())
        case .searching:
            if connection.monitors.isEmpty {
                SwiftUI.ProgressView("Searching for nearby monitors…")
            } else {
                Text("Choose the number shown on your RowErg to send the workout.").foregroundStyle(CoachStyle.muted)
                ForEach(connection.monitors, id: \.identifier) { monitor in
                    Button(monitor.name ?? "PM5 · \(monitor.identifier.uuidString.suffix(4))") {
                        connection.send(workout, to: monitor)
                    }
                    .buttonStyle(CoachActionStyle(primary: false))
                }
            }
            Button("Cancel search") { connection.stop() }
        case .connecting: SwiftUI.ProgressView("Connecting to PM5…")
        case .sending: SwiftUI.ProgressView("Setting up the workout…")
        case .ready:
            Label("Workout loaded", systemImage: "checkmark.circle.fill").font(.headline)
                .foregroundStyle(CoachStyle.accent)
            Text("Check the target on your monitor and start rowing. Log your result in Conditioning after the row.")
                .foregroundStyle(CoachStyle.muted)
        }
    }
}
