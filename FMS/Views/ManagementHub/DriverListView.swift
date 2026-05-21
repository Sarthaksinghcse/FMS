//
//  DriverListView.swift
//  FMS
//
//  Created on 21/05/26.
//

import SwiftUI
import SwiftData

// MARK: - Driver List View

@available(iOS 26.0, *)
struct DriverListView: View {
    
    // MARK: - SwiftData Queries
    
    @Query(sort: \User.fullName) private var allUsers: [User]
    
    private var drivers: [User] {
        allUsers.filter { $0.role == UserRole.driver }
    }
    
    @Query private var vehicles: [Vehicle]
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    
    @State private var searchText = ""
    @State private var showAddDriver = false
    @State private var selectedDriverForEdit: User?
    @State private var appearAnimation = false
    @State private var cardAnimations: [UUID: Bool] = [:]
    
    // MARK: - Computed
    
    private var filteredDrivers: [User] {
        guard !searchText.isEmpty else { return drivers }
        let query = searchText.lowercased()
        return drivers.filter {
            $0.fullName.lowercased().contains(query) ||
            $0.email.lowercased().contains(query)
        }
    }
    
    private func vehicleForDriver(_ driver: User) -> Vehicle? {
        vehicles.first { $0.assignedDriverId == driver.id }
    }
    
    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Content
                if filteredDrivers.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView {
                            Label("No Drivers Yet", systemImage: "person.2.fill")
                        } description: {
                            Text("Add your first driver to start managing your fleet team.")
                        } actions: {
                            Button("Add Driver") {
                                showAddDriver = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.Brand.royalBlue)
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    driverList
                }
            }
        }
        .navigationTitle("Driver Management")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search drivers...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showAddDriver = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddDriver) {
            AddDriverStubView()
        }
        .sheet(item: $selectedDriverForEdit) { driver in
            EditDriverStubView(driver: driver)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
            triggerCardAnimations()
        }
        .onChange(of: filteredDrivers.count) {
            triggerCardAnimations()
        }
    }
    
    
    // MARK: - Driver List
    
    private var driverList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(filteredDrivers) { driver in
                    driverCard(driver)
                        .opacity(cardAnimations[driver.id] == true ? 1 : 0)
                        .offset(y: cardAnimations[driver.id] == true ? 0 : 30)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Driver Card
    
    private func driverCard(_ driver: User) -> some View {
        HStack(spacing: 16) {
            
            // MARK: Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Brand.royalBlue.opacity(0.8), AppTheme.Brand.royalBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: AppTheme.Brand.royalBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Text(initials(for: driver.fullName))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // MARK: Info
            VStack(alignment: .leading, spacing: 6) {
                
                // Name row
                Text(driver.fullName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                // Email
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                    Text(driver.email)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                // Phone
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                    Text(driver.phoneNumber)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                // Assigned Vehicle
                if let vehicle = vehicleForDriver(driver) {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Brand.royalBlue.opacity(0.7))
                        Text(vehicle.registrationNumber)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Brand.royalBlue)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Unassigned")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray.opacity(0.5))
                            .italic()
                    }
                }
                
                // Badges row
                HStack(spacing: 8) {
                    // Status badge
                    statusBadge(isActive: driver.isActive)
                    
                    // Role badge
                    roleBadge
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            // MARK: Edit Button
            Button {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                selectedDriverForEdit = driver
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.08))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.Glass.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - Status Badge
    
    private func statusBadge(isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 7, height: 7)
            
            Text(isActive ? "Active" : "Inactive")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.3)
        }
        .foregroundColor(isActive ? .green : .red)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(isActive ? Color.green.opacity(0.10) : Color.red.opacity(0.10))
        )
        .overlay(
            Capsule()
                .stroke(isActive ? Color.green.opacity(0.25) : Color.red.opacity(0.25), lineWidth: 1)
        )
    }
    
    // MARK: - Role Badge
    
    private var roleBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "person.fill")
                .font(.system(size: 9))
            Text("Driver")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.3)
        }
        .foregroundColor(AppTheme.Brand.royalBlue)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(AppTheme.Brand.royalBlue.opacity(0.10))
        )
        .overlay(
            Capsule()
                .stroke(AppTheme.Brand.royalBlue.opacity(0.25), lineWidth: 1)
        )
    }
    
    
    
    // MARK: - Animation Helpers
    
    private func triggerCardAnimations() {
        for (index, driver) in filteredDrivers.enumerated() {
            withAnimation(
                .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
                .delay(Double(index) * 0.08 + 0.15)
            ) {
                cardAnimations[driver.id] = true
            }
        }
    }
}

// MARK: - Add Driver Stub Sheet

@available(iOS 26.0, *)
struct AddDriverStubView: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var appearAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Brand.royalBlue.opacity(0.08), AppTheme.Brand.royalBlue.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(AppTheme.Brand.royalBlue)
                            .symbolEffect(.bounce, value: appearAnimation)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Add New Driver")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text("Driver registration form\ncoming soon.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    
                    Spacer()
                }
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
            }
            .navigationTitle("New Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    appearAnimation = true
                }
            }
        }
    }
}

// MARK: - Edit Driver Stub Sheet

@available(iOS 26.0, *)
struct EditDriverStubView: View {
    
    let driver: User
    @Environment(\.dismiss) private var dismiss
    @State private var appearAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Brand.royalBlue.opacity(0.8), AppTheme.Brand.royalBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: AppTheme.Brand.royalBlue.opacity(0.3), radius: 12, x: 0, y: 6)
                        
                        Text(driverInitials)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Edit Driver Profile")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text(driver.fullName)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.gray)
                        
                        Text("Profile editing form\ncoming soon.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                }
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
            }
            .navigationTitle("Edit Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    appearAnimation = true
                }
            }
        }
    }
    
    private var driverInitials: String {
        let parts = driver.fullName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(driver.fullName.prefix(2)).uppercased()
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    NavigationStack {
        DriverListView()
    }
    .modelContainer(for: [User.self, Vehicle.self], inMemory: true)
}
