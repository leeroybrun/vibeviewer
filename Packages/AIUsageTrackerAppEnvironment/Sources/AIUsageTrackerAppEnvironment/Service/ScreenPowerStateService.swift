import Foundation
import Cocoa

/// Protocol describing a service that observes screen power state changes.
public protocol ScreenPowerStateService: Sendable {
    @MainActor var isScreenAwake: Bool { get }
    @MainActor func startMonitoring()
    @MainActor func stopMonitoring()
    @MainActor func setOnScreenSleep(_ handler: @escaping @Sendable () -> Void)
    @MainActor func setOnScreenWake(_ handler: @escaping @Sendable () -> Void)
}

/// Default implementation backed by `NSWorkspace` notifications.
@MainActor
public final class DefaultScreenPowerStateService: ScreenPowerStateService, ObservableObject {
    public private(set) var isScreenAwake: Bool = true
    
    private var onScreenSleep: (@Sendable () -> Void)?
    private var onScreenWake: (@Sendable () -> Void)?
    
    public init() {}
    
    public func setOnScreenSleep(_ handler: @escaping @Sendable () -> Void) {
        self.onScreenSleep = handler
    }
    
    public func setOnScreenWake(_ handler: @escaping @Sendable () -> Void) {
        self.onScreenWake = handler
    }
    
    public func startMonitoring() {
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenSleep()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenWake()
            }
        }
    }
    
    public func stopMonitoring() {
        NotificationCenter.default.removeObserver(self, name: NSWorkspace.willSleepNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    private func handleScreenSleep() {
        isScreenAwake = false
        onScreenSleep?()
    }
    
    private func handleScreenWake() {
        isScreenAwake = true
        onScreenWake?()
    }
}

/// No-op implementation used for environment defaults and previews.
public struct NoopScreenPowerStateService: ScreenPowerStateService {
    public init() {}
    public var isScreenAwake: Bool { true }
    public func startMonitoring() {}
    public func stopMonitoring() {}
    public func setOnScreenSleep(_ handler: @escaping @Sendable () -> Void) {}
    public func setOnScreenWake(_ handler: @escaping @Sendable () -> Void) {}
}