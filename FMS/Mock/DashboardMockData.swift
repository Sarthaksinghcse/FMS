//
//  DashboardMockData.swift
//  FMS
//
//  Created by Antigravity on 21/05/26.
//

import SwiftUI

struct DashboardMockData {
    static let stats: [DashboardStat] = [
        DashboardStat(
            icon: "car.fill",
            iconColor: Color(red: 0.2, green: 0.5, blue: 1.0),
            iconBgColor: Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.12),
            value: "48",
            label: "Total Vehicles",
            trend: "↗ 8%",
            isTrendPositive: true,
            graphData: [10, 15, 12, 18, 14, 20, 18, 22]
        ),
        DashboardStat(
            icon: "location.fill",
            iconColor: Color(red: 0.15, green: 0.75, blue: 0.45),
            iconBgColor: Color(red: 0.15, green: 0.75, blue: 0.45).opacity(0.12),
            value: "32",
            label: "Active Now",
            trend: "↗ 12%",
            isTrendPositive: true,
            graphData: [12, 11, 14, 13, 16, 15, 17, 16]
        ),
        DashboardStat(
            icon: "person.2.fill",
            iconColor: Color(red: 0.55, green: 0.35, blue: 0.95),
            iconBgColor: Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.12),
            value: "28",
            label: "Drivers Online",
            trend: "↗ 5%",
            isTrendPositive: true,
            graphData: [8, 12, 10, 11, 9, 13, 11, 12]
        ),
        DashboardStat(
            icon: "arrow.up.arrow.down",
            iconColor: Color(red: 0.05, green: 0.75, blue: 0.65),
            iconBgColor: Color(red: 0.05, green: 0.75, blue: 0.65).opacity(0.12),
            value: "15",
            label: "Live Trips",
            trend: "↘ 3%",
            isTrendPositive: false,
            graphData: [15, 13, 16, 12, 10, 12, 9, 11]
        )
    ]

    static let quickActions: [DashboardQuickAction] = [
        DashboardQuickAction(
            icon: "plus",
            iconColor: Color(red: 0.2, green: 0.5, blue: 1.0),
            bgColor: Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.12),
            label: "Add Vehicle"
        ),
        DashboardQuickAction(
            icon: "person.badge.plus",
            iconColor: Color(red: 0.55, green: 0.35, blue: 0.95),
            bgColor: Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.12),
            label: "Assign Driver"
        ),
        DashboardQuickAction(
            icon: "chart.bar.fill",
            iconColor: Color(red: 0.05, green: 0.75, blue: 0.65),
            bgColor: Color(red: 0.05, green: 0.75, blue: 0.65).opacity(0.12),
            label: "Reports"
        ),
        DashboardQuickAction(
            icon: "exclamationmark.octagon.fill",
            iconColor: Color(red: 0.95, green: 0.3, blue: 0.3),
            bgColor: Color(red: 0.95, green: 0.3, blue: 0.3).opacity(0.1),
            label: "Alerts"
        ),
        DashboardQuickAction(
            icon: "wrench.and.screwdriver.fill",
            iconColor: Color(red: 1.0, green: 0.6, blue: 0.1),
            bgColor: Color(red: 1.0, green: 0.6, blue: 0.1).opacity(0.12),
            label: "Maintenance"
        )
    ]

    static let activities: [DashboardActivity] = [
        DashboardActivity(
            title: "Trip #1842 Started",
            subtitle: "Priyanshu N. → Nehru Place",
            time: "1 hr ago",
            icon: "arrow.turn.up.right",
            iconColor: Color(red: 0.2, green: 0.5, blue: 1.0),
            iconBgColor: Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.12)
        ),
        DashboardActivity(
            title: "Trip #1839 Completed",
            subtitle: "Amit K. delivered to Noida Sec 62",
            time: "1 hr ago",
            icon: "checkmark.seal.fill",
            iconColor: Color(red: 0.15, green: 0.75, blue: 0.45),
            iconBgColor: Color(red: 0.15, green: 0.75, blue: 0.45).opacity(0.12)
        ),
        DashboardActivity(
            title: "Overspeeding Alert",
            subtitle: "Tata Intra V30 • 92 km/h",
            time: "2 hr ago",
            icon: "exclamationmark.triangle.fill",
            iconColor: Color(red: 0.95, green: 0.3, blue: 0.3),
            iconBgColor: Color(red: 0.95, green: 0.3, blue: 0.3).opacity(0.1)
        ),
        DashboardActivity(
            title: "Maintenance Scheduled",
            subtitle: "Force Traveller • Oil Change",
            time: "2 hr ago",
            icon: "wrench.fill",
            iconColor: Color(red: 0.55, green: 0.35, blue: 0.95),
            iconBgColor: Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.12)
        ),
        DashboardActivity(
            title: "Driver Shift Started",
            subtitle: "Deepak M. clocked in",
            time: "2 hr ago",
            icon: "person.badge.clock.fill",
            iconColor: Color(red: 1.0, green: 0.6, blue: 0.1),
            iconBgColor: Color(red: 1.0, green: 0.6, blue: 0.1).opacity(0.12)
        )
    ]
}
