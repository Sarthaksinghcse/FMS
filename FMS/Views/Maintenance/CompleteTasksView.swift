//
//  CompletedTaskView.swift
//  FMS
//
//  Created by Gauri Verma on 25/05/26.
//


import SwiftUI
import SwiftData
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class CompletedTasksViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published var selectedFilter: Int = 0   // 0=All, 1=High Value, 2=My Completions

    let currentUserId: UUID
    private let allWorkOrders: [WorkOrder]

    init(currentUserId: UUID, allWorkOrders: [WorkOrder]) {
        self.currentUserId = currentUserId
        self.allWorkOrders = allWorkOrders
    }

    var filteredTasks: [WorkOrder] {
        let today = Calendar.current.startOfDay(for: .now)

        var base = allWorkOrders.filter { order in
            order.status == .completed &&
            (order.completedAt ?? .distantPast) >= today
        }

        switch selectedFilter {
        case 1: base = base.filter { ($0.estimatedCost ?? 0) >= 5000 }
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

        return base.sorted {
            ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
        }
    }

    var totalLaborCost: Double {
        filteredTasks.compactMap { $0.estimatedCost }.reduce(0, +)
    }

    var filterChips: [String] { ["All", "High Value", "My Completions"] }
    var accentColor: Color { AppTheme.Status.success }

    func parts(for order: WorkOrder) -> [String] {
        let allParts = [
            ["Brake pads", "Rotor disc", "Caliper"],
            ["Engine oil filter", "Oil 5W-30", "Drain plug washer"],
            ["Air filter", "Spark plugs (x4)"],
            ["Coolant 5L", "Radiator cap", "Hose clamp"],
            ["Transmission fluid", "Gasket set", "Seal kit"]
        ]
        return allParts[abs(order.id.hashValue) % allParts.count]
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Main View
// ─────────────────────────────────────────────────────────────────────────────

struct CompletedTasksView: View {
    let hidesTabBar: Bool
    @StateObject private var vm: CompletedTasksViewModel
    
    init(currentUserId: UUID, allWorkOrders: [WorkOrder], hidesTabBar: Bool = false) {
        self.hidesTabBar = hidesTabBar
        _vm = StateObject(wrappedValue: CompletedTasksViewModel(
            currentUserId: currentUserId,
            allWorkOrders: allWorkOrders
        ))
    }
    
    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            // Summary banner
                            if !vm.filteredTasks.isEmpty {
                                CompletedSummaryBanner(
                                    count: vm.filteredTasks.count,
                                    totalCost: vm.totalLaborCost
                                )
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                            
                            if vm.filteredTasks.isEmpty {
                                DetailEmptyState(
                                    icon: "checkmark.seal.fill",
                                    title: "Nothing Completed Yet",
                                    message: "Completed maintenance tasks will appear here once work orders are closed today.",
                                    accentColor: vm.accentColor
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(vm.filteredTasks) { order in
                                        NavigationLink(destination: MaintenanceTaskDetailView(order: order)) {
                                            CompletedTaskCard(order: order, parts: vm.parts(for: order))
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 4)
                                .padding(.bottom, 32)
                            }
                        } header: {
                            VStack(spacing: 12) {
                                TaskSearchBar(text: $vm.searchText, placeholder: "Search completed tasks...")
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
        }
        .toolbar(hidesTabBar ? .hidden : .automatic, for: .tabBar)
    }
    
    // ─────────────────────────────────────────────────────────────────────────────
    // MARK: - Summary Banner
    // ─────────────────────────────────────────────────────────────────────────────
    
    private struct CompletedSummaryBanner: View {
        let count: Int
        let totalCost: Double
        
        var body: some View {
            HStack(spacing: 0) {
                SummaryMetric(
                    label: "Tasks Done",
                    value: "\(count)",
                    icon: "checkmark.circle.fill",
                    color: AppTheme.Status.success
                )
                Divider().frame(height: 36)
                SummaryMetric(
                    label: "Total Cost",
                    value: totalCost > 0 ? "₹\(String(format: "%.0f", totalCost))" : "—",
                    icon: "indianrupeesign.circle.fill",
                    color: AppTheme.Brand.primary
                )
                Divider().frame(height: 36)
                SummaryMetric(
                    label: "Avg. Time",
                    value: "2.4 hrs",
                    icon: "clock.fill",
                    color: AppTheme.Brand.amber
                )
            }
            .padding(.vertical, 14)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.medium)
            .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 2)
            .padding(.bottom, 4)
        }
    }
    
    private struct SummaryMetric: View {
        let label: String
        let value: String
        let icon: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.Text.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────────
    // MARK: - Completed Task Card
    // ─────────────────────────────────────────────────────────────────────────────
    
    private struct CompletedTaskCard: View {
        let order: WorkOrder
        let parts: [String]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                
                // ── Header with completed badge ──────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(order.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                            .lineLimit(1)
                        if let completedAt = order.completedAt {
                            Text(completedAt.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.Text.secondary)
                        }
                    }
                    Spacer()
                    
                    // Green completed badge
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Done")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.Status.success)
                    .cornerRadius(20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                Divider().padding(.horizontal, 16)
                
                // ── Details ──────────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    CompletedDetailRow(
                        icon: "wrench.and.screwdriver.fill",
                        label: "Service",
                        value: order.workDescription.isEmpty ? "General Maintenance" : order.workDescription,
                        color: AppTheme.Status.success
                    )
                    CompletedDetailRow(
                        icon: "person.fill",
                        label: "Mechanic",
                        value: "Tech #\(order.assignedTo.uuidString.prefix(4).uppercased())",
                        color: AppTheme.Brand.violet
                    )
                    if let cost = order.estimatedCost, cost > 0 {
                        CompletedDetailRow(
                            icon: "indianrupeesign.circle",
                            label: "Labor Cost",
                            value: "₹\(String(format: "%.2f", cost))",
                            color: AppTheme.Brand.primary
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // ── Parts used ───────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 7) {
                    Text("Parts Used")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.Text.secondary)
                    
                    FlowLayout(items: parts) { part in
                        Text(part)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.Status.success)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(AppTheme.Status.success.opacity(0.10))
                            .cornerRadius(7)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 14)
                
                // ── Footer ───────────────────────────────────────────────────────
                HStack {
                    Text(order.priority.rawValue.capitalized + " Priority")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(order.priority.detailColor)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.Status.success.opacity(0.20), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
    
    private struct CompletedDetailRow: View {
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
                    .frame(width: 80, alignment: .leading)
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)
                    .lineLimit(1)
                Spacer()
            }
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────────
    // MARK: - Simple Flow Layout (wrap chips)
    // ─────────────────────────────────────────────────────────────────────────────
    
    private struct FlowLayout<T: Hashable, Content: View>: View {
        let items: [T]
        let content: (T) -> Content
        
        @State private var totalHeight: CGFloat = 40
        
        var body: some View {
            GeometryReader { geo in
                self.generateContent(in: geo)
            }
            .frame(height: totalHeight)
        }
        
        private func generateContent(in geo: GeometryProxy) -> some View {
            var width: CGFloat = 0
            var height: CGFloat = 0
            return ZStack(alignment: .topLeading) {
                ForEach(items, id: \.self) { item in
                    content(item)
                        .padding(.trailing, 6)
                        .padding(.bottom, 6)
                        .alignmentGuide(.leading) { d in
                            if (abs(width - d.width) > geo.size.width) {
                                width = 0; height -= d.height
                            }
                            let result = width
                            if item == items.last { width = 0 } else { width -= d.width }
                            return result
                        }
                        .alignmentGuide(.top) { _ in height }
                }
            }
            .background(viewHeightReader($totalHeight))
        }
        
        private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
            GeometryReader { geo -> Color in
                DispatchQueue.main.async { binding.wrappedValue = geo.size.height }
                return Color.clear
            }
        }
    }
    //
    //  CompleteTasksView.swift
    //  FMS
    //
    //  Created by Gauri Verma on 26/05/26.
    //
}
