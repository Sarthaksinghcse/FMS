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
            iconColor: AppTheme.Brand.primary,
            iconBgColor: AppTheme.IconBg.blue,
            value: "48",
            label: "Total Vehicles",
            trend: "↗ 8%",
            isTrendPositive: true,
            graphData: [10, 15, 12, 18, 14, 20, 18, 22]
        ),
        DashboardStat(
            icon: "location.fill",
            iconColor: AppTheme.Status.success,
            iconBgColor: AppTheme.IconBg.green,
            value: "32",
            label: "Active Now",
            trend: "↗ 12%",
            isTrendPositive: true,
            graphData: [12, 11, 14, 13, 16, 15, 17, 16]
        ),
        DashboardStat(
            icon: "person.2.fill",
            iconColor: AppTheme.Brand.violet,
            iconBgColor: AppTheme.IconBg.violet,
            value: "28",
            label: "Drivers Online",
            trend: "↗ 5%",
            isTrendPositive: true,
            graphData: [8, 12, 10, 11, 9, 13, 11, 12]
        ),
        DashboardStat(
            icon: "arrow.up.arrow.down",
            iconColor: AppTheme.Brand.teal,
            iconBgColor: AppTheme.IconBg.teal,
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
            iconColor: AppTheme.Brand.primary,
            bgColor: AppTheme.IconBg.blue,
            label: "Add Vehicle"
        ),
        DashboardQuickAction(
            icon: "person.badge.plus",
            iconColor: AppTheme.Brand.violet,
            bgColor: AppTheme.IconBg.violet,
            label: "Assign Driver"
        ),
        DashboardQuickAction(
            icon: "chart.bar.fill",
            iconColor: AppTheme.Brand.teal,
            bgColor: AppTheme.IconBg.teal,
            label: "Reports"
        ),
        DashboardQuickAction(
            icon: "exclamationmark.octagon.fill",
            iconColor: AppTheme.Status.danger,
            bgColor: AppTheme.IconBg.red,
            label: "Alerts"
        ),
        DashboardQuickAction(
            icon: "wrench.and.screwdriver.fill",
            iconColor: AppTheme.Brand.amber,
            bgColor: AppTheme.IconBg.amber,
            label: "Maintenance"
        )
    ]

    static let activities: [DashboardActivity] = [
        DashboardActivity(
            title: "Trip #1842 Started",
            subtitle: "Priyanshu N. → Nehru Place",
            time: "1 hr ago",
            icon: "arrow.turn.up.right",
            iconColor: AppTheme.Brand.primary,
            iconBgColor: AppTheme.IconBg.blue
        ),
        DashboardActivity(
            title: "Trip #1839 Completed",
            subtitle: "Amit K. delivered to Noida Sec 62",
            time: "1 hr ago",
            icon: "checkmark.seal.fill",
            iconColor: AppTheme.Status.success,
            iconBgColor: AppTheme.IconBg.green
        ),
        DashboardActivity(
            title: "Overspeeding Alert",
            subtitle: "Tata Intra V30 • 92 km/h",
            time: "2 hr ago",
            icon: "exclamationmark.triangle.fill",
            iconColor: AppTheme.Status.danger,
            iconBgColor: AppTheme.IconBg.red
        ),
        DashboardActivity(
            title: "Maintenance Scheduled",
            subtitle: "Force Traveller • Oil Change",
            time: "2 hr ago",
            icon: "wrench.fill",
            iconColor: AppTheme.Brand.violet,
            iconBgColor: AppTheme.IconBg.violet
        ),
        DashboardActivity(
            title: "Driver Shift Started",
            subtitle: "Deepak M. clocked in",
            time: "2 hr ago",
            icon: "person.badge.clock.fill",
            iconColor: AppTheme.Brand.amber,
            iconBgColor: AppTheme.IconBg.amber
        )
    ]
}
