import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("units_kg") private var unitsKg: Bool = true
    @AppStorage("barbell_inc") private var barbellInc: Double = 2.5
    @AppStorage("db_inc") private var dbInc: Double = 2.0
    @AppStorage("enable_rir") private var enableRIR: Bool = true
    @AppStorage("deload_cadence") private var deloadCadence: Int = 0 // 0 off, 4/5/6 weeks
    @AppStorage("auto_periodization") private var autoPeriodization: Bool = true

    @State private var exportURL: URL?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var importError: String?
    @State private var showingResetSheet = false
    @State private var resetDate: Date = Date()
    @State private var resetInProgress = false
    @State private var resetMessage: String?
    @State private var exportBeforeReset: Bool = true
    @State private var pendingResetStartDate: Date? = nil

    @State private var showingSoftRestartSheet = false
    @State private var softRestartDate: Date = Date()
    @State private var softRestartMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Units & Increments")) {
                    Toggle("Use kilograms", isOn: $unitsKg)
                    Stepper(value: $barbellInc, in: 0.5...5, step: 0.5) { Text("Barbell increment: \(barbellInc, specifier: "%.1f") kg") }
                    Stepper(value: $dbInc, in: 0.5...5, step: 0.5) { Text("Dumbbell increment: \(dbInc, specifier: "%.1f") kg") }
                }
                Section(header: Text("Training Options")) {
                    Toggle("Enable RIR input", isOn: $enableRIR)
                    Picker("Deload cadence", selection: $deloadCadence) {
                        Text("Off").tag(0)
                        Text("Every 4 weeks").tag(4)
                        Text("Every 5 weeks").tag(5)
                        Text("Every 6 weeks").tag(6)
                    }
                    Toggle("Auto periodization", isOn: $autoPeriodization)
                }
                Section(header: Text("Data")) {
                    Button("Export JSON") { exportData() }
                    Button("Import JSON") { showingImporter = true }
                        .tint(.blue)
                    Button { showingSoftRestartSheet = true } label: {
                        Label("Soft Restart…", systemImage: "calendar.badge.clock")
                    }
                    Button(role: .destructive) { showingResetSheet = true } label: {
                        Label("Reset Program…", systemImage: "arrow.counterclockwise")
                    }
                }
                if let err = importError { Text(err).foregroundStyle(.red) }
                if let msg = resetMessage { Text(msg).foregroundStyle(.green) }
                if let sMsg = softRestartMessage { Text(sMsg).foregroundStyle(.green) }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingExporter, onDismiss: {
                exportURL = nil
                if let startDate = pendingResetStartDate {
                    Task { await resetProgram(startDate: startDate) }
                    pendingResetStartDate = nil
                }
            }) {
                if let url = exportURL { ShareSheet(activityItems: [url]) }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        let data = try Data(contentsOf: url)
                        try ExportImport.importJSON(data, context: context)
                    } catch { importError = "Import failed: \(error.localizedDescription)" }
                case .failure(let err):
                    importError = "Import failed: \(err.localizedDescription)"
                }
            }
            .sheet(isPresented: $showingResetSheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Start Over")
                            .font(.title2).bold()
                        Text("This deletes current program data and seeds a fresh 12‑week plan starting on the selected date.")
                            .foregroundStyle(.secondary)
                        DatePicker("New start date", selection: $resetDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        Toggle("Export a backup before reset", isOn: $exportBeforeReset)
                        HStack {
                            Button("Cancel") { showingResetSheet = false }
                            Spacer()
                            Button(role: .destructive) {
                                if exportBeforeReset {
                                    do {
                                        let url = try prepareExport()
                                        exportURL = url
                                        pendingResetStartDate = resetDate
                                        showingResetSheet = false
                                        showingExporter = true
                                    } catch {
                                        importError = "Backup export failed: \(error.localizedDescription). Proceeding with reset."
                                        Task { await resetProgram(startDate: resetDate) }
                                    }
                                } else {
                                    Task { await resetProgram(startDate: resetDate) }
                                }
                            } label: {
                                Label("Reset", systemImage: "trash")
                            }
                            .disabled(resetInProgress)
                        }
                    }
                    .padding()
                    .toolbar { if resetInProgress { ProgressView() } }
                }
            }
            .sheet(isPresented: $showingSoftRestartSheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Soft Restart")
                            .font(.title2).bold()
                        Text("Shift the program start date without deleting your past logs.")
                            .foregroundStyle(.secondary)
                        DatePicker("New start date", selection: $softRestartDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        HStack {
                            Button("Cancel") { showingSoftRestartSheet = false }
                            Spacer()
                            Button {
                                Task { await softRestart(startDate: softRestartDate) }
                            } label: {
                                Label("Apply", systemImage: "calendar")
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func exportData() {
        do {
            exportURL = try prepareExport()
            showingExporter = true
        } catch {
            importError = "Export failed: \(error.localizedDescription)"
        }
    }

    private func prepareExport() throws -> URL {
        let data = try ExportImport.exportJSON(context: context)
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let name = "UltimateCoach_Export_\(df.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    private func resetProgram(startDate: Date) async {
        resetInProgress = true
        defer { resetInProgress = false }
        // Purge existing data in safe order
        do {
            try deleteAll(ExerciseLog.self)
            try deleteAll(DayExercise.self)
            try deleteAll(Conditioning.self)
            try deleteAll(DayPlan.self)
            try deleteAll(ProgressionRule.self)
            try deleteAll(PhaseState.self)
            try deleteAll(ExerciseTemplate.self)
            try deleteAll(Program.self)
            try context.save()
        } catch {
            importError = "Reset cleanup failed: \(error.localizedDescription)"
            return
        }
        await SeedData.seedIfNeeded(context: context, overrideStartDate: Calendar.current.startOfDay(for: startDate))
        resetMessage = "Program reset to \(DateFormatter.localizedString(from: startDate, dateStyle: .medium, timeStyle: .none))."
        showingResetSheet = false
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        items.forEach { context.delete($0) }
    }

    private func softRestart(startDate: Date) async {
        do {
            let programs = try context.fetch(FetchDescriptor<Program>())
            guard let program = programs.first else {
                importError = "No program to adjust."
                return
            }
            program.startDate = Calendar.current.startOfDay(for: startDate)
            // Recompute DayPlan dates relative to new start
            let programID = program.persistentModelID
            let ds = try context.fetch(FetchDescriptor<DayPlan>(predicate: #Predicate<DayPlan> { $0.program.persistentModelID == programID }))
            for d in ds {
                d.date = SeedData.computeDate(start: program.startDate, weekIdx: d.weekIdx, dayIdx: d.dayIdx)
            }
            try context.save()
            softRestartMessage = "Start date shifted to \(DateFormatter.localizedString(from: startDate, dateStyle: .medium, timeStyle: .none))."
            showingSoftRestartSheet = false
        } catch {
            importError = "Soft restart failed: \(error.localizedDescription)"
        }
    }
}

// Simple UIActivityViewController wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
