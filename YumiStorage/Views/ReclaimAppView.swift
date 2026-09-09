import SwiftUI

/// Per-app reclaim: preview buckets, then empty selected folders.
struct ReclaimAppView: View {
    let app: InstalledApp
    @ObservedObject var viewModel: AppListViewModel
    @StateObject private var vm = ReclaimAppViewModel()

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    AppIconView(icon: viewModel.icons[app.bundleIdentifier], size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name).font(.headline)
                        Text(selectedSummary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Safe"), footer: Text("These folders are caches and temp files. The app can usually rebuild them.")) {
                ForEach(vm.buckets.filter { $0.category.risk == .safe }) { bucket in
                    bucketRow(bucket)
                }
            }

            Section(header: Text("Session"), footer: Text("May sign you out of in-app browsers. Off until you turn a bucket on.")) {
                if vm.isFilling && vm.buckets.filter({ $0.category.risk == .session }).isEmpty {
                    Text("Measuring…").foregroundColor(.secondary)
                }
                ForEach(vm.buckets.filter { $0.category.risk == .session }) { bucket in
                    bucketRow(bucket)
                }
            }

            Section(header: Text("Kept"), footer: Text("Documents, Preferences, and Application Support are never reclaimed here.")) {
                if vm.isFilling && vm.buckets.filter({ $0.category.risk == .kept }).isEmpty {
                    Text("Measuring…").foregroundColor(.secondary)
                }
                ForEach(vm.buckets.filter { $0.category.risk == .kept }) { bucket in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bucket.category.title)
                            Text(bucket.category.detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(bucket.summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section(footer: Text("Close \(app.name) first. This does not delete Documents, Preferences, or Application Support.")) {
                Button {
                    vm.confirmReclaim = true
                } label: {
                    Label("Reclaim \(ReclaimService.formatBytes(vm.selectedBytes))", systemImage: "internaldrive")
                }
                .disabled(vm.selectedBytes == 0 || vm.isBusy || vm.isLoading)
            }
        }
        .navigationTitle("Reclaim Space")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.isBusy || vm.isLoading {
                ZStack {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.15)
                        Text(vm.isLoading ? "Measuring…" : vm.busyTitle)
                            .font(.headline)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .onAppear {
            viewModel.ensureIcon(for: app.bundleIdentifier)
            vm.load(app: app)
        }
        .alert(vm.confirmTitle, isPresented: $vm.confirmReclaim) {
            Button("Cancel", role: .cancel) {}
            Button("Reclaim", role: .destructive) {
                vm.run(app: app)
            }
        } message: {
            Text(vm.confirmMessage(appName: app.name))
        }
        .alert(item: $vm.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    private var selectedSummary: String {
        if vm.isLoading { return "Measuring folders…" }
        return "\(ReclaimService.formatBytes(vm.selectedBytes)) selected"
    }

    private func bucketRow(_ bucket: ReclaimBucketStat) -> some View {
        let enabled = Binding<Bool>(
            get: { vm.selected.contains(bucket.id) },
            set: { on in
                if on { vm.selected.insert(bucket.id) }
                else { vm.selected.remove(bucket.id) }
            }
        )
        return Toggle(isOn: enabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bucket.category.title)
                Text(bucket.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(!bucket.available || (bucket.files == 0 && bucket.bytes == 0))
    }
}

struct ReclaimNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

final class ReclaimAppViewModel: ObservableObject {
    @Published var buckets: [ReclaimBucketStat] = []
    @Published var selected: Set<String> = []
    @Published var isLoading = false
    @Published var isFilling = false
    @Published var isBusy = false
    @Published var busyTitle = "Reclaiming…"
    @Published var confirmReclaim = false
    @Published var alert: ReclaimNotice?

    private let service = ReclaimService()
    private var loadToken = 0

    var selectedBytes: Int64 {
        buckets.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.bytes }
    }

    var selectedHasSession: Bool {
        buckets.contains { selected.contains($0.id) && $0.category.risk == .session }
    }

    var confirmTitle: String {
        selectedHasSession ? "Reclaim including session data?" : "Reclaim this space?"
    }

    func confirmMessage(appName: String) -> String {
        let count = buckets.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.files }
        var text = "Close \(appName) first. This removes \(count) files (\(ReclaimService.formatBytes(selectedBytes)))."
        if selectedHasSession {
            text += " Session buckets can sign you out of in-app web."
        }
        return text
    }

    func load(app: InstalledApp) {
        loadToken += 1
        let token = loadToken
        let cached = ReclaimScanCache.shared.buckets(for: app.bundleIdentifier) ?? []
        let hasSafe = cached.contains { $0.category.risk == .safe }
        if hasSafe {
            apply(cached, resetSelection: true)
            isLoading = false
            fillMissing(app: app, have: cached, token: token)
            return
        }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = (try? self.service.scan(app: app)) ?? []
            ReclaimScanCache.shared.merge(result, for: app.bundleIdentifier)
            DispatchQueue.main.async {
                guard token == self.loadToken else { return }
                self.apply(result, resetSelection: true)
                self.isLoading = false
            }
        }
    }

    private func fillMissing(app: InstalledApp, have: [ReclaimBucketStat], token: Int) {
        var needed: Set<ReclaimRisk> = []
        if !have.contains(where: { $0.category.risk == .session }) { needed.insert(.session) }
        if !have.contains(where: { $0.category.risk == .kept }) { needed.insert(.kept) }
        guard !needed.isEmpty else { return }
        isFilling = true
        DispatchQueue.global(qos: .utility).async {
            let extra = (try? self.service.scan(app: app, risks: needed)) ?? []
            ReclaimScanCache.shared.merge(extra, for: app.bundleIdentifier)
            DispatchQueue.main.async {
                guard token == self.loadToken else { return }
                self.merge(extra)
                self.isFilling = false
            }
        }
    }

    private func apply(_ result: [ReclaimBucketStat], resetSelection: Bool) {
        buckets = result
        if resetSelection {
            selected = Set(
                result.compactMap { bucket in
                    guard bucket.category.risk == .safe, bucket.available, bucket.bytes > 0 else { return nil }
                    return bucket.id
                }
            )
        }
    }

    private func merge(_ extra: [ReclaimBucketStat]) {
        var current = buckets
        for bucket in extra {
            if let i = current.firstIndex(where: { $0.id == bucket.id }) {
                current[i] = bucket
            } else {
                current.append(bucket)
            }
        }
        buckets = current
    }

    func run(app: InstalledApp) {
        let cats = buckets.filter { selected.contains($0.id) }.map(\.category)
        guard !cats.isEmpty else { return }
        loadToken += 1
        let token = loadToken
        isBusy = true
        busyTitle = "Reclaiming…"
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.service.reclaim(app: app, categories: cats) { title in
                    DispatchQueue.main.async { self.busyTitle = title }
                }
                let refreshed = (try? self.service.scan(app: app)) ?? []
                DispatchQueue.main.async {
                    guard token == self.loadToken else { return }
                    self.isBusy = false
                    self.apply(refreshed, resetSelection: true)
                    ReclaimScanCache.shared.merge(refreshed, for: app.bundleIdentifier)
                    var message = "Freed \(ReclaimService.formatBytes(result.bytesFreed)) (\(result.filesRemoved) files)."
                    if result.skipped > 0 {
                        message += " Skipped \(result.skipped) items that could not be deleted."
                    }
                    self.alert = ReclaimNotice(title: "Reclaimed", message: message)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isBusy = false
                    self.alert = ReclaimNotice(title: "Reclaim Failed", message: error.localizedDescription)
                }
            }
        }
    }
}
