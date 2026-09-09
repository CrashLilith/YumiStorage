import Foundation
import Network
import SwiftUI
import UIKit

/// Lightweight reachability check for the local service exposed by LocalDevVPN.
/// This does not create a VPN; it only tells the UI whether the existing tunnel
/// is reachable on the configured device IP.
@MainActor
final class LocalDevVPNStatus: ObservableObject {
    @Published private(set) var isChecking = false
    @Published private(set) var isConnected = false

    private var connection: NWConnection?

    func check(deviceIP: String) {
        connection?.cancel()
        isChecking = true
        isConnected = false

        // LocalDevVPN exposes lockdown on iOS 18 and RSD on newer iOS builds.
        tryPort(49152, deviceIP: deviceIP) { [weak self] connected in
            guard let self else { return }
            if connected {
                self.finish(true)
            } else {
                self.tryPort(62078, deviceIP: deviceIP) { [weak self] classicConnected in
                    self?.finish(classicConnected)
                }
            }
        }
    }

    private func tryPort(_ port: UInt16, deviceIP: String, completion: @escaping (Bool) -> Void) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            completion(false)
            return
        }

        let connection = NWConnection(host: NWEndpoint.Host(deviceIP), port: nwPort, using: .tcp)
        self.connection = connection
        var completed = false
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard !completed else { return }
            switch state {
            case .ready:
                completed = true
                connection?.cancel()
                Task { @MainActor in completion(true) }
            case .failed, .cancelled:
                if self?.connection === connection {
                    completed = true
                    Task { @MainActor in completion(false) }
                }
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .utility))
    }

    private func finish(_ connected: Bool) {
        connection?.cancel()
        connection = nil
        isChecking = false
        isConnected = connected
    }
}

struct LocalDevVPNCard: View {
    @StateObject private var status = LocalDevVPNStatus()
    @AppStorage("TunnelDeviceIP") private var tunnelIP: String = "10.7.0.1"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("LocalDevVPN", systemImage: status.isConnected ? "checkmark.shield.fill" : "network.badge.shield.half.filled")
                    .font(.headline)
                Spacer()
                if status.isChecking {
                    ProgressView()
                } else {
                    Circle()
                        .fill(status.isConnected ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                }
            }

            Text(status.isConnected
                 ? "Tunnel is active. YumiStorage can connect to the device."
                 : "Tunnel is not reachable. Turn on LocalDevVPN, then return here.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Button {
                    openLocalDevVPN()
                } label: {
                    Label("Open LocalDevVPN", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)

                Button("Check") {
                    status.check(deviceIP: tunnelIP)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .yumiGlass(cornerRadius: 20)
        .onAppear { status.check(deviceIP: tunnelIP) }
        .onChange(of: tunnelIP) { newIP in status.check(deviceIP: newIP) }
    }

    private func openLocalDevVPN() {
        guard let url = URL(string: "https://apps.apple.com/app/id6755608044") else { return }
        UIApplication.shared.open(url)
    }
}

