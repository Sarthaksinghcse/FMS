//
//  DashboardModels.swift
//  FMS
//
//  Created by Antigravity on 21/05/26.
//

import SwiftUI

struct DashboardStat: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let iconBgColor: Color
    let value: String
    let label: String
    let trend: String
    let isTrendPositive: Bool
    let graphData: [Double]
}

struct DashboardQuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let bgColor: Color
    let label: String
}

struct DashboardActivity: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let time: String
    let icon: String
    let iconColor: Color
    let iconBgColor: Color
}
