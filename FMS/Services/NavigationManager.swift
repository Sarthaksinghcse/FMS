
//  NavigationManager.swift
//  FMS — Active Turn-by-Turn Navigation Engine
//
//  Architecture:
//  • @MainActor final class  ← all @Published mutations happen on main thread (zero data races)
//  • CLLocationManagerDelegate methods dispatch back to MainActor via Task { @MainActor in }
//  • Weak self guards in every closure — zero retain cycles
//  • One CLLocationManager instance shared per session; stopped immediately on deinit

import Foundation
import CoreLocation
import MapKit
import Combine
import SwiftUI

// MARK: - Navigation Step Model

struct NavStep: Identifiable {
    let id: Int                         // step index in MKRoute.steps
    let instruction: String             // human-readable instruction
    let distance: CLLocationDistance    // meters to travel in this step
    let coordinate: CLLocationCoordinate2D
    let sfSymbol: String                // directional SF Symbol name

    /// Derive a contextual SF Symbol from the MKRoute.Step instruction text.
    static func symbol(for instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("turn left")          { return "arrow.turn.up.left" }
        if lower.contains("turn right")         { return "arrow.turn.up.right" }
        if lower.contains("slight left")        { return "arrow.up.left" }
        if lower.contains("slight right")       { return "arrow.up.right" }
        if lower.contains("u-turn")             { return "arrow.uturn.left" }
        if lower.contains("merge")              { return "arrow.merge" }
        if lower.contains("exit")               { return "arrow.triangle.turn.up.right.circle" }
        if lower.contains("roundabout")         { return "arrow.clockwise.circle" }
        if lower.contains("destination")        { return "mappin.circle.fill" }
        return "arrow.up"
    }
}

// MARK: - Navigation Manager

@MainActor
final class NavigationManager: NSObject, ObservableObject {

    // MARK: Published state
    @Published private(set) var authStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var userLocation: CLLocation?
    @Published private(set) var userHeading: CLHeading?

    @Published private(set) var route: MKRoute?
    @Published private(set) var alternateRoutes: [MKRoute] = []
    @Published private(set) var steps: [NavStep] = []
    @Published private(set) var currentStepIndex: Int = 0
    @Published private(set) var distanceToNextManeuver: CLLocationDistance = 0
    @Published private(set) var isRouting: Bool = false
    @Published private(set) var routingError: String?

    /// Drives the MapCameraPosition binding in the View.
    @Published var cameraPosition: MapCameraPosition = .automatic

    /// True once "Start Now" was tapped and the 3D perspective is active.
    @Published private(set) var isNavigating: Bool = false

    /// ETA in seconds remaining along the current route.
    @Published private(set) var remainingTime: TimeInterval = 0
    @Published private(set) var remainingDistance: CLLocationDistance = 0

    // MARK: Private
    private let clManager = CLLocationManager()

    /// The destination as set by the calling view.
    @Published private(set) var destinationCoordinate: CLLocationCoordinate2D?
    private var destinationName: String = ""

    // Hysteresis: only advance step when user is within this threshold.
    private let stepAdvanceThresholdMeters: CLLocationDistance = 25

    // MARK: Init / Deinit

    override init() {
        super.init()
        clManager.delegate         = self
        clManager.desiredAccuracy  = kCLLocationAccuracyBestForNavigation
        clManager.distanceFilter   = 5          // fire every 5 m minimum
        clManager.headingFilter     = 3          // fire every 3° change
        clManager.pausesLocationUpdatesAutomatically = false
        clManager.activityType     = .automotiveNavigation
    }

    deinit {
        // Safe — CLLocationManager is synchronous stop; no MainActor needed here.
        clManager.stopUpdatingLocation()
        clManager.stopUpdatingHeading()
    }

    // MARK: - Public API

    /// Call once when the navigation view appears.
    func requestPermissionAndStart() {
        switch clManager.authorizationStatus {
        case .notDetermined:
            clManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startStreaming()
        default:
            authStatus = clManager.authorizationStatus
        }
    }

    /// Geocode `fromAddress` and `toAddress` via MKLocalSearch then calculate route between them.
    func calculateRoute(fromAddress: String, toAddress: String) async {
        isRouting = true
        routingError = nil
        
        // Geocode source
        let srcReq = MKLocalSearch.Request()
        srcReq.naturalLanguageQuery = fromAddress
        let srcItem = try? await MKLocalSearch(request: srcReq).start()
        let srcCoord = srcItem?.mapItems.first?.placemark.coordinate
        
        // Geocode destination
        let destReq = MKLocalSearch.Request()
        destReq.naturalLanguageQuery = toAddress
        let destItem = try? await MKLocalSearch(request: destReq).start()
        guard let destCoord = destItem?.mapItems.first?.placemark.coordinate else {
            routingError = "Could not find \"\(toAddress)\""
            isRouting = false
            return
        }
        
        // Use geocoded source, OR current location, OR fallback.
        let originCoord = srcCoord ?? userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090)
        
