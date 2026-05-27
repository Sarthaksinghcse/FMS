//
//  InventoryDetailView.swift
//  FMS
//
//  Created by Gauri Verma on 27/05/26.
//

import SwiftUI
import SwiftData

struct InventoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var item: InventoryItem
    
    @State private var showingEditSheet = false
    
    private var isLow: Bool { item.quantityInStock <= item.reorderThreshold }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Dynamic Brand Header Panel
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(isLow ? AppTheme.Brand.accent.opacity(0.12) : AppTheme.Brand.teal.opacity(0.12))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: isLow ? "exclamationmark.triangle.fill" : "shippingbox.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(isLow ? AppTheme.Brand.accent : AppTheme.Brand.teal)
                            }
                            .padding(.top, 10)
                            
                            VStack(spacing: 4) {
                                Text(item.partName)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Text.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text("P/#\(item.partNumber)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.Text.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.Background.page)
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.Glass.border, lineWidth: 1))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, y: 3)
                        .padding(.horizontal)
                        
                        // Stock Status & Progress Bar
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Stock Level")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                    .textCase(.uppercase)
                                
                                Spacer()
                                
                                if isLow {
                                    Text("CRITICAL STOCK")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(AppTheme.Status.danger)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(AppTheme.Status.danger.opacity(0.12))
                                        .cornerRadius(6)
                                } else {
                                    Text("HEALTHY STOCK")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(AppTheme.Status.success)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(AppTheme.Status.success.opacity(0.12))
                                        .cornerRadius(6)
                                }
                            }
                            
                            HStack(alignment: .lastTextBaseline, spacing: 6) {
                                Text("\(item.quantityInStock)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(isLow ? AppTheme.Status.danger : AppTheme.Text.primary)
                                
                                Text("units available")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Text.secondary)
                            }
                            
                            // Safety Margin Progress Bar
                            GeometryReader { geo in
                                let totalWidth = geo.size.width
                                let percentage = CGFloat(min(Double(item.quantityInStock) / Double(max(1, item.reorderThreshold * 2)), 1.0))
                                
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(AppTheme.Glass.ringTrack)
                                        .frame(height: 8)
                                    
                                    Capsule()
                                        .fill(isLow ? AppTheme.Status.danger : AppTheme.Status.success)
                                        .frame(width: totalWidth * percentage, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(20)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, y: 3)
                        .padding(.horizontal)
                        
                        // Technical Specifications Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Specifications")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                            
                            VStack(spacing: 12) {
                                DetailRow(icon: "exclamationmark.triangle.fill", title: "Reorder Threshold", value: "\(item.reorderThreshold) units", color: AppTheme.Brand.amber)
                                
                                Divider()
                                
                                DetailRow(icon: "indianrupeesign.circle.fill", title: "Unit Cost", value: "₹\(String(format: "%.2f", item.unitCost))", color: AppTheme.Status.success)
                                
                                Divider()
                                
                                DetailRow(
                                    icon: "building.2.fill",
                                    title: "Supplier",
                                    value: (item.supplierName?.isEmpty ?? true) ? "Not Specified" : (item.supplierName ?? ""),
                                    color: AppTheme.Brand.primaryDeep
                                )
                            }
                        }
                        .padding(20)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, y: 3)
                        .padding(.horizontal)

                        // Date Metadata Row
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Registered On")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                Text(item.createdAt, style: .date)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Divider().frame(height: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last Updated")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                Text(item.updatedAt, style: .date)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(AppTheme.Background.card.opacity(0.6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Part Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditInventoryView(item: item, onDelete: {
                    dismiss() // Automatically dismisses the parent Detail sheet upon deletion!
                })
            }
        }
    }
}

// MARK: - Detail Row Component

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Text.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Text.primary)
        }
    }
}
