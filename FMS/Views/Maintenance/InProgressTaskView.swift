//
//  InProgressTaskView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//




import SwiftUI
import SwiftData
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class InProgressTasksViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published var selectedFilter: Int = 0   // 0=All, 1=High Priority, 2=My Tasks

    let currentUserId: UUID
    private let allWorkOrders: [WorkOrder]

    init(currentUserId: UUID, allWorkOrders: [WorkOrder]) {
        self.currentUserId = currentUserId
        self.allWorkOrders = allWorkOrders
    }

    var filteredTasks: [WorkOrder] {
        var base = allWorkOrders.filter { $0.status == .inProgress }

        switch selectedFilter {
        case 1: base = base.filter { $0.priority == .high || $0.priority == .urgent }
        case 2: base = base.filter { $0.assignedTo == currentUserId }
        default: break
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            base = base.filter {
                $0.title.lowercased().contains(q) ||
                $0.workDescription.lowercased().contains(q)
            }
        }

        return base.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    var filterChips: [String] { ["All Active", "High Priority", "My Tasks"] }
    var accentColor: Color { AppTheme.Brand.primary }

    /// Simulated progress (0.0–1.0) based on elapsed time since creation
    func progress(for order: WorkOrder) -> Double {
        let elapsed = Date().timeIntervalSince(order.createdAt)
        let total: TimeInterval = 3 * 3600   // assume 3hr avg repair
        return min(max(elapsed / total, 0.08), 0.95)
    }

    /// Parts list from work description or default set
    func parts(for order: WorkOrder) -> [String] {
        let defaults = [
            ["Brake pads", "Rotor disc"],
            ["Engine oil filter", "Oil 5W-30"],
            ["Air filter", "Spark plugs"],
            ["Coolant", "Radiator cap"],
            ["Transmission fluid", "Gasket set"]
        ]
        let idx = abs(order.id.hashValue) % defaults.count
        return defaults[idx]
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Main View
// ─────────────────────────────────────────────────────────────────────────────

struct InProgressTasksView: View {
    
    @StateObject private var vm: InProgressTasksViewModel
    
    init(currentUserId: UUID, allWorkOrders: [WorkOrder]) {
        _vm = StateObject(wrappedValue: InProgressTasksViewModel(
            currentUserId: currentUserId,
            allWorkOrders: allWorkOrders
        ))
    }
    
    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            VStack(spacing: 0) {
                CustomCenteredHeaderView(title: "In Progress")
                
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            if vm.filteredTasks.isEmpty {
                                DetailEmptyState(
                                    icon: "wrench.and.screwdriver",
                                    title: "No Active Repairs",
                                    message: "There are no maintenance tasks currently in progress.",
                                    accentColor: vm.accentColor
                                )
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(vm.filteredTasks) { order in
                                        NavigationLink(destination: MaintenanceTaskDetailView(order: order)) {
                                            InProgressTaskCard(
                                                order: order,
                                                progress: vm.progress(for: order),
                                                parts: vm.parts(for: order)
                                            )
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 32)
                            }
                        } header: {
                            VStack(spacing: 12) {
                                TaskSearchBar(text: $vm.searchText, placeholder: "Search active repairs...")
                                    .padding(.top, 8)
                                
                                FilterChipRow(
                                    chips: vm.filterChips,
                                    selected: $vm.selectedFilter,
                                    accentColor: vm.accentColor
                                )
                                .padding(.bottom, 4)
                            }
                            .background(AppTheme.Background.page)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────────
    // MARK: - In Progress Task Card
    // ─────────────────────────────────────────────────────────────────────────────
    
    private struct InProgressTaskCard: View {
        let order: WorkOrder
        let progress: Double
        let parts: [String]
        
        var estimatedCompletion: Date {
            Calendar.current.date(byAdding: .hour, value: 3, to: order.createdAt) ?? .now
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                
                // ── Header ───────────────────────────────────────────────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            // Live pulse indicator
                            LivePulseDot()
                            Text("Active Repair")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Brand.primary)
                        }
                    }
                    Spacer()
                    PriorityBadge(priority: order.priority)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                // ── Progress Bar ─────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Repair Progress")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.Text.secondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.Brand.primary.opacity(0.10))
                                .frame(height: 7)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Brand.primary, AppTheme.Brand.teal],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 7)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                        }
                    }
                    .frame(height: 7)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                Divider().padding(.horizontal, 16)
                
                // ── Detail rows ──────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    InProgressDetailRow(
                        icon: "person.fill",
                        label: "Mechanic",
                        value: "Tech #\(order.assignedTo.uuidString.prefix(4).uppercased())",
                        color: AppTheme.Brand.violet
                    )
                    InProgressDetailRow(
                        icon: "clock.badge.checkmark",
                        label: "Est. Completion",
                        value: estimatedCompletion.formatted(date: .omitted, time: .shortened),
                        color: AppTheme.Brand.teal
                    )
                    InProgressDetailRow(
                        icon: "note.text",
                        label: "Notes",
                        value: order.workDescription.isEmpty ? "No notes" : order.workDescription,
                        color: AppTheme.Brand.primary
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // ── Parts being used ─────────────────────────────────────────────
                if !parts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Parts In Use")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.Text.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(parts, id: \.self) { part in
                                    Text(part)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AppTheme.Brand.primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(AppTheme.Brand.primary.opacity(0.08))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                
                // ── Footer ───────────────────────────────────────────────────────
                HStack {
                    TaskStatusBadge(label: "In Progress", color: AppTheme.Brand.primary, icon: "wrench.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.Brand.primary.opacity(0.18), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────────
    // MARK: - Live Pulse Indicator
    // ─────────────────────────────────────────────────────────────────────────────
    
    private struct LivePulseDot: View {
        @State private var pulsing = false
        
        var body: some View {
            ZStack {
                Circle()
                    .fill(AppTheme.Brand.primary.opacity(0.25))
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulsing ? 1.6 : 1.0)
                    .opacity(pulsing ? 0 : 1)
                Circle()
                    .fill(AppTheme.Brand.primary)
                    .frame(width: 7, height: 7)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    pulsing = true
                }
            }
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────────
    // MARK: - Detail Row
    // ─────────────────────────────────────────────────────────────────────────────
    
    private struct InProgressDetailRow: View {
        let icon: String
        let label: String
        let value: String
        let color: Color
        
        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Text.secondary)
                    .frame(width: 100, alignment: .leading)
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)
                    .lineLimit(1)
                Spacer()
            }
        }
    }
}
