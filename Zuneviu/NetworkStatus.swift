import Foundation
import Network
import Combine

enum ConnectionKind: String { case unknown, offline, wifi, wired, cellular, other }
@MainActor final class NetworkStatus: ObservableObject {
    static let shared = NetworkStatus()
    @Published private(set) var kind: ConnectionKind
    @Published private(set) var expensive = false
    @Published private(set) var constrained = false
    private var monitor: NWPathMonitor?
    init(initial: ConnectionKind = .unknown, monitor enabled: Bool = true) {
        kind = initial
        if enabled {
            let monitor = NWPathMonitor(); self.monitor = monitor
            monitor.pathUpdateHandler = { [weak self] path in
                let kind: ConnectionKind = path.status != .satisfied ? .offline : path.usesInterfaceType(.wifi) ? .wifi : path.usesInterfaceType(.wiredEthernet) ? .wired : path.usesInterfaceType(.cellular) ? .cellular : .other
                Task { @MainActor in
                    self?.kind = kind; self?.expensive = path.isExpensive; self?.constrained = path.isConstrained
                }
            }
            monitor.start(queue: DispatchQueue(label: "Zuneviu.NetworkStatus"))
        }
    }
    var allowsWifiOnlyDownload: Bool { (kind == .wifi || kind == .wired) && !expensive && !constrained }
    deinit { monitor?.cancel() }
}
