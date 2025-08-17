//
//  Coordinator.swift
//  Background Changer
//
//  MVVM-C: Base Coordinator protocol and default storage/child management.
//

import Foundation

@MainActor
public protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    func start()
}

@MainActor
open class BaseCoordinator: Coordinator {
    public var childCoordinators: [Coordinator] = []

    public init() {}

    open func start() {
        // Override in subclass
    }

    public func addChild(_ coordinator: Coordinator) {
        childCoordinators.append(coordinator)
    }

    public func removeChild(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}
