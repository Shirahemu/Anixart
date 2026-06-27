import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DiagnosticsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategory: DiagnosticCategory?
    @State private var selectedLevel: DiagnosticLevel?
    @State private var searchText = ""
    @State private var txtExportURL: URL?
    @State private var jsonlExportURL: URL?
    @State private var fullTraceBundleURL: URL?
    @State private var exportStatus = ""

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
                Toggle("Full Trace", isOn: $appState.config.isFullTraceEnabled)

                if let txtExportURL {
                    ShareLink(item: txtExportURL) {
                        Label("Share TXT logs", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        prepareTextExport()
                    } label: {
                        Label("Share TXT logs", systemImage: "square.and.arrow.up")
                    }
                }

                if let jsonlExportURL {
                    ShareLink(item: jsonlExportURL) {
                        Label("Share JSONL logs", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        prepareJSONLExport()
                    } label: {
                        Label("Share JSONL logs", systemImage: "square.and.arrow.up")
                    }
                }

                Button {
                    copySummary()
                } label: {
                    Label("Copy summary", systemImage: "doc.on.doc")
                }

                if let fullTraceBundleURL {
                    ShareLink(item: fullTraceBundleURL) {
                        Label("Export Full Trace Bundle", systemImage: "shippingbox")
                    }
                } else {
                    Button {
                        prepareFullTraceBundle()
                    } label: {
                        Label("Export Full Trace Bundle", systemImage: "shippingbox")
                    }
                }

                Button(role: .destructive) {
                    appState.diagnosticsStore.clear()
                    txtExportURL = nil
                    jsonlExportURL = nil
                    fullTraceBundleURL = nil
                    exportStatus = "Logs cleared."
                } label: {
                    Label("Clear logs", systemImage: "trash")
                }

                Button(role: .destructive) {
                    appState.diagnosticsStore.clear()
                    fullTraceBundleURL = nil
                    exportStatus = "Trace cleared."
                } label: {
                    Label("Clear Trace", systemImage: "trash.slash")
                }

                if !exportStatus.isEmpty {
                    Text(exportStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

        }
        .navigationTitle("Diagnostics")
        .task {
            prepareTextExport()
            prepareJSONLExport()
            prepareFullTraceBundle()
        }
    }

    private func prepareTextExport() {
        do {
            let report = appState.diagnosticsStore.exportTextReport(config: appState.config, session: appState.session)
            txtExportURL = try DiagnosticsExportService.makeTextFile(report: report)
            exportStatus = "TXT log file is ready to share."
        } catch {
            exportStatus = "TXT export failed: \(error.localizedDescription)"
        }
    }

    private func prepareJSONLExport() {
        do {
            let report = appState.diagnosticsStore.exportJSONL(config: appState.config, session: appState.session)
            jsonlExportURL = try DiagnosticsExportService.makeJSONLFile(report: report)
            exportStatus = "JSONL log file is ready to share."
        } catch {
            exportStatus = "JSONL export failed: \(error.localizedDescription)"
        }
    }

    private func prepareFullTraceBundle() {
        do {
            fullTraceBundleURL = try DiagnosticsExportService.makeFullTraceBundle(store: appState.diagnosticsStore, config: appState.config, session: appState.session)
            exportStatus = "Full Trace bundle is ready to share."
        } catch {
            exportStatus = "Full Trace export failed: \(error.localizedDescription)"
        }
    }

    private func copySummary() {
        #if canImport(UIKit)
        UIPasteboard.general.string = appState.diagnosticsStore.exportSummary(config: appState.config, session: appState.session)
        exportStatus = "Summary copied."
        #else
        exportStatus = "Copy summary is available on iOS."
        #endif
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
