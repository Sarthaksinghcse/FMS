import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct VehicleMaintenanceHistoryView: View {
    let vehicle: Vehicle
    
    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case oldest = "Oldest"
        case custom = "Custom"
        
        var id: String { self.rawValue }
    }
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MaintenanceRecord.serviceDate, order: .reverse) private var allRecords: [MaintenanceRecord]
    
    @State private var animateIn = false
    @State private var selectedSort: SortOption = .newest
    @State private var previousSort: SortOption = .newest
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showCalendarSheet = false
    
    let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    let years = Array(2020...2035)
    
    // Filter and sort records specific to this vehicle
    private var vehicleRecords: [MaintenanceRecord] {
        let filtered = allRecords.filter { $0.vehicleId == vehicle.id }
        switch selectedSort {
        case .newest:
            return filtered.sorted { $0.serviceDate > $1.serviceDate }
        case .oldest:
            return filtered.sorted { $0.serviceDate < $1.serviceDate }
        case .custom:
            let calendar = Calendar.current
            return filtered
                .filter { record in
                    let m = calendar.component(.month, from: record.serviceDate)
                    let y = calendar.component(.year, from: record.serviceDate)
                    return m == selectedMonth && y == selectedYear
                }
                .sorted { $0.serviceDate > $1.serviceDate }
        }
    }
    
    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header badge when Custom date filter is active
                if selectedSort == .custom {
                    Button(action: {
                        showCalendarSheet = true
                    }) {
                        HStack(spacing: 6) {
                            Text("\(months[selectedMonth - 1]) \(String(selectedYear))")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.Brand.amber.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.Brand.amber.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if vehicleRecords.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: selectedSort == .custom ? "calendar.badge.exclamationmark" : "wrench.and.screwdriver")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text(selectedSort == .custom ? "No Records for \(months[selectedMonth - 1]) \(String(selectedYear))" : "No Maintenance History")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        
                        if selectedSort == .custom {
                            Text("Try picking another date or reset the filter.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.gray.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                selectedSort = .newest
                            }) {
                                Text("Reset Filter")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.Brand.amber)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(.top, 8)
                        }
                        Spacer()
                    }
                } else {
                    // Maintenance Activities List
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(vehicleRecords) { record in
                                MaintenanceActivityCard(record: record)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 60)
                    }
                }
            }
        }
        .navigationTitle("Maintenance History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sort by", selection: $selectedSort) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Brand.amber)
                        .rotationEffect(.degrees(90))
                        .padding(8)
                        .contentShape(Rectangle())
                }
            }
        }
        .onChange(of: selectedSort) { oldValue, newValue in
            if newValue == .custom {
                previousSort = oldValue
                showCalendarSheet = true
            }
        }
        .sheet(isPresented: $showCalendarSheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    // Preview label like blue May 2025 v in screenshot
                    HStack {
                        HStack(spacing: 4) {
                            Text("\(months[selectedMonth - 1]) \(String(selectedYear))")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Wheel pickers
                    HStack(spacing: 0) {
                        Picker("Month", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(months[month - 1])
                                    .font(.system(.body, design: .rounded))
                                    .tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        Picker("Year", selection: $selectedYear) {
                            ForEach(years, id: \.self) { year in
                                Text(String(year))
                                    .font(.system(.body, design: .rounded))
                                    .tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    Button(action: {
                        showCalendarSheet = false
                    }) {
                        Text("Apply")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.Brand.amber)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            selectedSort = previousSort
                            showCalendarSheet = false
                        }
                        .foregroundColor(.gray)
                    }
                }
            }
            .presentationDetents([.height(380)])
        }
    }
}

// Simplified Premium Card matching acceptance criteria: Displays service records, repair details, dates, and costs
@available(iOS 26.0, *)
struct MaintenanceActivityCard: View {
    let record: MaintenanceRecord
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: record.serviceDate)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Service Record (Type) & Cost
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Service Type")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(0.5)
                    
                    Text(record.serviceType)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Cost")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(0.5)
                    
                    Text(String(format: "₹%.2f", record.cost))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Brand.amber)
                }
            }
            
            Divider()
                .background(Color.black.opacity(0.06))
            
            // Body: Repair Details (Notes) & Date
            HStack(alignment: .top) {
                if let notes = record.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Repair Details")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        
                        Text(notes)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.black.opacity(0.8))
                            .lineLimit(3)
                            .lineSpacing(2)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Date")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(0.5)
                    
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Glass.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