        await calculateRoute(from: originCoord, to: destCoord, name: toAddress)
    }

    /// Calculate route from origin → destination and render polyline.
    func calculateRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, name: String) async {
        destinationCoordinate = destination
        destinationName       = name
        isRouting             = true
        routingError          = nil

        let request               = MKDirections.Request()
        request.source            = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination       = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType     = .automobile
        request.requestsAlternateRoutes = true

        do {
            let result    = try await MKDirections(request: request).calculate()
            route         = result.routes.first
            alternateRoutes = Array(result.routes.dropFirst())

            if let primary = route {
                steps         = buildSteps(from: primary)
                remainingTime = primary.expectedTravelTime
                remainingDistance = primary.distance
                fitCamera(to: primary)
            }
        } catch {
            routingError = error.localizedDescription
        }
        isRouting = false
    }

    /// Transition to 3D driving perspective. Called when "Start Now" is tapped.
    func beginNavigation() {
        guard !isNavigating else { return }
        isNavigating   = true
        currentStepIndex = 0
        startStreaming()
        animateTo3DPerspective(location: userLocation)
    }

    /// Stop navigation and reset state.
    func endNavigation() {
        isNavigating = false
        clManager.stopUpdatingLocation()
        clManager.stopUpdatingHeading()
        cameraPosition = .automatic
    }

    // MARK: - Private helpers

    private func startStreaming() {
        clManager.startUpdatingLocation()
        clManager.startUpdatingHeading()
    }

    /// Build NavStep array from an MKRoute, skipping the degenerate first step.
    private func buildSteps(from route: MKRoute) -> [NavStep] {
        route.steps.enumerated().compactMap { idx, step in
            guard !step.instructions.isEmpty else { return nil }
            return NavStep(
                id:          idx,
                instruction: step.instructions,
                distance:    step.distance,
                coordinate:  step.polyline.coordinate,
                sfSymbol:    NavStep.symbol(for: step.instructions)
            )
        }
    }

    /// Fit camera to show the full route polyline with padding.
    private func fitCamera(to route: MKRoute) {
        let rect = route.polyline.boundingMapRect
        cameraPosition = .rect(
            rect.insetBy(dx: -rect.size.width * 0.20, dy: -rect.size.height * 0.20)
        )
    }

    /// Smooth 3D perspective — 500 m look-ahead, 65° pitch, heading-locked.
    private func animateTo3DPerspective(location: CLLocation?) {
        // Fallback to the start of the route, then Delhi if all else fails
        let coord = location?.coordinate
            ?? route?.polyline.coordinate
            ?? CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090)
        let heading = userHeading?.trueHeading ?? 0

        withAnimation(.easeInOut(duration: 1.2)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: coord,
                    distance:  500,          // metres above ground
                    heading:   heading,
                    pitch:     65            // degrees — matches Apple Maps driving tilt
                )
            )
        }
    }

    /// Update camera to follow user in 3D mode as they move.
    private func updateFollowCamera(location: CLLocation) {
        guard isNavigating else { return }
        let heading = userHeading?.trueHeading ?? location.course

        // Only reposition camera — no withAnimation here; MapKit handles interpolation.
        cameraPosition = .camera(
            MapCamera(
                centerCoordinate: location.coordinate,
                distance:  350,
                heading:   heading.isNaN ? 0 : heading,
                pitch:     65
            )
        )
    }

    /// Evaluate which route step the user is currently on and update progress.
    private func evaluateProgress(location: CLLocation) {
        guard isNavigating, steps.indices.contains(currentStepIndex) else { return }

        // Distance remaining on the full route (approximate via polyline).
        if let route {
            let polyCoord = route.polyline.coordinate
            let polyLoc   = CLLocation(latitude: polyCoord.latitude, longitude: polyCoord.longitude)
            remainingDistance = max(0, location.distance(from: polyLoc))
            let speed = max(location.speed, 5.0)  // assume ≥ 5 m/s
            remainingTime = remainingDistance / speed
        }

        // Check if user is close enough to the next step waypoint.
        let currentStep = steps[currentStepIndex]
        let stepLocation = CLLocation(
            latitude:  currentStep.coordinate.latitude,
            longitude: currentStep.coordinate.longitude
        )
        distanceToNextManeuver = location.distance(from: stepLocation)

        if distanceToNextManeuver < stepAdvanceThresholdMeters,
           currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension NavigationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startStreaming()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last,
              loc.horizontalAccuracy >= 0,
              loc.horizontalAccuracy < 65 else { return }          // discard poor fixes
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.userLocation = loc
            self.updateFollowCamera(location: loc)
            self.evaluateProgress(location: loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.userHeading = newHeading
            // Re-align camera heading in real-time.
            if self.isNavigating, let loc = self.userLocation {
                self.updateFollowCamera(location: loc)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        guard (error as? CLError)?.code != .locationUnknown else { return }
        Task { @MainActor [weak self] in
            self?.routingError = error.localizedDescription
        }
    }
}
