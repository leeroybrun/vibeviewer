import Foundation
import Observation

/// Coordinates the dashboard refresh service with screen power state events.
@MainActor
@Observable
public final class PowerAwareDashboardRefreshService: DashboardRefreshService {
    private let refreshService: DefaultDashboardRefreshService
    private let screenPowerService: DefaultScreenPowerStateService
    
    public var isRefreshing: Bool { refreshService.isRefreshing }
    public var isPaused: Bool { refreshService.isPaused }
    
    public init(
        refreshService: DefaultDashboardRefreshService,
        screenPowerService: DefaultScreenPowerStateService
    ) {
        self.refreshService = refreshService
        self.screenPowerService = screenPowerService
        
        // Wire up screen sleep/wake callbacks.
        screenPowerService.setOnScreenSleep { [weak self] in
            Task { @MainActor in
                self?.refreshService.pause()
            }
        }
        
        screenPowerService.setOnScreenWake { [weak self] in
            Task { @MainActor in
                await self?.refreshService.resume()
            }
        }
    }
    
    public func start() async {
        // Begin monitoring screen power state changes.
        screenPowerService.startMonitoring()
        
        // Start the underlying refresh service.
        await refreshService.start()
    }
    
    public func stop() {
        refreshService.stop()
        screenPowerService.stopMonitoring()
    }
    
    public func pause() {
        refreshService.pause()
    }
    
    public func resume() async {
        await refreshService.resume()
    }
    
    public func refreshNow() async {
        await refreshService.refreshNow()
    }
}