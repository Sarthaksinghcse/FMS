//
//  ScheduleCardView.swift
//  FMS
//
//  Created by Antigravity on 22/05/26.
//

import SwiftUI

// MARK: - Schedule Card Model

struct ScheduleCardModel: Identifiable, Equatable {
    let id: UUID
    let vehicleImage: String
    let vehicleName: String
    let serviceType: String
    let timeText: String
    let bayText: String
    let status: String
    let date: Int
    
    init(id: UUID = UUID(), vehicleImage: String, vehicleName: String, serviceType: String, timeText: String, bayText: String, status: String, date: Int) {
        self.id = id
        self.vehicleImage = vehicleImage
        self.vehicleName = vehicleName
        self.serviceType = serviceType
        self.timeText = timeText
        self.bayText = bayText
        self.status = status
        self.date = date
    }
}

// MARK: - Unified Schedule Card View

struct ScheduleCardView: View {
    let model: ScheduleCardModel
    
    /// Initializes `ScheduleCardView` with a pre-configured `ScheduleCardModel`
    init(model: ScheduleCardModel) {
        self.model = model
    }
    
    /// Convenience initializer to support direct parameter-based initialization (e.g. from the Dashboard view)
    init(vehicleImage: String, vehicleName: String, serviceType: String, timeText: String, bayText: String, status: String = "Scheduled", date: Int = 22) {
        self.model = ScheduleCardModel(
            vehicleImage: vehicleImage,
            vehicleName: vehicleName,
            serviceType: serviceType,
            timeText: timeText,
            bayText: bayText,
            status: status,
            date: date
        )
    }
    
    private var statusColor: Color {
        switch model.status {
        case "Completed":
            return Color(red: 39/255, green: 174/255, blue: 96/255)
        case "In Progress":
            return Color(red: 236/255, green: 110/255, blue: 37/255)
        default:
            return AppTheme.Brand.royalBlue
        }
    }
    
    private var statusBgColor: Color {
        statusColor.opacity(0.08)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: model.vehicleImage)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        Color.gray.opacity(0.1)
                        Image(systemName: "truck.box.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .cornerRadius(12)
            .clipped()
            
            VStack(alignment: .leading, spacing: 6) {
                Text(model.vehicleName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                
                Text(model.serviceType)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Brand.royalBlue)
                        Text(model.timeText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Brand.royalBlue)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Text.tertiary)
                        Text(model.bayText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Text(model.status)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusBgColor)
                    .cornerRadius(8)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.Text.tertiary.opacity(0.5))
            }
        }
        .padding(12)
        .background(AppTheme.Background.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1.5)
        )
    }
}
