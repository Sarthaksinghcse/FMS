//
//  StatCard.swift
//  FMS
//
//  Created by Antigravity on 21/05/26.
//

import SwiftUI

struct SparklineView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        Path { path in
            guard data.count > 1 else { return }
            
            // Normalize and scale points to fit a normalized [0, 1] space
            let minVal = data.min() ?? 0
            let maxVal = data.max() ?? 1
            let range = maxVal - minVal == 0 ? 1 : maxVal - minVal
            
            let points = data.enumerated().map { index, value -> CGPoint in
                let x = CGFloat(index) / CGFloat(data.count - 1)
                let y = 1.0 - CGFloat(value - minVal) / CGFloat(range)
                return CGPoint(x: x, y: y)
            }
            
            // Draw a smooth curved line using cubic Bezier points
            path.move(to: points[0])
            for i in 1..<points.count {
                let p0 = points[i-1]
                let p1 = points[i]
                let controlPoint1 = CGPoint(x: p0.x + (p1.x - p0.x) / 2, y: p0.y)
                let controlPoint2 = CGPoint(x: p0.x + (p1.x - p0.x) / 2, y: p1.y)
                path.addCurve(to: p1, control1: controlPoint1, control2: controlPoint2)
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .background(
            // Optional subtle gradient fill under the line
            GeometryReader { geometry in
                Path { path in
                    guard data.count > 1 else { return }
                    let minVal = data.min() ?? 0
                    let maxVal = data.max() ?? 1
                    let range = maxVal - minVal == 0 ? 1 : maxVal - minVal
                    
                    let points = data.enumerated().map { index, value -> CGPoint in
                        let x = CGFloat(index) / CGFloat(data.count - 1)
                        let y = 1.0 - CGFloat(value - minVal) / CGFloat(range)
                        return CGPoint(x: x, y: y)
                    }
                    
                    path.move(to: points[0])
                    for i in 1..<points.count {
                        let p0 = points[i-1]
                        let p1 = points[i]
                        let controlPoint1 = CGPoint(x: p0.x + (p1.x - p0.x) / 2, y: p0.y)
                        let controlPoint2 = CGPoint(x: p0.x + (p1.x - p0.x) / 2, y: p1.y)
                        path.addCurve(to: p1, control1: controlPoint1, control2: controlPoint2)
                    }
                    
                    // Close the path to the bottom
                    path.addLine(to: CGPoint(x: 1.0, y: 1.0))
                    path.addLine(to: CGPoint(x: 0.0, y: 1.0))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.15), color.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(x: 1, y: 1, anchor: .center)
            }
        )
    }
}

struct DashboardStatCard: View {
    let stat: DashboardStat

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Row: Icon and Trend Badge
            HStack(alignment: .top) {
                // Icon Container
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(stat.iconBgColor)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: stat.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(stat.iconColor)
                }
                
                Spacer()
                
                // Trend Badge
                Text(stat.trend)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(stat.isTrendPositive ? Color(red: 0.15, green: 0.75, blue: 0.45) : Color(red: 0.95, green: 0.3, blue: 0.3))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(stat.isTrendPositive ? Color(red: 0.15, green: 0.75, blue: 0.45).opacity(0.1) : Color(red: 0.95, green: 0.3, blue: 0.3).opacity(0.1))
                    )
            }
            
            // Value
            Text(stat.value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .padding(.top, 4)
            
            // Bottom Row: Label & Sparkline
            HStack(alignment: .bottom) {
                Text(stat.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Sized Sparkline
                SparklineView(data: stat.graphData, color: stat.iconColor)
                    .frame(width: 48, height: 16)
                    .padding(.bottom, 2)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        DashboardStatCard(stat: DashboardMockData.stats[0])
        DashboardStatCard(stat: DashboardMockData.stats[3])
    }
    .padding()
    .background(Color(red: 0.97, green: 0.98, blue: 1.0))
}
