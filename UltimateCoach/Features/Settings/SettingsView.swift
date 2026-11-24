import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("adaptive_rest") private var adaptiveRest = false
    @Environment(\.modelContext) private var context
    @Query private var programs: [Program]
    @AppStorage("units_kg") private var unitsKg = true
    @AppStorage("barbell_inc") private var barbellInc = 2.5
    @AppStorage("db_inc") private var dbInc = 2.0
    @AppStorage("enable_rir") private var enableRIR = true
    @AppStorage("rest_whistle") private var restWhistle = false
    @State private var requestingNotifications = false
    @State private var backup: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingImport: Data?
    @State private var importName = ""
    @State private var confirmingImport = false
    @State private var message: String?
    @State private var shiftingProgram: Program?

    var body: some View {
        NavigationStack {
            Form {
                Section("Units & increments") {
                    Picker("Weight unit", selection: $unitsKg) {
                        Text("Kilograms").tag(true)
                        Text("Pounds").tag(false)
                    }
                    Stepper("Barbell: \(WeightUnit.formatted(barbellInc, useKilograms: unitsKg))",
                            value: $barbellInc, in: 0.5...5, step: 0.5)
                    Stepper("Dumbbell: \(WeightUnit.formatted(dbInc, useKilograms: unitsKg))",
                            value: $dbInc, in: 0.5...5, step: 0.5)
                    Text("Increments are stored in kilograms; pounds show the equivalent.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Logging") {
                    Toggle("Show reps in reserve", isOn: $enableRIR)
                    Text("Record how many more reps you could have completed.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Toggle("Adaptive rest suggestions", isOn: $adaptiveRest)
                    Text("After a hard set, the timer can suggest 30 extra seconds. It learns from your next logged set. Tap to add the time.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Toggle("Whistle when rest ends", isOn: Binding(get: { restWhistle }, set: setWhistle))
                        .disabled(requestingNotifications)
                    Button("Preview whistle", systemImage: "speaker.wave.2") { RestWhistle.preview() }
                } header: {
                    Text("Rest timer")
                } footer: {
                    Text("The whistle uses your iPhone’s notification sound settings.")
                }
                if let program = programs.first(where: { !$0.isArchived }) {
                    Section("Program") {
                        Button("Move upcoming workouts", systemImage: "calendar") { shiftingProgram = program }
                    }
                }
                Section("Backup") {
                    Button("Export workout backup", systemImage: "square.and.arrow.up") {
                        do {
                            backup = BackupDocument(data: try ExportImport.exportJSON(context: context))
                            showingExporter = true
                        } catch { message = error.localizedDescription }
                    }
                    Button("Restore workout backup", systemImage: "square.and.arrow.down") { showingImporter = true }
                    Text("Includes your current cycle, past cycles, and saved sets. App preferences are not included. Export a backup before replacing your plan.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .coachBackground()
            .navigationTitle("Settings")
            .fileExporter(isPresented: $showingExporter, document: backup, contentType: .json,
                          defaultFilename: "UltimateCoach-backup") { result in
                switch result {
                case .success: message = "Backup saved."
                case .failure(let error): message = "Backup was not saved. " + error.localizedDescription
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    let program = try ExportImport.validatedProgram(data)
                    importName = program.name
                    pendingImport = data
                    confirmingImport = true
                } catch { message = "Backup could not be read. " + error.localizedDescription }
            }
            .confirmationDialog("Restore workout backup for \(importName)?", isPresented: $confirmingImport,
                                titleVisibility: .visible) {
                Button("Replace with backup", role: .destructive) {
                    guard let data = pendingImport else { return }
                    do {
                        try ExportImport.importJSON(data, context: context)
                        message = "Workout backup restored."
                    } catch { message = "Restore failed. " + error.localizedDescription }
                    pendingImport = nil
                }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text("This replaces your cycles and saved workouts. Export your current backup first if you want to keep them.")
            }
            .alert("UltimateCoach", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: { Text(message ?? "") }
            .sheet(item: $shiftingProgram) { ScheduleShiftSheet(program: $0) }
        }
    }

    private func setWhistle(_ enabled: Bool) {
        guard enabled else { restWhistle = false; return }
        requestingNotifications = true
        Task {
            defer { requestingNotifications = false }
            do {
                restWhistle = try await RestWhistle.authorize()
                if !restWhistle { message = "Allow notifications for UltimateCoach in iPhone Settings to use the whistle." }
            } catch {
                message = "Could not enable the whistle. " + error.localizedDescription
            }
        }
    }

}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
