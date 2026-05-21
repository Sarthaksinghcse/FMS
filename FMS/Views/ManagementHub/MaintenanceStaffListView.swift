//
//  MaintenanceStaffListView.swift
//  FMS
//
//  Created on 21/05/26.
//

import SwiftUI
import SwiftData

// MARK: - Maintenance Staff List View

@available(iOS 26.0, *)
struct MaintenanceStaffListView: View {
    
    // MARK: - SwiftData Queries
    
    @Query(sort: \User.fullName) private var allUsers: [User]
    
    private var maintenanceStaff: [User] {
        allUsers.filter { $0.role == UserRole.maintenance }
    }
    
    @Query private var allWorkOrders: [WorkOrder]
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    
    @State private var searchText = ""
    @State private var showAddStaffSheet = false
    @State private var selectedStaffForEdit: User?
    @State private var appearAnimation = false
    @State private var cardAnimations: [UUID: Bool] = [:]
    
    // MARK: - Computed Properties
    
    private var filteredStaff: [User] {
        if searchText.isEmpty {
            return maintenanceStaff
        }
        let query = searchText.lowercased()
        return maintenanceStaff.filter {
            $0.fullName.lowercased().contains(query) ||
            $0.email.lowercased().contains(query)
        }
    }
    
    private func workOrderCount(for staffId: UUID) -> Int {
        allWorkOrders.filter { $0.assignedTo == staffId }.count
    }
    
    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Content
                if filteredStaff.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView {
                            Label("No Maintenance Staff", systemImage: "wrench.and.screwdriver.fill")
                        } description: {
                            Text("Add your first technician to get started.")
                        } actions: {
                            Button("Add Staff Member") {
                                showAddStaffSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.Brand.accent)
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    staffListView
                }
            }
        }
        .navigationTitle("Maintenance Team")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search technicians...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showAddStaffSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddStaffSheet) {
            AddStaffSheetView()
        }
        .sheet(item: $selectedStaffForEdit) { staff in
            EditStaffSheetView(staff: staff)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
            triggerCardAnimations()
        }
        .onChange(of: filteredStaff.count) {
            triggerCardAnimations()
        }
    }
    
    
    
    // MARK: - Staff List
    
    private var staffListView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(filteredStaff) { staff in
                    staffCard(for: staff)
                        .opacity(cardAnimations[staff.id] == true ? 1 : 0)
                        .offset(y: cardAnimations[staff.id] == true ? 0 : 30)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Staff Card
    
    private func staffCard(for staff: User) -> some View {
        let orders = workOrderCount(for: staff.id)
        
        return ZStack(alignment: .topTrailing) {
            
            // Main Card Content
            HStack(spacing: 16) {
                
                // MARK: Avatar Circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.Brand.accent.opacity(0.7),
                                    AppTheme.Brand.accent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: AppTheme.Brand.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Text(initials(for: staff.fullName))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // MARK: Info Stack
                VStack(alignment: .leading, spacing: 6) {
                    Text(staff.fullName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    // Email
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                        Text(staff.email)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    // Phone
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                        Text(staff.phoneNumber)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    // Badges Row
                    HStack(spacing: 8) {
                        // Status Badge
                        statusBadge(isActive: staff.isActive)
                        
                        // Role Badge
                        roleBadge
                    }
                    .padding(.top, 2)
                }
                
                Spacer(minLength: 0)
                
                // MARK: Edit Button
                VStack {
                    Spacer()
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        selectedStaffForEdit = staff
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.Brand.royalBlue)
                            .symbolEffect(.bounce, value: selectedStaffForEdit?.id == staff.id)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    Spacer()
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.Glass.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
            
            // MARK: Work Order Count Badge (Top-Right)
            if orders > 0 {
                Text("\(orders)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(AppTheme.Brand.royalBlue)
                            .shadow(color: AppTheme.Brand.royalBlue.opacity(0.3), radius: 6, x: 0, y: 3)
                    )
                    .offset(x: -12, y: -8)
            }
        }
    }
    
    // MARK: - Status Badge
    
    private func statusBadge(isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isActive ? Color.green : AppTheme.Brand.accent)
                .frame(width: 7, height: 7)
            
            Text(isActive ? "Available" : "Busy")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(isActive ? Color.green : AppTheme.Brand.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((isActive ? Color.green : AppTheme.Brand.accent).opacity(0.12))
        )
    }
    
    // MARK: - Role Badge
    
    private var roleBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 9, weight: .bold))
            Text("Technician")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(AppTheme.Brand.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(AppTheme.Brand.accent.opacity(0.12))
        )
    }
    
    
    
    // MARK: - Animation Helpers
    
    private func triggerCardAnimations() {
        for (index, staff) in filteredStaff.enumerated() {
            let staffId = staff.id
            if cardAnimations[staffId] != true {
                withAnimation(
                    .spring(response: 0.6, dampingFraction: 0.8)
                    .delay(Double(index) * 0.08 + 0.15)
                ) {
                    cardAnimations[staffId] = true
                }
            }
        }
    }
}

// MARK: - Add Staff Sheet (Stub)

@available(iOS 26.0, *)
struct AddStaffSheetView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(AppTheme.Brand.accent.opacity(0.1))
                            .frame(width: 90, height: 90)
                        
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(AppTheme.Brand.accent)
                            .symbolEffect(.bounce)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Add Staff Member")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text("This feature is coming soon.\nYou'll be able to add maintenance technicians here.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle("New Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(AppTheme.Brand.accent)
                }
            }
        }
    }
}

// MARK: - Edit Staff Sheet (Stub)

@available(iOS 26.0, *)
struct EditStaffSheetView: View {
    
    let staff: User
    @Environment(\.dismiss) private var dismiss
    
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
                                    colors: [AppTheme.Brand.accent.opacity(0.7), AppTheme.Brand.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: AppTheme.Brand.accent.opacity(0.3), radius: 10, x: 0, y: 6)
                        
                        Text(staffInitials)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text(staff.fullName)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text("Edit functionality coming soon.\nYou'll be able to update staff details here.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle("Edit Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(AppTheme.Brand.accent)
                }
            }
        }
    }
    
    private var staffInitials: String {
        let parts = staff.fullName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    NavigationStack {
        MaintenanceStaffListView()
    }
    .modelContainer(for: [User.self, WorkOrder.self], inMemory: true)
}
