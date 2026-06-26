import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategory: DiagnosticCategory?
    @State private var selectedLevel: DiagnosticLevel?
    @State private var searchText = ""
    @State private var exportText = ""

    private var filteredEvents: [DiagnosticEvent] {
        appState.diagnosticsStore.events.filter { event in
            let categoryMatches = selectedCategory == nil || event.category == selectedCategory
            let levelMatches = selectedLevel == nil || event.level == selectedLevel
            let searchMatches = searchText.isEmpty
                || event.message.localizedCaseInsensitiveContains(searchText)
                || event.metadata.values.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return categoryMatches && levelMatches && searchMatches
        }
    }

    var body: some View {
        List {
            Section("Controls") {
                Toggle("Enable verbose diagnostics", isOn: $appState.config.isDiagnosticsVerbose)

                Button(role: .destructive) {
                    appState.diagnosticsStore.clear()
                    exportText = ""
                } label: {
                    Label("Clear logs", systemImage: "trash")
                }

                Button {
                    exportText = appState.diagnosticsStore.exportReport(config: appState.config, session: appState.session)
                } label: {
                    Label("Export diagnostics text", systemImage: "square.and.arrow.up")
                }
            }

            Section("Filters") {
                TextField("Search logs", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Picker("Category", selection: categoryBinding) {
                    Text("All").tag("all")
                    ForEach(DiagnosticCategory.allCases) { category in
                        Text(category.rawValue).tag(category.rawValue)
                    }
                }

                Picker("Level", selection: levelBinding) {
                    Text("All").tag("all")
                    ForEach(DiagnosticLevel.allCases) { level in
                        Text(level.rawValue).tag(level.rawValue)
                    }
                }
            }

            if let audit = appState.diagnosticsStore.latestProfileAudit {
                Section("Latest ProfileDecodeAudit") {
                    Text(audit.summaryText)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Section("Latest decoding errors") {
                let errors = appState.diagnosticsStore.events
                    .filter { $0.category == .decoding || $0.level >= .error }
                    .suffix(8)
                if errors.isEmpty {
                    Text("No decoding errors.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(errors)) { event in
                        DiagnosticEventRow(event: event)
                    }
                }
            }

            Section("Latest network responses") {
                let network = appState.diagnosticsStore.events
                    .filter { $0.category == .network }
                    .suffix(8)
                if network.isEmpty {
                    Text("No network events.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(network)) { event in
                        DiagnosticEventRow(event: event)
                    }
                }
            }

            Section("Events (\(filteredEvents.count))") {
                ForEach(Array(filteredEvents.reversed())) { event in
                    DiagnosticEventRow(event: event)
                }
            }

            if !exportText.isEmpty {
                Section("Export") {
                    Text(exportText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Diagnostics")
    }

    private var categoryBinding: Binding<String> {
        Binding {
            selectedCategory?.rawValue ?? "all"
        } set: { value in
            selectedCategory = value == "all" ? nil : DiagnosticCategory(rawValue: value)
        }
    }

    private var levelBinding: Binding<String> {
        Binding {
            selectedLevel?.rawValue ?? "all"
        } set: { value in
            selectedLevel = value == "all" ? nil : DiagnosticLevel(rawValue: value)
        }
    }
}

private struct DiagnosticEventRow: View {
    let event: DiagnosticEvent
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.level.rawValue.uppercased())
                    .font(.caption.weight(.bold))
                Text(event.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(event.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(event.message)
                .font(.subheadline)

            if let requestId = event.requestId {
                Text("requestId: \(requestId)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isExpanded {
                Text(event.metadata.map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isExpanded.toggle()
        }
    }
}
