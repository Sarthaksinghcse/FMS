//
//  TripListView.swift
//  FMS
//
//  Created on 21/05/26.
//

import SwiftUI
import SwiftData

// MARK: - Trip Status Filter

enum TripStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case assigned = "Assigned"
    case started = "Started"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"

    var id: String { rawValue }

    var tripStatus: TripStatus? {
        switch self {
        case .all: return nil
        case .assigned: return .assigned
        case .started: return .started
        case .inProgress: return .inProgress
        case .completed: return .completed
        case .cancelled: return .cancelled
        }
    }
}

// MARK: - Trip Status UI Extension

extension TripStatus {
    var displayName: String {
        switch self {
        case .assigned: return "Assigned"
        case .started: return "Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var badgeColor: Color {
        switch self {
        case .assigned: return Color(red: 0.15, green: 0.38, blue: 0.90)
        case .started: return Color(red: 0.30, green: 0.70, blue: 0.46)
        case .inProgress: return Theme.darkOrange
        case .completed: return Color.gray
        case .cancelled: return Color.red
        }
    }

    var badgeIcon: String {
        switch self {
        case .assigned: return "person.badge.clock.fill"
        case .started: return "play.circle.fill"
        case .inProgress: return "truck.box.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

// MARK: - Trip List View

@available(iOS 26.0, *)
struct TripListView: View {

    // MARK: - State

    @State private var searchText = ""
    @State private var selectedFilter: TripStatusFilter = .all
    @State private var showAddTrip = false
    @State private var editingTrip: Trip? = nil
    @State private var appearAnimation = false
    @State private var cardAnimations: Set<UUID> = []

    // MARK: - SwiftData

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.scheduledStartTime, order: .reverse) private var allTrips: [Trip]
    @Query private var allUsers: [User]

    // MARK: - Purple Accent

    private let tripPurple = Color(red: 0.58, green: 0.39, blue: 0.87)

    // MARK: - Computed

    private var filteredTrips: [Trip] {
        var trips = allTrips

        // Status filter
        if let status = selectedFilter.tripStatus {
            trips = trips.filter { $0.tripStatus == status }
        }

        // Search filter
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            trips = trips.filter {
                $0.tripCode.lowercased().contains(query) ||
                $0.startLocation.lowercased().contains(query) ||
                $0.endLocation.lowercased().contains(query)
            }
        }
        return trips
    }

    private func driverName(for driverId: UUID) -> String? {
        allUsers.first(where: { $0.id == driverId && $0.role == UserRole.driver })?.fullName
    }

    // MARK: - Date Formatters

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f
    }()

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.clearWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                // Filter Chips
                filterChips
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                // Content
                if filteredTrips.isEmpty {
                    if searchText.isEmpty && selectedFilter == .all {
                        ContentUnavailableView {
                            Label("No Trips Yet", systemImage: "map.fill")
                        } description: {
                            Text("Schedule or dispatch your first trip.")
                        } actions: {
                            Button("Add Trip") {
                                showAddTrip = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(tripPurple)
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    tripListContent
                }
            }
        }
        .navigationTitle("Trip Management")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search trips...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showAddTrip = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTrip) {
            AddTripStubView()
        }
        .sheet(item: $editingTrip) { trip in
            EditTripStubView(trip: trip)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
        }
    }

    

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TripStatusFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    let fgColor: Color = isSelected ? .white : .gray
                    let strokeColor: Color = isSelected ? .clear : Theme.glassBorder
                    
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(fgColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background {
                                if isSelected {
                                    tripPurple
                                }
                            }
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(strokeColor, lineWidth: 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 2)
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }

    // MARK: - Trip List Content

