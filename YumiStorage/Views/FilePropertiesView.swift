import SwiftUI
import CryptoKit

/// Metadata sheet for a file or folder inside another app's container.
struct FilePropertiesView: View {
    let app: InstalledApp
    let item: FileItem

    @StateObject private var vm = FilePropertiesViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Name")) {
                    Text(item.name)
                }
                Section(header: Text("Path")) {
                    Text(item.path)
                        .font(.footnote)
                        .textSelection(.enabled)
                    Button {
                        FileClipboard.copyText(item.path, confirmation: "Copied Path")
                    } label: {
                        Label("Copy Path", systemImage: "doc.on.doc")
                    }
                }
                Section(header: Text("Details")) {
                    row("Kind", kindLabel)
                    row("Size", formatBytes(item.size))
                    if let modified = item.modified {
                        row("Modified", BackupPaths.displayStamp.string(from: modified))
                    }
                    row("Readable", item.isReadable ? "Yes" : "No")
                    row("Writable", item.isWritable ? "Yes" : "No")
                }
                if !item.isDirectory {
                    Section(header: Text("SHA-256")) {
                        if vm.isHashing {
                            HStack {
                                ProgressView()
                                Text("Computing…")
                            }
                        } else if let hash = vm.sha256 {
                            Text(hash)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                            Button {
                                FileClipboard.copyText(hash, confirmation: "Copied SHA-256")
                            } label: {
                                Label("Copy SHA-256", systemImage: "doc.on.doc")
                            }
                        } else if let error = vm.errorMessage {
                            Text(error).foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Properties")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if !item.isDirectory {
                    vm.hash(app: app, item: item)
                }
            }
        }
    }

    private var kindLabel: String {
        FileContentKind.classify(name: item.name, isDirectory: item.isDirectory).rawValue
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}

final class FilePropertiesViewModel: ObservableObject {
    @Published var sha256: String?
    @Published var isHashing = false
    @Published var errorMessage: String?

    private let escape = SandboxEscape()
    private let files = FileService()

    func hash(app: InstalledApp, item: FileItem) {
        isHashing = true
        errorMessage = nil
        DispatchQueue.global(qos: .utility).async {
            do {
                let data = try self.escape.withHandle(for: app.containerPath) { _ in
                    try self.files.readFile(at: item.path)
                }
                let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                DispatchQueue.main.async {
                    self.sha256 = digest
                    self.isHashing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isHashing = false
                }
            }
        }
    }
}
