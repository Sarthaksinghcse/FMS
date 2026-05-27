//
//  PredictiveAlertDetailView.swift
//  FMS
//
//  Created by Naman Yadav on 27/05/26.
//

import SwiftUI
import SwiftData

struct PredictiveAlertDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var vehicles: [Vehicle]
    @Query private var staff: [User]
    
    @State private var showingWorkOrderSheet = false
    
    private var truck12: Vehicle? {
        vehicles.first { $0.registrationNumber.contains("12") || $0.model.contains("Truck 12") }
    }
    
    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Diagnostic Status Header Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppTheme.Brand.royalBlue.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "cpu.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppTheme.Brand.royalBlue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SMART TELEMATICS DETECTED")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.Brand.royalBlue)
                                Text("Brake Pad Wear Threshold Alert")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Text.primary)
                            }
                            Spacer()
                            
                            Text("CRITICAL")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.Status.danger)
                                .cornerRadius(6)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Diagnostic Summary")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.primary)
                            
                            Text("Sensor #BRK-409 on the front-left axle of **Truck 12** reports brake pad thickness has worn down to **2.4mm** (Safety Limit: **3.0mm**). The system predicts potential safety threshold violations and braking inefficiency within approximately **7 operating days**.")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Text.secondary)
                                .lineSpacing(4)
                        }
                    }
                    .padding(16)
                    .background(AppTheme.Background.card)
                    .cornerRadius(AppTheme.Radius.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                            .stroke(AppTheme.Glass.border, lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Live Sensor Trend Chart (Visual Simulation)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Brake Thickness Trend (Last 30 Days)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.primary)
                        
                        // Fake line chart representation
                        HStack(alignment: .bottom, spacing: 14) {
                            ForEach(0..<6) { idx in
                                let thickness: Double = 6.0 - Double(idx) * 0.72
                                let pct = CGFloat(thickness / 6.0)
                                VStack(spacing: 6) {
                                    Text(String(format: "%.1f", thickness))
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(pct < 0.5 ? AppTheme.Status.danger : AppTheme.Text.secondary)
                                    
                                    ZStack(alignment: .bottom) {
                                        Capsule()
                                            .fill(AppTheme.Glass.ringTrack)
                                            .frame(width: 24, height: 100)
                                        
                                        Capsule()
                                            .fill(pct < 0.5 ? AppTheme.Status.danger : AppTheme.Brand.royalBlue)
                                            .frame(width: 24, height: 100 * pct)
                                    }
                                    
                                    Text("Wk \(idx + 1)")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(AppTheme.Text.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Circle().fill(AppTheme.Brand.royalBlue).frame(width: 8, height: 8)
                                Text("Healthy Stock").font(.system(size: 10)).foregroundColor(AppTheme.Text.secondary)
                            }
                            HStack(spacing: 6) {
                                Circle().fill(AppTheme.Status.danger).frame(width: 8, height: 8)
                                Text("Critical Wear (< 3.0mm)").font(.system(size: 10)).foregroundColor(AppTheme.Text.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .background(AppTheme.Background.card)
                    .cornerRadius(AppTheme.Radius.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                            .stroke(AppTheme.Glass.border, lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Vehicle Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Associated Vehicle details")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.primary)
                        
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppTheme.Brand.royalBlue.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "truck.box.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(AppTheme.Brand.royalBlue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(truck12?.model ?? "Truck 12 (Heavy Duty)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.Text.primary)
                                Text("Reg No: \(truck12?.registrationNumber ?? "MH-12-AB-3456")")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Text.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Background.card)
                    .cornerRadius(AppTheme.Radius.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                            .stroke(AppTheme.Glass.border, lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Recommendation & Action Button
                    VStack(spacing: 12) {
                        Button {
                            showingWorkOrderSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                Text("Schedule Work Order Now")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.Brand.royalBlue)
                            .cornerRadius(12)
                            .shadow(color: AppTheme.Shadow.primaryGlow(opacity: 0.2), radius: 6, y: 3)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("AI Smart Diagnostic")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingWorkOrderSheet) {
            NavigationStack {
                CreateWorkOrderView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        PredictiveAlertDetailView()
    }
}