    private var tripListContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(filteredTrips) { trip in
                    let index: Int = filteredTrips.firstIndex(where: { $0.id == trip.id }) ?? 0
                    let delay: Double = Double(index) * 0.07
                    TripCardView(
                        trip: trip,
                        driverName: driverName(for: trip.driverId),
                        accentColor: tripPurple,
                        onEdit: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            editingTrip = trip
                        }
                    )
                    .opacity(cardAnimations.contains(trip.id) ? 1 : 0)
                    .offset(y: cardAnimations.contains(trip.id) ? 0 : 30)
                    .onAppear {
                        withAnimation(
                            Animation.spring(response: 0.6, dampingFraction: 0.8)
                            .delay(delay)
                        ) {
                            _ = cardAnimations.insert(trip.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    
}

// MARK: - Trip Card View

@available(iOS 26.0, *)
struct TripCardView: View {

    let trip: Trip
    let driverName: String?
    let accentColor: Color
    let onEdit: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // MARK: Top Row — Icon, Trip Code, Status, Edit
            HStack(spacing: 14) {

                // Route icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.8), accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.tripCode)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.black)

                    Text(Self.dateFormatter.string(from: trip.scheduledStartTime))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Status Badge
                statusBadge

                // Edit Button
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.gray.opacity(0.35))
                }
                .buttonStyle(ScaleButtonStyle())
            }

            // MARK: Route Info
            routeRow

            // MARK: Schedule & Distance
            HStack(spacing: 0) {
                // Scheduled Time
                detailColumn(
                    label: "DEPARTURE",
                    value: Self.timeFormatter.string(from: trip.scheduledStartTime),
                    icon: "clock.fill"
                )

                Spacer()

                // Arrival Time
                detailColumn(
                    label: "ARRIVAL",
                    value: Self.timeFormatter.string(from: trip.scheduledEndTime),
                    icon: "clock.badge.checkmark.fill"
                )

                Spacer()

                // Distance
                detailColumn(
                    label: "DISTANCE",
                    value: String(format: "%.1f km", trip.distanceKm),
                    icon: "road.lanes"
                )
            }

            // MARK: Driver Info
            if let name = driverName {
                Divider()
                    .background(Theme.glassBorder)

                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(accentColor.opacity(0.7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ASSIGNED DRIVER")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.gray.opacity(0.7))
                            .tracking(0.8)

                        Text(name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                    }

                    Spacer()
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: trip.tripStatus.badgeIcon)
                .font(.system(size: 10, weight: .bold))

            Text(trip.tripStatus.displayName)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(trip.tripStatus.badgeColor)
        .clipShape(Capsule())
    }

    // MARK: - Route Row

    private var routeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.green.opacity(0.7))

            Text(trip.startLocation)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.black.opacity(0.8))
                .lineLimit(1)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray.opacity(0.5))

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.red.opacity(0.7))

            Text(trip.endLocation)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.black.opacity(0.8))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Detail Column

    private func detailColumn(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(accentColor.opacity(0.6))

            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.gray.opacity(0.7))
                .tracking(0.8)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
        }
    }
}

// MARK: - Add Trip Stub View

@available(iOS 26.0, *)
struct AddTripStubView: View {

    @Environment(\.dismiss) private var dismiss

    private let tripPurple = Color(red: 0.58, green: 0.39, blue: 0.87)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.clearWhite.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(tripPurple.opacity(0.08))
                            .frame(width: 100, height: 100)

                        Image(systemName: "map.fill")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(tripPurple.opacity(0.5))
                            .symbolEffect(.bounce)
                    }

                    VStack(spacing: 8) {
                        Text("Add New Trip")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.black)

                        Text("Trip creation form\ncoming soon.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(tripPurple)
                }
            }
        }
    }
}

// MARK: - Edit Trip Stub View

@available(iOS 26.0, *)
struct EditTripStubView: View {

    let trip: Trip
    @Environment(\.dismiss) private var dismiss

    private let tripPurple = Color(red: 0.58, green: 0.39, blue: 0.87)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.clearWhite.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(tripPurple.opacity(0.08))
                            .frame(width: 100, height: 100)

                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(tripPurple.opacity(0.5))
                            .symbolEffect(.bounce)
                    }

                    VStack(spacing: 8) {
                        Text("Edit Trip")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.black)

                        Text("Editing \(trip.tripCode)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(tripPurple)

                        Text("Trip editing form\ncoming soon.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(tripPurple)
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    NavigationStack {
        TripListView()
    }
    .modelContainer(for: [Trip.self, User.self], inMemory: true)
}
