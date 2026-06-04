//
//  TechnicianWorkDetailsView.swift
//  FMS
//
//  Created by Antigravity on 04/06/26.
//

import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct TechnicianWorkDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let technician: User
    
    @Query private var allWorkOrders: [WorkOrder]
    
    @State private var selectedFilter: Int = 0 // 0 = Assigned, 1 = In Progress, 2 = Completed
    
    private var technicianWorkOrders: [WorkOrder] {
        allWorkOrders.filter { $0.assignedTo == technician.id }
    }
    
    private var filteredWorkOrders: [WorkOrder] {
        switch selectedFilter {
        case 0:
            return technicianWorkOrders.filter { $0.status == .open }
        case 1:
            return technicianWorkOrders.filter { $0.status == .inProgress }
        case 2:
            return technicianWorkOrders.filter { $0.status == .completed }
        default:
            return technicianWorkOrders
        }
    }
    
    private func countForTab(_ idx: Int) -> Int {
        switch idx {
        case 0: return technicianWorkOrders.filter { $0.status == .open }.count
        case 1: return technicianWorkOrders.filter { $0.status == .inProgress }.count
        case 2: return technicianWorkOrders.filter { $0.status == .completed }.count
        default: return 0
        }
    }
    
    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }
    
    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Technician Profile Header
                    profileHeaderView
                    
                    // Filter tab chips
                    statusTabs
                    
                    // Work Orders List
                    if filteredWorkOrders.isEmpty {
                        let statusName = selectedFilter == 0 ? "Assigned" : (selectedFilter == 1 ? "In Progress" : "Completed")
                        emptyStateView(for: statusName)
                            .padding(.top, 10)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredWorkOrders) { order in
                                NavigationLink(destination: WorkOrderDetailedView(order: order).environment(\.modelContext, modelContext)) {
                                    WorkOrderRow(order: order)
                                }
                                .buttonStyle(.plain)
                                .background(AppTheme.Background.card)
                                .cornerRadius(AppTheme.Radius.card)
                                .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Work Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var profileHeaderView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [AppTheme.Brand.accent.opacity(0.7), AppTheme.Brand.accent],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 72, height: 72)
                    .shadow(color: AppTheme.Brand.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                Text(initials(for: technician.fullName))
                    .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text(technician.fullName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Text("Technician")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Brand.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.Brand.accent.opacity(0.12)))
            }
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                    Text(technician.email)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                    Text(technician.phoneNumber)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 6) {
                Circle().fill(technician.isActive ? AppTheme.Status.success : AppTheme.Brand.accent).frame(width: 7, height: 7)
                Text(technician.isActive ? "Available" : "Busy")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(technician.isActive ? AppTheme.Status.success : AppTheme.Brand.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill((technician.isActive ? AppTheme.Status.success : AppTheme.Brand.accent).opacity(0.12)))
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Background.card)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 24)
    }
    
    private var statusTabs: some View {
        HStack(spacing: 10) {
            ForEach(0..<3) { idx in
                let label = idx == 0 ? "Assigned" : (idx == 1 ? "In Progress" : "Completed")
                let count = countForTab(idx)
                let isSelected = selectedFilter == idx
                let accentColor: Color = idx == 0 ? AppTheme.Brand.primary : (idx == 1 ? AppTheme.Brand.amber : AppTheme.Status.success)
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedFilter = idx
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(isSelected ? Color.white.opacity(0.25) : accentColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(isSelected ? .white : accentColor)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(isSelected ? accentColor : accentColor.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(isSelected ? Color.clear : accentColor.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }
    
    private func emptyStateView(for status: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.Brand.primary.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.Brand.primary.opacity(0.6))
            }
            
            VStack(spacing: 6) {
                Text("No \(status) Tasks")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Text("There are no tasks currently \(status.lowercased()) for \(technician.fullName).")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 24)
    }
}
