//
//  MaintenanceScheduleView.swift
//  FMS


import SwiftUI
import SwiftData

// MARK: - Schedule Card Model is now imported dynamically from the central ScheduleCardView.swift component

// MARK: - Maintenance Schedule View

struct MaintenanceScheduleView: View {

    @Query private var allWorkOrders: [WorkOrder]
    @State private var selectedFilter: String = "All"
    @State private var selectedDate: Int = 22 // Default to Friday 22nd

    // Days of the week matching May 18 - May 24, 2026
    let weekDays = [
        (day: "M", date: 18),
        (day: "T", date: 19),
        (day: "W", date: 20),
        (day: "T", date: 21),
        (day: "F", date: 22),
        (day: "S", date: 23),
        (day: "S", date: 24)
    ]

    let categories = ["All", "Scheduled", "In Progress", "Completed"]

    // Mock schedule items matching the dashboard & seed
    private var mockScheduleItems: [ScheduleCardModel] {
        [
            ScheduleCardModel(
                vehicleImage: "https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=150&auto=format&fit=crop&q=80",
                vehicleName: "Truck 12",
                serviceType: "Oil Change & Filter Replacement",
                timeText: "Today, 10:00 AM",
                bayText: "Bay 2",
                status: "Scheduled",
                date: 22
            ),
            ScheduleCardModel(
                vehicleImage: "https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?w=150&auto=format&fit=crop&q=80",
                vehicleName: "Van 05",
                serviceType: "Brake Inspection",
                timeText: "Today, 01:00 PM",
                bayText: "Bay 1",
                status: "Scheduled",
                date: 22
            ),
            ScheduleCardModel(
                vehicleImage: "https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=150&auto=format&fit=crop&q=80",
                vehicleName: "Truck 18",
                serviceType: "Engine Check & Diagnostics",
                timeText: "Tomorrow, 09:00 AM",
                bayText: "Bay 3",
                status: "Scheduled",
                date: 23
            ),
            ScheduleCardModel(
                vehicleImage: "https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=150&auto=format&fit=crop&q=80",
                vehicleName: "Truck 12",
                serviceType: "Brake Pad Replacement & Inspection",
                timeText: "20 May 2026, 11:00 AM",
                bayText: "Bay 2",
                status: "In Progress",
                date: 20
            ),
            ScheduleCardModel(
                vehicleImage: "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150&auto=format&fit=crop&q=80",
                vehicleName: "Truck 07",
                serviceType: "Tire Replacement",
                timeText: "18 May 2026, 02:00 PM",
                bayText: "Bay 2",
                status: "Completed",
                date: 18
            )
        ]
    }

    // Filtered schedules combining live query & mock data
    private var filteredSchedules: [ScheduleCardModel] {
        // Gather any dynamic work orders
        let dynamicItems = allWorkOrders.map { order in
            let statusText = order.status == .completed ? "Completed" : (order.status == .inProgress ? "In Progress" : "Scheduled")
            let isBrakeOrTire = order.title.localizedCaseInsensitiveContains("Brake") || order.title.localizedCaseInsensitiveContains("Tire")
            let img = isBrakeOrTire ? "https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=150&auto=format&fit=crop&q=80" : "https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?w=150&auto=format&fit=crop&q=80"
            
            let calendar = Calendar.current
            let day = calendar.component(.day, from: order.createdAt)
            
            return ScheduleCardModel(
                vehicleImage: img,
                vehicleName: order.title.contains("Truck") ? "Truck 12" : "Van 05",
                serviceType: order.title,
                timeText: order.createdAt.formatted(date: .abbreviated, time: .shortened),
                bayText: "Bay 1",
                status: statusText,
                date: day
            )
        }
        
        let mockServiceTypes = mockScheduleItems.map { $0.serviceType }
        let uniqueDynamicItems = dynamicItems.filter { dItem in
            let isDuplicate = mockServiceTypes.contains(dItem.serviceType)
            return !isDuplicate
        }
        let combined = mockScheduleItems + uniqueDynamicItems
        
        // Filter by status tab selection
        let statusFiltered: [ScheduleCardModel]
        if selectedFilter == "All" {
            statusFiltered = combined
        } else {
            statusFiltered = combined.filter { $0.status.localizedCaseInsensitiveContains(selectedFilter) }
        }
        
        // Apply date filtering:
        // - If a specific status filter is active ("In Progress" or "Completed"), show all matching tasks
        //   across ALL dates so they are instantly visible without hunting day-by-day.
        // - Otherwise (if selecting "All" or "Scheduled"), filter by the selectedDate (if selectedDate > 0).
        if selectedFilter == "In Progress" || selectedFilter == "Completed" {
            return statusFiltered
        } else {
            if selectedDate > 0 {
                return statusFiltered.filter { $0.date == selectedDate }
            } else {
                return statusFiltered
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                calendarStripSection
                filterRowSection
                
                Divider()
                    .padding(.top, 8)
                
                scheduleListSection
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.99)) // Off-white backing
            .navigationBarHidden(true)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Schedule")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                Text("May 2026")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
            }
            
            Spacer()
            
            // Add custom schedule button
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(Color.fmsAmberLight.opacity(0.8))
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.fmsAmber)
                }
            }
            .buttonStyle(ShrinkButtonStyle())
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    // MARK: - Calendar Selector Strip Section

    private var calendarStripSection: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.date) { item in
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        if selectedDate == item.date {
                            selectedDate = 0 // Toggle off to show all dates
                        } else {
                            selectedDate = item.date
                        }
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(item.day)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(selectedDate == item.date ? Color.white : AppTheme.Text.secondary)
                        
                        Text("\(item.date)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(selectedDate == item.date ? Color.white : AppTheme.Text.primary)
                            .frame(width: 32, height: 32)
                            .background(selectedDate == item.date ? Color.fmsAmber : Color.clear)
                            .clipShape(Circle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedDate == item.date ? Color.fmsAmberLight : Color.clear)
                    .cornerRadius(12)
                }
                .buttonStyle(ShrinkButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 16)
    }

    // MARK: - Filter Row Section

    private var filterRowSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    Button(action: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            selectedFilter = cat
                        }
                    }) {
                        Text(cat)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(selectedFilter == cat ? Color.white : AppTheme.Text.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedFilter == cat ? Color.fmsAmber : Color.white)
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(selectedFilter == cat ? Color.clear : Color.black.opacity(0.05), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(ShrinkButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 16)
    }

    // MARK: - Schedule List Section

    private var scheduleListSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                if filteredSchedules.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 44))
                            .foregroundColor(AppTheme.Text.tertiary.opacity(0.5))
                            .padding(.top, 40)
                        
                        Text("No schedule for this day")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                        
                        Text("All clear! No pending appointments on May \(selectedDate)th.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.Text.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(filteredSchedules) { item in
                        ScheduleCardView(model: item)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Schedule Row Card has been refactored into ScheduleCardView

// MARK: - Preview

#Preview {
    struct PreviewContainerView: View {
        static let container: ModelContainer = {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: WorkOrder.self, configurations: config)
        }()
        
        var body: some View {
            MaintenanceScheduleView()
                .modelContainer(Self.container)
        }
    }
    
    return PreviewContainerView()
}
