// FMS/Services/Fleet Manager/WorkOrderPDFGenerator.swift
import UIKit
import SwiftUI

final class WorkOrderPDFGenerator {
    
    // MARK: - Color Palette
    private static let primaryBlue = UIColor(red: 0.15, green: 0.38, blue: 0.90, alpha: 1.0)     // Theme.royalBlue
    private static let darkOrange = UIColor(red: 0.93, green: 0.46, blue: 0.0, alpha: 1.0)       // Theme.darkOrange
    private static let lightBlueBg = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1.0)     // AppTheme.Background.page
    private static let borderGray = UIColor(red: 0.88, green: 0.90, blue: 0.93, alpha: 1.0)
    
    private static let textPrimary = UIColor(red: 0.11, green: 0.14, blue: 0.19, alpha: 1.0)
    private static let textSecondary = UIColor.secondaryLabel
    private static let textMuted = UIColor.tertiaryLabel
    
    // MARK: - Main PDF Generator
    static func generatePDFData(
        order: WorkOrder,
        vehicle: Vehicle?,
        technician: User?,
        maintenanceRecord: MaintenanceRecord?,
        partsCost: Double,
        laborCost: Double,
        additionalCost: Double
    ) -> Data {
        let pageWidth: CGFloat  = 612   // US Letter Width
        let pageHeight: CGFloat = 792   // US Letter Height
        let margin: CGFloat     = 40
        let contentWidth        = pageWidth - margin * 2
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin
            
            // --- Helper: check space and add new page ---
            func ensureSpace(heightNeeded: CGFloat) {
                if y + heightNeeded > pageHeight - margin - 30 {
                    context.beginPage()
                    y = margin
                    drawPageFooter(context: context, pageHeight: pageHeight, margin: margin, dateFormatter: dateFormatter)
                }
            }
            
            // Draw page footer on the first page as well
            drawPageFooter(context: context, pageHeight: pageHeight, margin: margin, dateFormatter: dateFormatter)
            
            // ─── 1. HEADER BANNER ───────────────────────────────────────────
            ensureSpace(heightNeeded: 110)
            y = drawHeaderBanner(
                order: order,
                context: context,
                y: y,
                x: margin,
                width: contentWidth,
                dateFormatter: dateFormatter
            )
            y += 20
            
            // ─── 2. VEHICLE DETAILS SECTION ────────────────────────────────
            ensureSpace(heightNeeded: 140)
            y = drawVehicleSection(
                vehicle: vehicle,
                context: context,
                y: y,
                x: margin,
                width: contentWidth
            )
            y += 20
            
            // ─── 3. REPAIR DETAILS SECTION ─────────────────────────────────
            // Description can be long, so we estimate text size first
            let descriptionFont = UIFont.systemFont(ofSize: 11, weight: .regular)
            let descWidth = contentWidth - 24
            let descHeight = estimateTextHeight(order.workDescription, font: descriptionFont, width: descWidth)
            ensureSpace(heightNeeded: 120 + descHeight)
            
            y = drawRepairSection(
                order: order,
                technician: technician,
                maintenanceRecord: maintenanceRecord,
                context: context,
                y: y,
                x: margin,
                width: contentWidth,
                descHeight: descHeight,
                descriptionFont: descriptionFont
            )
            y += 20
            
            // ─── 4. FINANCIAL SUMMARY ──────────────────────────────────────
            let totalSummaryHeight: CGFloat = 135
            
            // If the whole section cannot fit, let's start it on a new page.
            if y + totalSummaryHeight > pageHeight - margin - 30 {
                context.beginPage()
                y = margin
                drawPageFooter(context: context, pageHeight: pageHeight, margin: margin, dateFormatter: dateFormatter)
            }
            
            y = drawSectionHeader("FINANCIAL SUMMARY", context: context, y: y, x: margin)
            y += 8
            
            // Overall cost and approval
            ensureSpace(heightNeeded: totalSummaryHeight)
            y = drawFinalCostSummary(
                order: order,
                maintenanceRecord: maintenanceRecord,
                partsCost: partsCost,
                laborCost: laborCost,
                additionalCost: additionalCost,
                context: context,
                y: y,
                x: margin,
                width: contentWidth
            )
        }
        
        return data
    }
    
    // MARK: - Drawing Components
    
    private static func drawHeaderBanner(
        order: WorkOrder,
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        x: CGFloat,
        width: CGFloat,
        dateFormatter: DateFormatter
    ) -> CGFloat {
        let cgContext = context.cgContext
        let height: CGFloat = 90
        
        // Draw Light Blue Banner Background
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        cgContext.saveGState()
        lightBlueBg.setFill()
        path.fill()
        
        // Draw primary blue left accent bar
        let leftBarRect = CGRect(x: x, y: y, width: 6, height: height)
        let leftBarPath = UIBezierPath(roundedRect: leftBarRect, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 10, height: 10))
        primaryBlue.setFill()
        leftBarPath.fill()
        cgContext.restoreGState()
        
        // Title Text
        let titleFont = UIFont.systemFont(ofSize: 18, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: primaryBlue
        ]
        let titleStr = "MAINTENANCE WORK ORDER REPORT"
        (titleStr as NSString).draw(at: CGPoint(x: x + 20, y: y + 16), withAttributes: titleAttrs)
        
        // WO ID & Date
        let detailsFont = UIFont.systemFont(ofSize: 10, weight: .medium)
        let detailsAttrs: [NSAttributedString.Key: Any] = [
            .font: detailsFont,
            .foregroundColor: textSecondary
        ]
        let idStr = "Work Order ID: WO-\(order.id.uuidString.prefix(6).uppercased())  •  Date: \(dateFormatter.string(from: order.createdAt))"
        (idStr as NSString).draw(at: CGPoint(x: x + 20, y: y + 42), withAttributes: detailsAttrs)
        
        // Priority & Status Badges (drawn right-aligned)
        let badgeY = y + 16
        var badgeX = x + width - 20
        
        // Status Badge
        let statusText = currentStatusText(for: order).uppercased()
        let statusColor = getStatusColor(for: order)
        let statusFont = UIFont.systemFont(ofSize: 9, weight: .bold)
        let statusSize = (statusText as NSString).size(withAttributes: [.font: statusFont])
        let statusBadgeWidth = statusSize.width + 16
        let statusBadgeHeight: CGFloat = 20
        
        badgeX -= statusBadgeWidth
        let statusRect = CGRect(x: badgeX, y: badgeY, width: statusBadgeWidth, height: statusBadgeHeight)
        let statusPath = UIBezierPath(roundedRect: statusRect, cornerRadius: 5)
        cgContext.saveGState()
        statusColor.setFill()
        statusPath.fill()
        cgContext.restoreGState()
        
        let statusTextAttrs: [NSAttributedString.Key: Any] = [
            .font: statusFont,
            .foregroundColor: UIColor.white
        ]
        (statusText as NSString).draw(
            at: CGPoint(x: badgeX + 8, y: badgeY + (statusBadgeHeight - statusSize.height)/2),
            withAttributes: statusTextAttrs
        )
        
        // Priority Badge
        badgeX -= 10 // Spacing
        let priorityText = order.priority.rawValue.uppercased()
        let priorityColor = order.priority == .urgent || order.priority == .high ? darkOrange : primaryBlue
        let prioritySize = (priorityText as NSString).size(withAttributes: [.font: statusFont])
        let priorityBadgeWidth = prioritySize.width + 16
        
        badgeX -= priorityBadgeWidth
        let priorityRect = CGRect(x: badgeX, y: badgeY, width: priorityBadgeWidth, height: statusBadgeHeight)
        let priorityPath = UIBezierPath(roundedRect: priorityRect, cornerRadius: 5)
        cgContext.saveGState()
        priorityColor.withAlphaComponent(0.12).setFill()
        priorityPath.fill()
        cgContext.restoreGState()
        
        let priorityTextAttrs: [NSAttributedString.Key: Any] = [
            .font: statusFont,
            .foregroundColor: priorityColor
        ]
        (priorityText as NSString).draw(
            at: CGPoint(x: badgeX + 8, y: badgeY + (statusBadgeHeight - prioritySize.height)/2),
            withAttributes: priorityTextAttrs
        )
        
        return y + height
    }
    
    private static func drawVehicleSection(
        vehicle: Vehicle?,
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        x: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let cgContext = context.cgContext
        var currentY = drawSectionHeader("VEHICLE INFORMATION", context: context, y: y, x: x)
        currentY += 8
        
        let height: CGFloat = 90
        let rect = CGRect(x: x, y: currentY, width: width, height: height)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        
        cgContext.saveGState()
        cgContext.setStrokeColor(borderGray.cgColor)
        cgContext.setLineWidth(1)
        path.stroke()
        cgContext.restoreGState()
        
        // Left offset for details (shifted left because vehicle logo is removed)
        let detailsX = x + 20
        let labelFont = UIFont.systemFont(ofSize: 9, weight: .bold)
        let valFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: textSecondary]
        let valAttrs: [NSAttributedString.Key: Any] = [.font: valFont, .foregroundColor: textPrimary]
        
        let colWidth = (width - 40) / 2
        
        // Row 1
        let row1Y = currentY + 18
        ("REGISTRATION NUMBER" as NSString).draw(at: CGPoint(x: detailsX, y: row1Y), withAttributes: labelAttrs)
        ((vehicle?.registrationNumber ?? "N/A") as NSString).draw(at: CGPoint(x: detailsX, y: row1Y + 12), withAttributes: valAttrs)
        
        ("MAKE & MODEL" as NSString).draw(at: CGPoint(x: detailsX + colWidth, y: row1Y), withAttributes: labelAttrs)
        ("\(vehicle?.make ?? "N/A") \(vehicle?.model ?? "")" as NSString).draw(at: CGPoint(x: detailsX + colWidth, y: row1Y + 12), withAttributes: valAttrs)
        
        // Row 2
        let row2Y = currentY + 50
        ("FUEL TYPE" as NSString).draw(at: CGPoint(x: detailsX, y: row2Y), withAttributes: labelAttrs)
        ((vehicle?.fuelType.displayName ?? "N/A") as NSString).draw(at: CGPoint(x: detailsX, y: row2Y + 12), withAttributes: valAttrs)
        
        ("CURRENT ODOMETER" as NSString).draw(at: CGPoint(x: detailsX + colWidth, y: row2Y), withAttributes: labelAttrs)
        let odometer = vehicle != nil ? "\(Int(vehicle!.odometerReading)) km" : "N/A"
        (odometer as NSString).draw(at: CGPoint(x: detailsX + colWidth, y: row2Y + 12), withAttributes: valAttrs)
        
        return currentY + height
    }
    
    private static func drawRepairSection(
        order: WorkOrder,
        technician: User?,
        maintenanceRecord: MaintenanceRecord?,
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        x: CGFloat,
        width: CGFloat,
        descHeight: CGFloat,
        descriptionFont: UIFont
    ) -> CGFloat {
        let cgContext = context.cgContext
        var currentY = drawSectionHeader("REPAIR & EXECUTION DETAILS", context: context, y: y, x: x)
        currentY += 8
        
        let headerDetailsHeight: CGFloat = 50
        let padding: CGFloat = 12
        let totalHeight = headerDetailsHeight + descHeight + padding * 3
        
        let rect = CGRect(x: x, y: currentY, width: width, height: totalHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        
        cgContext.saveGState()
        cgContext.setStrokeColor(borderGray.cgColor)
        cgContext.setLineWidth(1)
        path.stroke()
        cgContext.restoreGState()
        
        let labelFont = UIFont.systemFont(ofSize: 9, weight: .bold)
        let valFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: textSecondary]
        let valAttrs: [NSAttributedString.Key: Any] = [.font: valFont, .foregroundColor: textPrimary]
        
        let colWidth = (width - 24) / 2
        
        // Technician and Service Title
        let detailsY = currentY + padding
        ("REPAIR TASK TITLE" as NSString).draw(at: CGPoint(x: x + padding, y: detailsY), withAttributes: labelAttrs)
        (order.title as NSString).draw(at: CGPoint(x: x + padding, y: detailsY + 12), withAttributes: valAttrs)
        
        ("ASSIGNED TECHNICIAN" as NSString).draw(at: CGPoint(x: x + padding + colWidth, y: detailsY), withAttributes: labelAttrs)
        let techName = technician?.fullName ?? "Unassigned"
        (techName as NSString).draw(at: CGPoint(x: x + padding + colWidth, y: detailsY + 12), withAttributes: valAttrs)
        
        // Work Description Box
        let descY = detailsY + 36
        ("WORK DESCRIPTION & INSTRUCTIONS" as NSString).draw(at: CGPoint(x: x + padding, y: descY), withAttributes: labelAttrs)
        
        let descTextY = descY + 12
        _ = drawMultilineText(
            order.workDescription,
            font: descriptionFont,
            color: textPrimary,
            context: context,
            y: descTextY,
            x: x + padding,
            width: width - padding * 2
        )
        
        return currentY + totalHeight
    }
    
    private static func drawSuggestedPartsTable(
        parts: [WorkOrderCostEstimate.SuggestedPart],
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        x: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let titleFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: primaryBlue]
        ("Required Parts & Materials (AI Recommended)" as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: titleAttrs)
        
        var currentY = y + 18
        
        // Table Header
        let thFont = UIFont.systemFont(ofSize: 9, weight: .bold)
        let thAttrs: [NSAttributedString.Key: Any] = [.font: thFont, .foregroundColor: textSecondary]
        
        ("PART NAME / NUMBER" as NSString).draw(at: CGPoint(x: x + 6, y: currentY), withAttributes: thAttrs)
        ("QTY" as NSString).draw(at: CGPoint(x: x + width - 180, y: currentY), withAttributes: thAttrs)
        ("UNIT COST" as NSString).draw(at: CGPoint(x: x + width - 120, y: currentY), withAttributes: thAttrs)
        ("TOTAL" as NSString).draw(at: CGPoint(x: x + width - 50, y: currentY), withAttributes: thAttrs)
        
        currentY += 15
        
        // Divider
        currentY = drawSubDivider(context: context, y: currentY, x: x, width: width)
        
        let cellFont = UIFont.systemFont(ofSize: 10, weight: .medium)
        let cellValFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let cellAttrs: [NSAttributedString.Key: Any] = [.font: cellFont, .foregroundColor: textPrimary]
        let cellValAttrs: [NSAttributedString.Key: Any] = [.font: cellValFont, .foregroundColor: textPrimary]
        
        for part in parts {
            // Part Name and Number
            let partText = "\(part.partName)\n(Part #: \(part.partNumber))"
            let partHeight = estimateTextHeight(partText, font: cellFont, width: width - 250)
            
            _ = drawMultilineText(
                partText,
                font: cellFont,
                color: textPrimary,
                context: context,
                y: currentY + 4,
                x: x + 6,
                width: width - 250
            )
            
            // Qty
            ("\(part.quantity)" as NSString).draw(
                at: CGPoint(x: x + width - 180, y: currentY + 4),
                withAttributes: cellAttrs
            )
            
            // Unit Cost
            ("₹\(String(format: "%.2f", part.unitCost))" as NSString).draw(
                at: CGPoint(x: x + width - 120, y: currentY + 4),
                withAttributes: cellAttrs
            )
            
            // Total
            let totalCost = part.unitCost * Double(part.quantity)
            ("₹\(String(format: "%.2f", totalCost))" as NSString).draw(
                at: CGPoint(x: x + width - 50, y: currentY + 4),
                withAttributes: cellValAttrs
            )
            
            currentY += max(24, partHeight + 8)
            currentY = drawSubDivider(context: context, y: currentY, x: x, width: width)
        }
        
        return currentY
    }
    
    private static func drawLaborAndMiscSection(
        estimate: WorkOrderCostEstimate,
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        x: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let cgContext = context.cgContext
        
        let titleFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: textPrimary]
        ("Labor & Miscellaneous Estimations" as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: titleAttrs)
        
        let currentY = y + 18
        
        let rect = CGRect(x: x, y: currentY, width: width, height: 80)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        
        cgContext.saveGState()
        cgContext.setStrokeColor(borderGray.cgColor)
        cgContext.setLineWidth(0.8)
        path.stroke()
        cgContext.restoreGState()
        
        let labelFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let detailFont = UIFont.systemFont(ofSize: 10, weight: .regular)
        let valFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: textPrimary]
        let detailAttrs: [NSAttributedString.Key: Any] = [.font: detailFont, .foregroundColor: textSecondary]
        let valAttrs: [NSAttributedString.Key: Any] = [.font: valFont, .foregroundColor: textPrimary]
        
        // Labor
        let laborY = currentY + 12
        ("Estimated Labor" as NSString).draw(at: CGPoint(x: x + 12, y: laborY), withAttributes: labelAttrs)
        let laborSub = "\(String(format: "%.1f", estimate.laborHours)) Hrs @ ₹\(String(format: "%.0f", estimate.laborRatePerHour))/Hr"
        (laborSub as NSString).draw(at: CGPoint(x: x + 12, y: laborY + 14), withAttributes: detailAttrs)
        
        let laborCostText = "₹\(String(format: "%.2f", estimate.laborCost))"
        let laborCostSize = (laborCostText as NSString).size(withAttributes: valAttrs)
        (laborCostText as NSString).draw(at: CGPoint(x: x + width - laborCostSize.width - 12, y: laborY + 6), withAttributes: valAttrs)
        
        // Divider inside box
        cgContext.saveGState()
        cgContext.setStrokeColor(borderGray.cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.move(to: CGPoint(x: x + 12, y: currentY + 40))
        cgContext.addLine(to: CGPoint(x: x + width - 12, y: currentY + 40))
        cgContext.strokePath()
        cgContext.restoreGState()
        
        // Miscellaneous
        let miscY = currentY + 48
        ("Additional / Miscellaneous Costs" as NSString).draw(at: CGPoint(x: x + 12, y: miscY), withAttributes: labelAttrs)
        let miscSub = estimate.additionalReason.isEmpty ? "Disposal, workshop supplies, clean up" : estimate.additionalReason
        (miscSub as NSString).draw(at: CGPoint(x: x + 12, y: miscY + 14), withAttributes: detailAttrs)
        
        let miscCostText = "₹\(String(format: "%.2f", estimate.additionalCosts))"
        let miscCostSize = (miscCostText as NSString).size(withAttributes: valAttrs)
        (miscCostText as NSString).draw(at: CGPoint(x: x + width - miscCostSize.width - 12, y: miscY + 6), withAttributes: valAttrs)
        
        return currentY + 80
    }
    
    private static func drawFinalCostSummary(
        order: WorkOrder,
        maintenanceRecord: MaintenanceRecord?,
        partsCost: Double,
        laborCost: Double,
        additionalCost: Double,
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        x: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let cgContext = context.cgContext
        
        let actualCost = maintenanceRecord?.cost ?? order.estimatedCost ?? 0.0
        
        var finalParts = partsCost
        var finalLabor = laborCost
        let finalAdditional = additionalCost
        
        // Fallback: If parts, labor, and additional are all zero but we have an actual cost, split 40/60.
        if finalParts == 0 && finalLabor == 0 && finalAdditional == 0 && actualCost > 0 {
            finalParts = actualCost * 0.4
            finalLabor = actualCost * 0.6
        }
        
        let height: CGFloat = 135
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        
        cgContext.saveGState()
        primaryBlue.withAlphaComponent(0.04).setFill()
        path.fill()
        cgContext.setStrokeColor(primaryBlue.withAlphaComponent(0.2).cgColor)
        cgContext.setLineWidth(1)
        path.stroke()
        cgContext.restoreGState()
        
        let labelFont = UIFont.systemFont(ofSize: 10, weight: .medium)
        let valFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let totalLabelFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        let totalValFont = UIFont.systemFont(ofSize: 14, weight: .bold)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: textSecondary]
        let valAttrs: [NSAttributedString.Key: Any] = [.font: valFont, .foregroundColor: textPrimary]
        
        var currentY = y + 12
        
        // Parts Row (Left Aligned label, Right Aligned amount)
        ("Parts Subtotal" as NSString).draw(at: CGPoint(x: x + 16, y: currentY), withAttributes: labelAttrs)
        let partsStr = "₹\(String(format: "%.2f", finalParts))"
        let partsSize = (partsStr as NSString).size(withAttributes: valAttrs)
        (partsStr as NSString).draw(at: CGPoint(x: x + width - partsSize.width - 16, y: currentY), withAttributes: valAttrs)
        
        currentY += 20
        
        // Labor Row
        ("Labor Subtotal" as NSString).draw(at: CGPoint(x: x + 16, y: currentY), withAttributes: labelAttrs)
        let laborStr = "₹\(String(format: "%.2f", finalLabor))"
        let laborSize = (laborStr as NSString).size(withAttributes: valAttrs)
        (laborStr as NSString).draw(at: CGPoint(x: x + width - laborSize.width - 16, y: currentY), withAttributes: valAttrs)
        
        currentY += 20
        
        // Additional Row
        ("Additional & Miscellaneous" as NSString).draw(at: CGPoint(x: x + 16, y: currentY), withAttributes: labelAttrs)
        let addStr = "₹\(String(format: "%.2f", finalAdditional))"
        let addSize = (addStr as NSString).size(withAttributes: valAttrs)
        (addStr as NSString).draw(at: CGPoint(x: x + width - addSize.width - 16, y: currentY), withAttributes: valAttrs)
        
        currentY += 20
        
        // Divider
        cgContext.saveGState()
        cgContext.setStrokeColor(borderGray.cgColor)
        cgContext.setLineWidth(0.8)
        cgContext.move(to: CGPoint(x: x + 16, y: currentY + 4))
        cgContext.addLine(to: CGPoint(x: x + width - 16, y: currentY + 4))
        cgContext.strokePath()
        cgContext.restoreGState()
        
        currentY += 12
        
        // Total Row
        let totalLabelAttrs: [NSAttributedString.Key: Any] = [.font: totalLabelFont, .foregroundColor: textPrimary]
        let totalValAttrs: [NSAttributedString.Key: Any] = [.font: totalValFont, .foregroundColor: primaryBlue]
        
        ("Total Approved Cost" as NSString).draw(at: CGPoint(x: x + 16, y: currentY), withAttributes: totalLabelAttrs)
        let totalStr = "₹\(String(format: "%.2f", actualCost))"
        let totalSize = (totalStr as NSString).size(withAttributes: totalValAttrs)
        (totalStr as NSString).draw(at: CGPoint(x: x + width - totalSize.width - 16, y: currentY), withAttributes: totalValAttrs)
        
        currentY += 24
        
        // Status indicator
        let statusDesc = order.workDescription.contains("[PENDING_APPROVAL]") ? "Awaiting Manager Approval" : "Authorized & Finalized"
        let statusDescFont = UIFont.systemFont(ofSize: 9, weight: .bold)
        let statusDescColor = order.workDescription.contains("[PENDING_APPROVAL]") ? darkOrange : UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0)
        let statusDescAttrs: [NSAttributedString.Key: Any] = [
            .font: statusDescFont,
            .foregroundColor: statusDescColor
        ]
        (statusDesc as NSString).draw(at: CGPoint(x: x + 16, y: currentY), withAttributes: statusDescAttrs)
        
        return y + height
    }
    
    private static func drawPageFooter(
        context: UIGraphicsPDFRendererContext,
        pageHeight: CGFloat,
        margin: CGFloat,
        dateFormatter: DateFormatter
    ) {
        let y = pageHeight - margin + 10
        let footerFont = UIFont.systemFont(ofSize: 8, weight: .regular)
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: textMuted
        ]
        let footerStr = "Fleet Management System  •  Confidential Maintenance Report  •  Generated: \(dateFormatter.string(from: Date()))"
        (footerStr as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: footerAttrs)
    }
    
    // MARK: - General Drawing Helpers
    
    private static func drawSectionHeader(_ text: String, context: UIGraphicsPDFRendererContext, y: CGFloat, x: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 11, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: primaryBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
        return y + 16
    }
    
    private static func drawSubDivider(context: UIGraphicsPDFRendererContext, y: CGFloat, x: CGFloat, width: CGFloat) -> CGFloat {
        let cgContext = context.cgContext
        cgContext.saveGState()
        cgContext.setStrokeColor(borderGray.cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.move(to: CGPoint(x: x, y: y))
        cgContext.addLine(to: CGPoint(x: x + width, y: y))
        cgContext.strokePath()
        cgContext.restoreGState()
        return y
    }
    
    private static func drawMultilineText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        context: UIGraphicsPDFRendererContext,
        y: CGFloat,
        x: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let string = NSAttributedString(string: text, attributes: attrs)
        let constraintSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let rect = string.boundingRect(with: constraintSize, options: .usesLineFragmentOrigin, context: nil)
        
        string.draw(in: CGRect(x: x, y: y, width: width, height: rect.height))
        return y + rect.height
    }
    
    private static func estimateTextHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let string = NSAttributedString(string: text, attributes: [.font: font])
        let constraintSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let rect = string.boundingRect(with: constraintSize, options: .usesLineFragmentOrigin, context: nil)
        return rect.height
    }
    
    private static func drawSFSymbol(_ name: String, color: UIColor, in rect: CGRect) {
        if let image = UIImage(systemName: name) {
            let tinted = image.withTintColor(color, renderingMode: .alwaysOriginal)
            let aspect = image.size.width / image.size.height
            var drawRect = rect
            if rect.width / rect.height > aspect {
                let newWidth = rect.height * aspect
                drawRect.origin.x += (rect.width - newWidth) / 2
                drawRect.size.width = newWidth
            } else {
                let newHeight = rect.width / aspect
                drawRect.origin.y += (rect.height - newHeight) / 2
                drawRect.size.height = newHeight
            }
            tinted.draw(in: drawRect)
        }
    }
    
    private static func currentStatusText(for order: WorkOrder) -> String {
        if order.workDescription.contains("[PENDING_APPROVAL]") {
            return "Awaiting Approval"
        } else if order.workDescription.contains("[REJECTED]") {
            return "Rejected"
        } else if order.workDescription.contains("[INFO_REQUESTED]") {
            return "Info Requested"
        }
        
        switch order.status {
        case .open: return "Assigned"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    private static func getStatusColor(for order: WorkOrder) -> UIColor {
        if order.workDescription.contains("[PENDING_APPROVAL]") {
            return darkOrange
        } else if order.workDescription.contains("[REJECTED]") {
            return UIColor.systemRed
        } else if order.workDescription.contains("[INFO_REQUESTED]") {
            return darkOrange
        }
        
        switch order.status {
        case .open: return primaryBlue
        case .inProgress: return primaryBlue
        case .completed: return UIColor.systemGreen
        case .cancelled: return UIColor.systemRed
        }
    }
}
