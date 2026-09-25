import SwiftUI
import AppKit

struct SFSymbolsPickerView: View {

    @Binding var isPresented: Bool

    let onImport: (URL) async -> Void

    @State private var query: String = ""
    @State private var allNames: [String] = []
    @State private var results: [String] = []
    @State private var loading: Bool = true

    @AppStorage("recentSFSymbols") private var recentSymbolsData: Data = Data()

    private static let maxRecents: Int = 30
    private static let gridColumns = [GridItem(.adaptive(minimum: 72), spacing: 8)]
    private static let tileSize: CGFloat = 56
    private static let maxResults: Int = 300

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchField
            Divider()
            resultsGrid
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 480)
        .task {
            await loadLibrary()
        }
        .onDisappear {
            SFSymbolsLibrary.shared.releaseCache()
        }
    }

    private var header: some View {
        HStack {
            Text("SF Symbols")
                .font(.headline)
            Spacer()
            Button("Close") { isPresented = false }
                .keyboardShortcut(.cancelAction)
        }
        .padding(10)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search (e.g. heart, arrow, folder)", text: $query)
                .textFieldStyle(.plain)
                .onChange(of: query) { _, newValue in
                    results = filteredResults(for: newValue)
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = filteredResults(for: "")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
    }

    private var resultsGrid: some View {
        Group {
            if loading {
                VStack {
                    ProgressView()
                    Text("Loading \(SFSymbolsLibrary.shared.count) symbols…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if query.isEmpty {
                let recents = recentSymbols
                if recents.isEmpty {
                    Text("Start typing to search.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Recently Used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 8)
                        ScrollView {
                            LazyVGrid(columns: Self.gridColumns, spacing: 8) {
                                ForEach(recents, id: \.self) { name in
                                    Button {
                                        Task { await importSymbol(named: name) }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: name)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: Self.tileSize, height: Self.tileSize)
                                                .foregroundColor(.primary)
                                            Text(name)
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: 80)
                                        }
                                        .padding(6)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .help(name)
                                }
                            }
                            .padding(10)
                        }
                    }
                }
            } else if results.isEmpty {
                Text("No symbols match \"\(query)\".")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: Self.gridColumns, spacing: 8) {
                        ForEach(results, id: \.self) { name in
                            Button {
                                Task { await importSymbol(named: name) }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: name)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: Self.tileSize, height: Self.tileSize)
                                        .foregroundColor(.primary)
                                    Text(name)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: 80)
                                }
                                .padding(6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(name)
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if query.isEmpty {
                let count = recentSymbols.count
                Text(count > 0 ? "\(count) recent" : "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("Tap a symbol to import")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
    }

    private func loadLibrary() async {

        let names = await Task.detached(priority: .userInitiated) {
            await SFSymbolsLibrary.shared.allNames()
        }.value
        allNames = names
        results = filteredResults(for: query)
        loading = false
    }

    private func filteredResults(for q: String) -> [String] {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return [] }
        let matches = allNames.filter { $0.lowercased().contains(trimmed) }
        return Array(matches.prefix(Self.maxResults))
    }

    private var recentSymbols: [String] {
        (try? JSONDecoder().decode([String].self, from: recentSymbolsData)) ?? []
    }

    private func addToRecents(_ name: String) {
        var recents = recentSymbols
        recents.removeAll { $0 == name }
        recents.insert(name, at: 0)
        if recents.count > Self.maxRecents {
            recents = Array(recents.prefix(Self.maxRecents))
        }
        recentSymbolsData = (try? JSONEncoder().encode(recents)) ?? Data()
    }

    private func importSymbol(named name: String) async {
        guard let svg = SFSymbolsLibrary.shared.svg(named: name) else {
            NSSound.beep()
            return
        }
        addToRecents(name)
        let tempDir = FileManager.default.temporaryDirectory
        let sanitized = name.replacingOccurrences(of: "/", with: "_")
        let tempURL = tempDir.appendingPathComponent("sfsymbol-\(sanitized)-\(UUID().uuidString.prefix(8)).svg")
        do {
            try svg.data(using: String.Encoding.utf8)?.write(to: tempURL)
            await onImport(tempURL)
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            NSSound.beep()
            try? FileManager.default.removeItem(at: tempURL)
        }
        isPresented = false
    }
}
