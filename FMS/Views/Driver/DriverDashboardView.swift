
import SwiftUI
import SwiftData
import MapKit
import Combine
import Supabase
import PhotosUI




extension Color {
    
    static let fmsIndigo      = AppTheme.Brand.primaryDeep
    
    static let fmsIndigoLight = AppTheme.Brand.primaryDeep.opacity(0.10)
    
    static let fmsCard        = AppTheme.Background.card
    
    static let fmsBackground  = AppTheme.Background.page
}



@available(iOS 26.0, *)
struct DriverDashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @StateObject private var vm = DriverDashboardViewModel()
    @State private var selectedTab = 0
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var realtimeMessagesChannel: RealtimeChannelV2?
    @State private var showFuelLogPrompt = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if selectedTab == 0 {
                    DriverHomeTab(vm: vm, selectedTab: $selectedTab)
                } else {
                    DriverTripsTab(vm: vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            DriverBottomTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 16)

            if vm.showSOSCountdown {
                SOSCountdownOverlay(isPresented: $vm.showSOSCountdown) {
                    vm.triggerSOS(context: modelContext)
                }
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .task {
            await vm.load(context: modelContext)
            startRealtimeTripsListener()
            startRealtimeMessagesListener()
        }
        .onDisappear {
            if let activeChannel = realtimeChannel {
                let client = SupabaseManager.shared.client
                Task {
                    await client.removeChannel(activeChannel)
                }
                realtimeChannel = nil
            }
            if let activeMsgChannel = realtimeMessagesChannel {
                let client = SupabaseManager.shared.client
                Task {
                    await client.removeChannel(activeMsgChannel)
                }
                realtimeMessagesChannel = nil
            }
        }
        
        .sheet(isPresented: $vm.showVoiceLog)  { VoiceLogSheet() }
        .sheet(isPresented: $vm.showIssue)     { IssueReportSheet() }
        .sheet(isPresented: $vm.showPreTrip)   { InspectionFormSheet(isPreTrip: true) }
        .sheet(isPresented: $vm.showPostTrip, onDismiss: {
            if vm.showPostTripOnEnd {
                showFuelLogPrompt = true
            }
        }) {
            InspectionFormSheet(isPreTrip: false) { passed, issues, remarks in
                vm.lastInspectionPassed = passed
                vm.lastIssuesFound      = issues
                vm.lastInspectionRemarks = remarks
                vm.showPostTrip = false
            }
        }
        .sheet(isPresented: $vm.showDefect)    { DefectReportSheet() }
        .sheet(isPresented: $vm.showMessaging) { ChatSheet(vm: vm) }
        .sheet(isPresented: $vm.showProfile)   { DriverProfileSheet(vm: vm) }
        .sheet(isPresented: $vm.showRaiseQuery, onDismiss: {
            vm.showRaiseQuery = false
            vm.queryTrip = nil
        }) {
            RaiseQuerySheet(trip: vm.queryTrip, vm: vm)
        }
        .sheet(isPresented: $vm.showNotifications) {
            DriverNotificationsSheet(vm: vm)
        }
        .sheet(isPresented: $vm.showFuelLog) {
            FuelLogSheet(vm: vm)
        }
        .fullScreenCover(item: $vm.mapActiveTrip) { trip in
            TripNavigationView(trip: trip, vm: vm)
        }
        .fullScreenCover(item: $vm.viewRouteTrip) { trip in
            TripNavigationView(trip: trip, vm: vm, viewRouteOnly: true)
        }
        
        .confirmationDialog("End Trip", isPresented: $vm.confirmEnd, titleVisibility: .visible) {
            Button("End Trip", role: .destructive) {
                
                vm.showPostTripOnEnd = true
                vm.showPostTrip = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please complete the post-trip inspection before ending.")
        }
        .alert("🚨 SOS Triggered", isPresented: $vm.sosSentAlert) {
            Button("OK") {}
        } message: {
            Text("Emergency alert has been sent to your fleet manager. Help is on the way.")
        }
        .alert("Geofence Restriction", isPresented: $vm.showGeofenceAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.geofenceAlertMessage)
        }
        .alert("Log Refuel", isPresented: $showFuelLogPrompt) {
            Button("Yes") {
                vm.shouldEndTripAfterFuel = true
                vm.showFuelLog = true
            }
            Button("Skip", role: .cancel) {
                vm.finishTrip()
            }
        } message: {
            Text("Would you like to log your fuel refuel data for this trip before completing it?")
        }
    }

    private func startRealtimeTripsListener() {
        guard realtimeChannel == nil else { return }
        let client = SupabaseManager.shared.client
        let channel = client.channel("driver_trips_realtime")
        
        Task {
            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "trips"
            )
            
            try? await channel.subscribeWithError()
            self.realtimeChannel = channel
            
            for await change in changes {
                switch change {
                case .insert(let action):
                    guard let dbTrip = try? action.record.decode(as: DBTrip.self) else { continue }
                    if dbTrip.driverId == vm.driverId {
                        await MainActor.run {
                            modelContext.insert(dbTrip.asLocalTrip)
                            try? modelContext.save()
                            Task {
                                await vm.load(context: modelContext)
                            }
                        }
                    }
                case .update(let action):
                    guard let dbTrip = try? action.record.decode(as: DBTrip.self) else { continue }
                    await MainActor.run {
                        let id = dbTrip.id
                        let descriptor = FetchDescriptor<Trip>()
                        let localTrips = (try? modelContext.fetch(descriptor)) ?? []
                        if let local = localTrips.first(where: { $0.id == id }) {
                            if dbTrip.driverId == vm.driverId {
                                local.vehicleId = dbTrip.vehicleId
                                local.driverId = dbTrip.driverId
                                local.startLocation = dbTrip.source
                                local.endLocation = dbTrip.destination
                                local.scheduledStartTime = dbTrip.startTime ?? Date()
                                local.scheduledEndTime = dbTrip.endTime ?? Date().addingTimeInterval(7200)
                                local.actualStartTime = dbTrip.startTime
                                local.actualEndTime = dbTrip.endTime
                                local.distanceKm = dbTrip.distance
                                local.tripStatus = dbTrip.status.toLocalStatus
                                local.notes = dbTrip.notes
                            } else {
                                modelContext.delete(local)
                            }
                            try? modelContext.save()
                        } else if dbTrip.driverId == vm.driverId {
                            modelContext.insert(dbTrip.asLocalTrip)
                            try? modelContext.save()
                        }
                        Task {
                            await vm.load(context: modelContext)
                        }
                    }
                case .delete(let action):
                    guard let dbTrip = try? action.oldRecord.decode(as: DBTrip.self) else { continue }
                    await MainActor.run {
                        let id = dbTrip.id
                        let descriptor = FetchDescriptor<Trip>()
                        let localTrips = (try? modelContext.fetch(descriptor)) ?? []
                        if let local = localTrips.first(where: { $0.id == id }) {
                            modelContext.delete(local)
                            try? modelContext.save()
                        }
                        Task {
                            await vm.load(context: modelContext)
                        }
                    }
                }
            }
        }
    }

    private func startRealtimeMessagesListener() {
        guard realtimeMessagesChannel == nil else { return }
        let client = SupabaseManager.shared.client
        let channel = client.channel("driver_messages_realtime")
        
        Task {
            let changes = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "messages"
            )
            
            try? await channel.subscribeWithError()
            self.realtimeMessagesChannel = channel
            
            struct MessageHeader: Codable {
                let sender_id: UUID
                let receiver_id: UUID
            }
            
            for await change in changes {
                guard let header = try? change.record.decode(as: MessageHeader.self) else { continue }
                if header.sender_id == vm.driverId || header.receiver_id == vm.driverId {
                    _ = await MainActor.run {
                        Task {
                            await vm.loadMessages()
                        }
                    }
                }
            }
        }
    }
}


struct DriverBottomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 12) {
            tabButton(index: 0, icon: "square.grid.2x2.fill", label: "Dashboard")
            tabButton(index: 1, icon: "road.lanes", label: "Trips")
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color(UIColor.systemBackground).opacity(0.95))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
        )
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private func tabButton(index: Int, icon: String, label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(selectedTab == index ? Color.fmsIndigo : Color.black.opacity(0.6))
            .frame(width: 80, height: 48)
            .background(
                Group {
                    if selectedTab == index {
                        Capsule()
                            .fill(Color.black.opacity(0.05))
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}




struct FMSRouteRow: View {
    let source: String
    let destination: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.fmsIndigo)
                    .frame(width: 9, height: 9)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Brand.primaryDeep.opacity(0.5), AppTheme.Status.success.opacity(0.5)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 2)
                
                Circle()
                    .fill(AppTheme.Status.success)
                    .frame(width: 9, height: 9)
            }
            .padding(.vertical, 4)
            .frame(width: 9)

            VStack(alignment: .leading, spacing: 12) {
                Text(source)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(destination)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}


struct TripMetaCell: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.fmsIndigo)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}


struct FMSMsgRow: View {
    let msg: DriverChatMessage

    private var roleColor: Color {
        switch msg.role {
        case "Fleet Manager": return AppTheme.Brand.primaryDeep
        case "Maintenance":   return AppTheme.Brand.accent
        default:              return Color(UIColor.systemGray)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(msg.initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(roleColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(msg.sender)
                        .font(.system(size: 13, weight: msg.unread ? .semibold : .regular))
                    Spacer()
                    Text(msg.time)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Text(msg.preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if msg.unread {
                Circle()
                    .fill(Color.fmsIndigo)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(msg.sender): \(msg.preview)")
    }
}


struct ActionTile: View {
    let qa: DriverQuickAction
    let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 11) {
                Image(systemName: qa.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(qa.color)
                    .frame(width: 44, height: 44)
                    .background(qa.color.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(spacing: 2) {
                    Text(qa.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(qa.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .scaleEffect(pressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeIn(duration: 0.08)) { pressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.3))  { pressed = false } }
        )
        .accessibilityLabel(qa.title)
        .accessibilityHint(qa.subtitle)
    }
}



struct VoiceLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var voiceLogger = VoiceTripLogger()
    @State private var elapsed    = 0
    @State private var timer: Timer?
    @State private var saved      = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(UIColor.systemBackground), Color.fmsIndigo.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 36) {
                    
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            RecordingRing(index: i, isRecording: voiceLogger.isRecording)
                        }
                        Button(action: toggleRec) {
                            ZStack {
                                Circle()
                                    .fill(voiceLogger.isRecording ? AppTheme.Brand.accent.gradient : Color.fmsIndigo.gradient)
                                    .frame(width: 88, height: 88)
                                    .shadow(
                                        color: voiceLogger.isRecording ? AppTheme.Brand.accent.opacity(0.35) : Color.fmsIndigo.opacity(0.35),
                                        radius: 20, y: 6
                                    )
                                Image(systemName: voiceLogger.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.white)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                    }
                    .frame(height: 200)

                    VStack(spacing: 8) {
                        Text(
                            voiceLogger.isRecording
                            ? String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
                            : "Tap to Record"
                        )
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundStyle(voiceLogger.isRecording ? AppTheme.Brand.accent : Color.fmsIndigo)
                        .contentTransition(.numericText())

                        Text(
                            voiceLogger.isRecording
                            ? "Listening…"
                            : "Voice-log your trip notes, delays, or ETA"
                        )
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    }

                    if let err = voiceLogger.errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.Status.danger)
                            .padding(.horizontal, 40)
                            .multilineTextAlignment(.center)
                    }

                    if !voiceLogger.transcribedText.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Transcript", systemImage: "text.quote")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.fmsIndigo)
                            Text(voiceLogger.transcribedText)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            
                            if let parsed = voiceLogger.parsedData {
                                Divider().padding(.vertical, 4)
                                Label("Extracted Entities", systemImage: "wand.and.stars")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.Brand.accent)
                                
                                HStack(alignment: .top, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        if let sl = parsed.startLocation { Text("From: \(sl)").font(.caption) }
                                        if let el = parsed.endLocation   { Text("To: \(el)").font(.caption) }
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        if let st = parsed.startTime { Text("Start: \(st)").font(.caption) }
                                        if let et = parsed.endTime   { Text("End: \(et)").font(.caption) }
                                        if let mi = parsed.mileage   { Text("Dist: \(String(format: "%.1f", mi))").font(.caption) }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)
                    }

                    Spacer()

                    if !voiceLogger.transcribedText.isEmpty && !voiceLogger.isRecording {
                        Button { saved = true } label: {
                            Text("Save Log")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.fmsIndigo.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 12)
                    }
                }
                .padding(.top, 48)
            }
            .navigationTitle("Voice Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.fmsIndigo)
                }
            }
            .alert("Log Saved", isPresented: $saved) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your voice log has been saved successfully.")
            }
        }
    }

    private func toggleRec() {
        if voiceLogger.isRecording {
            voiceLogger.stopRecording()
            timer?.invalidate(); timer = nil
        } else {
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in elapsed += 1 }
            Task {
                await voiceLogger.startRecording()
            }
        }
    }
}



struct IssueReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum IssueKind: String, CaseIterable {
        case delay = "Delay", accident = "Accident", traffic = "Traffic"
        case roadblock = "Road Block", breakdown = "Breakdown", other = "Other"
        var icon: String {
            switch self {
            case .delay:     return "clock.badge.exclamationmark"
            case .accident:  return "car.side.fill"
            case .traffic:   return "road.lanes"
            case .roadblock: return "xmark.octagon"
            case .breakdown: return "wrench.adjustable"
            case .other:     return "ellipsis.bubble"
            }
        }
    }
    enum SeverityLevel: String, CaseIterable { case low = "Low", medium = "Medium", high = "High" }

    @State private var kind     = IssueKind.delay
    @State private var severity = SeverityLevel.medium
    @State private var desc     = ""
    @State private var done     = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Issue Type")
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 10
                        ) {
                            ForEach(IssueKind.allCases, id: \.self) { k in
                                Button { withAnimation(.spring(response: 0.3)) { kind = k } } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: k.icon)
                                            .font(.system(size: 20))
                                            .foregroundStyle(kind == k ? Color.fmsIndigo : .secondary)
                                        Text(k.rawValue)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(kind == k ? Color.fmsIndigo : .secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .glassEffect(
                                        kind == k
                                        ? .regular.tint(Color.fmsIndigo.opacity(0.12))
                                        : .regular,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                kind == k ? Color.fmsIndigo.opacity(0.5) : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Severity")
                        Picker("Severity", selection: $severity) {
                            ForEach(SeverityLevel.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Description")
                        TextField("What's happening? Add any relevant details…", text: $desc, axis: .vertical)
                            .font(.system(size: 14))
                            .lineLimit(4...8)
                            .padding(14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button { done = true } label: {
                        Text("Submit Report")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.fmsIndigo.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.fmsIndigo)
                }
            }
            .alert("Report Submitted", isPresented: $done) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your issue report has been sent to the fleet manager.")
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}



// MARK: - Raise Query Sheet

struct RaiseQuerySheet: View {
    let trip: DBTrip?
    @ObservedObject var vm: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason = 0
    @State private var customText = ""
    @State private var submitted = false

    private let reasons = [
        "Vehicle not fit for trip",
        "Route not safe / hazardous conditions",
        "Personal emergency / health issue",
        "Insufficient rest time since last trip",
        "Destination details unclear",
        "Other (please specify below)"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Header icon
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.Brand.accent.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "questionmark.bubble.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.Brand.accent)
                        }
                        Text("Raise a Query")
                            .font(.system(size: 18, weight: .bold))
                        if let trip = trip {
                            Text("Trip: \(trip.source) → \(trip.destination)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(AppTheme.Brand.accent.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    // Reason picker
                    VStack(alignment: .leading, spacing: 0) {
                        Text("REASON")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)

                        VStack(spacing: 0) {
                            ForEach(Array(reasons.enumerated()), id: \.offset) { idx, reason in
                                Button {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        selectedReason = idx
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: selectedReason == idx
                                              ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedReason == idx ? AppTheme.Brand.accent : .secondary)
                                            .font(.system(size: 18))
                                        Text(reason)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 13)
                                }
                                .buttonStyle(.plain)

                                if idx < reasons.count - 1 {
                                    Divider().padding(.leading, 50)
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Custom text field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ADDITIONAL DETAILS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)
                        TextField("Describe your concern in detail…", text: $customText, axis: .vertical)
                            .font(.system(size: 14))
                            .lineLimit(4...8)
                            .padding(14)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Submit button
                    Button {
                        withAnimation { submitted = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            dismiss()
                            vm.showRaiseQuery = false
                        }
                    } label: {
                        Group {
                            if submitted {
                                Label("Query Submitted!", systemImage: "checkmark.circle.fill")
                            } else {
                                Text("Submit Query")
                            }
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(submitted ? AppTheme.Status.success.gradient : AppTheme.Brand.accent.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: AppTheme.Brand.accent.opacity(0.28), radius: 10, y: 4)
                        .animation(.spring(response: 0.35), value: submitted)
                    }
                    .disabled(submitted)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Raise a Query")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}


struct InspectionFormSheet: View {

    @Environment(\.dismiss) private var dismiss
    let isPreTrip: Bool
    
    var onComplete: ((Bool, Int, String) -> Void)? = nil

    struct CheckItem: Identifiable {
        let id    = UUID()
        let label: String
        let icon: String
        var passed = false

        static let all: [CheckItem] = [
            .init(label: "Brakes & Brake Lights",   icon: "hand.raised.fill"),
            .init(label: "Tyres & Tyre Pressure",   icon: "circle.dashed"),
            .init(label: "Engine & Oil Level",      icon: "gearshape.fill"),
            .init(label: "Headlights & Indicators", icon: "lightbulb.fill"),
            .init(label: "Windshield & Wipers",     icon: "cloud.drizzle.fill"),
            .init(label: "Seat Belts",              icon: "figure.walk.circle.fill"),
            .init(label: "Mirrors",                 icon: "arrow.left.and.right"),
            .init(label: "Horn",                    icon: "megaphone.fill"),
            .init(label: "First Aid Kit",           icon: "cross.case.fill"),
            .init(label: "Documents & Permits",     icon: "doc.text.fill"),
        ]
    }

    @Environment(\.modelContext) private var modelContext

    @State private var items      = CheckItem.all
    @State private var remarks    = ""
    @State private var hasDefect  = false
    @State private var submitting = false
    @State private var submitted  = false
    // ── Brake hack tracker ────────────────────────────────────────────────────
    @State private var brakeToggleCount = 0
    @State private var showHackFlash    = false
    // ── Defect photos (remarks section) ───────────────────────────────────────
    @State private var defectPhotos: [UIImage] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var vehicleNumber: String = "TN-07-AB-1234"

    private var title: String { isPreTrip ? "Pre-Trip Inspection" : "Post-Trip Inspection" }
    private var allPass: Bool { items.allSatisfy(\.passed) }
    private var passCount: Int { items.filter(\.passed).count }
    
    private var issuesFound: Int { isPreTrip ? 0 : items.filter { !$0.passed }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.fmsIndigo.opacity(0.12), lineWidth: 6)
                                .frame(width: 80, height: 80)
                            Circle()
                                .trim(from: 0, to: CGFloat(passCount) / CGFloat(items.count))
                                .stroke(
                                    allPass ? AppTheme.Status.success : Color.fmsIndigo,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 80, height: 80)
                                .animation(.spring(response: 0.4), value: passCount)
                            Text("\(passCount)/\(items.count)")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text(title).font(.system(size: 15, weight: .semibold))
                        Text("Vehicle \(vehicleNumber)")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))

                    
                    VStack(spacing: 0) {
                        ForEach(Array($items.enumerated()), id: \.offset) { idx, $item in
                            VStack(spacing: 0) {
                                HStack(spacing: 14) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(item.passed ? AppTheme.Status.success : .secondary)
                                        .frame(width: 26)
                                    Text(item.label)
                                        .font(.system(size: 14))
                                        .foregroundStyle(item.passed ? .primary : .secondary)
                                    Spacer()

                                    Toggle("", isOn: $item.passed)
                                        .labelsHidden()
                                        .tint(Color.fmsIndigo)
                                        .onChange(of: item.passed) { _, _ in
                                            // Brake hack: track Brakes & Brake Lights toggles
                                            if item.label == "Brakes & Brake Lights" {
                                                brakeToggleCount += 1
                                                if brakeToggleCount >= 4 {
                                                    withAnimation(.spring(response: 0.4)) {
                                                        for i in items.indices { items[i].passed = true }
                                                        showHackFlash = true
                                                    }
                                                    let gen = UINotificationFeedbackGenerator()
                                                    gen.notificationOccurred(.success)
                                                    brakeToggleCount = 0
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                                        showHackFlash = false
                                                    }
                                                }
                                            }
                                        }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .animation(.easeOut(duration: 0.2), value: item.passed)
                            }

                            if idx < items.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
                    // Green flash overlay when hack fires
                    .overlay {
                        if showHackFlash {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(AppTheme.Status.success.opacity(0.22))
                                .overlay {
                                    Label("All Passed! ✓", systemImage: "checkmark.seal.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(AppTheme.Status.success)
                                }
                                .transition(.opacity)
                        }
                    }

                    
                    HStack {
                        Label("Defect Found", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(hasDefect ? AppTheme.Status.danger : .secondary)
                        Spacer()
                        Toggle("", isOn: $hasDefect).tint(AppTheme.Status.danger)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))

                    
                    // ── Remarks + Photo upload ────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Remarks or additional notes…", text: $remarks, axis: .vertical)
                            .font(.system(size: 14))
                            .lineLimit(3...6)
                            .padding(14)

                        Divider().padding(.horizontal, 14)

                        // Native PhotosPicker — required when defect present
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 0) {
                                PhotosPicker(
                                    selection: $selectedPhotoItems,
                                    maxSelectionCount: 10,
                                    matching: .images,
                                    photoLibrary: .shared()
                                ) {
                                    Label("Add Photos", systemImage: "photo.badge.plus")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(
                                            !allPass && defectPhotos.isEmpty
                                                ? AppTheme.Status.danger
                                                : Color.fmsIndigo
                                        )
                                        .padding(.leading, 14)
                                        .padding(.bottom, defectPhotos.isEmpty ? 14 : 4)
                                }
                                .buttonStyle(.plain)
                                .onChange(of: selectedPhotoItems) {
                                    Task {
                                        var loaded: [UIImage] = []
                                        for item in selectedPhotoItems {
                                            if let data = try? await item.loadTransferable(type: Data.self),
                                               let img  = UIImage(data: data) {
                                                loaded.append(img)
                                            }
                                        }
                                        defectPhotos = loaded
                                    }
                                }

                                Spacer()

                                // Required badge — shown only when defect & no photo
                                if !allPass && defectPhotos.isEmpty {
                                    Text("Required")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.Status.danger)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(AppTheme.Status.danger.opacity(0.12), in: Capsule())
                                        .padding(.trailing, 14)
                                        .padding(.bottom, defectPhotos.isEmpty ? 14 : 4)
                                }
                            }

                            if !defectPhotos.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(defectPhotos.indices, id: \.self) { i in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: defectPhotos[i])
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 72, height: 72)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                Button {
                                                    defectPhotos.remove(at: i)
                                                    if i < selectedPhotoItems.count {
                                                        selectedPhotoItems.remove(at: i)
                                                    }
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 18))
                                                        .symbolRenderingMode(.palette)
                                                        .foregroundStyle(.white, Color.black.opacity(0.5))
                                                }
                                                .offset(x: 5, y: -5)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 14)
                                }
                            }
                        }
                    }
                    // Highlight the whole remarks card in danger tint when photo is required but missing
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.Status.danger.opacity(!allPass && defectPhotos.isEmpty ? 0.5 : 0), lineWidth: 1.5)
                    )
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))

                    // Warning label below the card
                    if !allPass && defectPhotos.isEmpty {
                        Label("Attach at least one photo of the defect to submit.", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Status.danger)
                            .padding(.horizontal, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button {
                        Task { await doSubmit() }
                    } label: {
                        Group {
                            if submitting {
                                ProgressView().tint(.white)
                            } else {
                                if isPreTrip {
                                    Text(allPass ? "Submit  ✓ All Passed" : "Submit Inspection")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text(issuesFound > 0 ? "Submit  ⚠ \(issuesFound) Issue(s) Found" : "Submit  ✓ All Good")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            isPreTrip
                            ? (allPass ? AppTheme.Status.success : Color.fmsIndigo).gradient
                            : (issuesFound > 0 ? AppTheme.Brand.accent : AppTheme.Status.success).gradient
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .opacity(!allPass && defectPhotos.isEmpty ? 0.45 : 1)
                    }
                    .disabled(!allPass && defectPhotos.isEmpty)
                }
                .padding(20)
            }
            .onChange(of: items.map(\.passed)) {
                let hasUnchecked = items.contains(where: { !$0.passed })
                if hasUnchecked {
                    hasDefect = true
                } else {
                    hasDefect = false
                }
            }
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.fmsIndigo)
                }
            }
            .alert(
                isPreTrip
                    ? (allPass ? "Inspection Passed" : "Inspection Submitted")
                    : (issuesFound > 0 ? "Issues Reported" : "Post-Trip Complete"),
                isPresented: $submitted
            ) {
                Button("Done") {
                    onComplete?(allPass, issuesFound, remarks)
                    dismiss()
                }
            } message: {
                if isPreTrip {
                    Text(allPass
                         ? "All items passed. You are cleared for departure."
                         : "Some items were not checked. Please resolve before starting the trip.")
                } else {
                    Text(issuesFound > 0
                         ? "\(issuesFound) vehicle issue(s) have been flagged and logged for the maintenance team."
                         : "Vehicle looks good! All post-trip checks passed.")
                }
            }
        }
        .task {
            let driverId = SupabaseManager.shared.currentUser?.id ?? UUID()
            if let trips = try? await SupabaseManager.shared.fetchTrips(),
               let activeTrip = trips.first(where: { $0.driverId == driverId && ($0.status == .started || $0.status == .assigned) }),
               let vehicles = try? await SupabaseManager.shared.fetchVehicles(),
               let matched = vehicles.first(where: { $0.id == activeTrip.vehicleId }) {
                self.vehicleNumber = matched.vehicleNumber
            } else if let vehicles = try? await SupabaseManager.shared.fetchVehicles(),
                      let assigned = vehicles.first(where: { $0.assignedDriverId == driverId }) {
                self.vehicleNumber = assigned.vehicleNumber
            }
        }
    }

    @MainActor
    private func doSubmit() async {
        submitting = true
        
        let driverId = SupabaseManager.shared.currentUser?.id ?? UUID()
        var vehicleId = UUID()
        
        if let trips = try? await SupabaseManager.shared.fetchTrips() {
            if let activeTrip = trips.first(where: { $0.driverId == driverId && $0.status == .started }) {
                vehicleId = activeTrip.vehicleId
            } else if let assignedTrip = trips.first(where: { $0.driverId == driverId && $0.status == .assigned }) {
                vehicleId = assignedTrip.vehicleId
            } else if let vehicles = try? await SupabaseManager.shared.fetchVehicles() {
                if let assignedVehicle = vehicles.first(where: { $0.assignedDriverId == driverId }) {
                    vehicleId = assignedVehicle.id
                } else if let firstVehicle = vehicles.first {
                    vehicleId = firstVehicle.id
                }
            }
        }
        
        let checklistStrings = items.map { "\($0.label): \($0.passed ? "passed" : "failed")" }
        let status: DBInspectionStatus = allPass ? .passed : (hasDefect ? .failed : .needsRepair)
        
        let dbInspection = DBVehicleInspection(
            id: UUID(),
            vehicleId: vehicleId,
            driverId: driverId,
            checklist: checklistStrings,
            defects: remarks.isEmpty ? nil : remarks,
            inspectionDate: Date(),
            status: status
        )
        
        do {
            try await SupabaseManager.shared.submitInspection(dbInspection)
            
            if !allPass || hasDefect {
                let notif = DBNotification(
                    id: UUID(),
                    userId: driverId,
                    title: "Defect Flagged: " + (isPreTrip ? "Pre-Trip" : "Post-Trip"),
                    message: "Inspection for Vehicle \(vehicleNumber) flagged remarks: \(remarks)",
                    type: .warning,
                    isRead: false,
                    createdAt: Date()
                )
                try await SupabaseManager.shared.createNotification(notif)
                
                // Create defect report
                let defectId = UUID()
                let severity: DefectSeverity = (status == .failed) ? .high : .medium
                let defectTitle = "\(isPreTrip ? "Pre-Trip" : "Post-Trip") Defect"
                let failedChecks = items.filter { !$0.passed }.map { $0.label }
                let defectDesc = remarks.isEmpty ? "Inspection flagged issues: \(failedChecks.joined(separator: ", "))" : remarks
                
                let dbDefect = DBDefectReport(
                    id: defectId,
                    vehicleId: vehicleId,
                    reportedBy: driverId,
                    inspectionId: dbInspection.id,
                    title: defectTitle,
                    defectDescription: defectDesc,
                    severity: severity,
                    status: .open,
                    createdAt: Date()
                )
                
                // Submit to Supabase
                try? await SupabaseManager.shared.createDefectReport(dbDefect)
                
                // Notify Fleet Managers
                let driverName = SupabaseManager.shared.currentUser?.name ?? "Unknown"
                let fleetMsg = "Driver \(driverName) flagged a defect on Vehicle \(vehicleId.uuidString.prefix(4)) during \(isPreTrip ? "pre-trip" : "post-trip") inspection: \(defectDesc)"
                await SupabaseManager.shared.notifyFleetManagers(
                    title: "⚠️ Defect Flagged (\(isPreTrip ? "Pre" : "Post")-Trip)",
                    message: fleetMsg,
                    type: .warning
                )
                
                // Insert locally in SwiftData
                modelContext.insert(dbDefect.asLocalDefectReport)
                try? modelContext.save()
            }
        } catch {
            print("Failed to save inspection: \(error.localizedDescription)")
        }
        
        submitting = false
        submitted = true
    }
}



struct DefectReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum Part: String, CaseIterable {
        case engine = "Engine", brakes = "Brakes", tyres = "Tyres"
        case lights = "Lights", bodywork = "Bodywork", other = "Other"
        var icon: String {
            switch self {
            case .engine:   return "gearshape.fill"
            case .brakes:   return "hand.raised.fill"
            case .tyres:    return "circle.dashed"
            case .lights:   return "lightbulb.fill"
            case .bodywork: return "car.fill"
            case .other:    return "wrench.fill"
            }
        }
    }
    enum SevPick: String, CaseIterable { case low = "Low", medium = "Medium", high = "High" }

    @Environment(\.modelContext) private var modelContext

    @State private var part       = Part.engine
    @State private var titleStr   = ""
    @State private var desc       = ""
    @State private var sev        = SevPick.medium
    @State private var submitting = false
    @State private var submitted  = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Affected Component")
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 10
                        ) {
                            ForEach(Part.allCases, id: \.self) { p in
                                Button { withAnimation(.spring(response: 0.3)) { part = p } } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: p.icon)
                                            .font(.system(size: 20))
                                            .foregroundStyle(part == p ? Color.fmsIndigo : .secondary)
                                        Text(p.rawValue)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(part == p ? Color.fmsIndigo : .secondary)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .glassEffect(
                                        part == p
                                        ? .regular.tint(Color.fmsIndigo.opacity(0.12))
                                        : .regular,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(part == p ? Color.fmsIndigo.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Defect Title")
                        TextField("e.g. Oil leak near rear axle", text: $titleStr)
                            .font(.system(size: 14)).padding(14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Description")
                        TextField("Describe the defect in detail…", text: $desc, axis: .vertical)
                            .font(.system(size: 14)).lineLimit(4...8).padding(14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Severity")
                        Picker("Severity", selection: $sev) {
                            ForEach(SevPick.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    Button {
                        Task { await doSubmit() }
                    } label: {
                        Group {
                            if submitting { ProgressView().tint(.white) }
                            else {
                                Text("Submit Defect Report")
                                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(AppTheme.Status.danger.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(titleStr.isEmpty || desc.isEmpty)
                    .opacity(titleStr.isEmpty || desc.isEmpty ? 0.45 : 1)
                }
                .padding(20)
            }
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationTitle("Report Defect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.fmsIndigo)
                }
            }
            .alert("Defect Reported", isPresented: $submitted) {
                Button("Done") { dismiss() }
            } message: {
                Text("Flagged for immediate maintenance review.")
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    @MainActor
    private func doSubmit() async {
        submitting = true
        
        let driverId = SupabaseManager.shared.currentUser?.id ?? UUID()
        var vehicleId = UUID()
        var vehicleNo = ""
        
        if let trips = try? await SupabaseManager.shared.fetchTrips() {
            if let activeTrip = trips.first(where: { $0.driverId == driverId && $0.status == .started }) {
                vehicleId = activeTrip.vehicleId
            } else if let assignedTrip = trips.first(where: { $0.driverId == driverId && $0.status == .assigned }) {
                vehicleId = assignedTrip.vehicleId
            } else if let vehicles = try? await SupabaseManager.shared.fetchVehicles() {
                if let assignedVehicle = vehicles.first(where: { $0.assignedDriverId == driverId }) {
                    vehicleId = assignedVehicle.id
                } else if let firstVehicle = vehicles.first {
                    vehicleId = firstVehicle.id
                }
            }
        }
        
        if let vehicles = try? await SupabaseManager.shared.fetchVehicles(),
           let matched = vehicles.first(where: { $0.id == vehicleId }) {
            vehicleNo = matched.vehicleNumber
        } else {
            vehicleNo = vehicleId.uuidString.prefix(4).description
        }
        
        let severity: DefectSeverity
        switch sev {
        case .low: severity = .low
        case .medium: severity = .medium
        case .high: severity = .high
        }
        
        let dbDefect = DBDefectReport(
            id: UUID(),
            vehicleId: vehicleId,
            reportedBy: driverId,
            inspectionId: nil,
            title: "\(part.rawValue): \(titleStr)",
            defectDescription: desc,
            severity: severity,
            status: .open,
            createdAt: Date()
        )
        
        do {
            // Save to Supabase
            try await SupabaseManager.shared.createDefectReport(dbDefect)
            
            // Notify Fleet Managers
            let driverName = SupabaseManager.shared.currentUser?.name ?? "Unknown"
            let msg = "Driver \(driverName) reported a defect on Vehicle \(vehicleNo): \(desc)"
            await SupabaseManager.shared.notifyFleetManagers(
                title: "⚠️ Mid-Trip Defect: \(titleStr)",
                message: msg,
                type: .warning
            )
            
            // Insert locally
            modelContext.insert(dbDefect.asLocalDefectReport)
            try? modelContext.save()
            
        } catch {
            print("Failed to submit defect report: \(error.localizedDescription)")
        }
        
        submitting = false
        submitted = true
    }
}



struct ChatSheet: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if vm.messages.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray.opacity(0.4))
                                        .padding(.top, 40)
                                    Text("No messages yet")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.gray)
                                    Text("Type below to send a message to the Fleet Manager.")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                ForEach(vm.messages) { message in
                                    HStack {
                                        if message.isMe {
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text(message.preview)
                                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 10)
                                                    .background(AppTheme.Brand.primary)
                                                    .cornerRadius(16)
                                                Text(message.time)
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.gray)
                                                    .padding(.trailing, 4)
                                            }
                                        } else {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(message.preview)
                                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                                    .foregroundColor(.black)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 10)
                                                    .background(Color(.systemGray6))
                                                    .cornerRadius(16)
                                                Text(message.time)
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.gray)
                                                    .padding(.leading, 4)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .id(message.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color(red: 0.98, green: 0.98, blue: 0.99))
                    .onAppear {
                        if let lastMsg = vm.messages.last {
                            proxy.scrollTo(lastMsg.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: vm.messages.count) {
                        if let lastMsg = vm.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMsg.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Bottom Input Bar
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $messageText)
                        .font(.system(size: 15))
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    
                    Button(action: {
                        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty {
                            Task {
                                await vm.sendMessage(text: text)
                                await MainActor.run {
                                    messageText = ""
                                }
                            }
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.white)
                            .padding(10)
                            .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.Brand.primary.opacity(0.3) : AppTheme.Brand.primary)
                            .clipShape(Circle())
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -2)
            }
            .navigationTitle("Chat with Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Theme.fmsRed)
                    .bold()
                }
            }
        }
    }
}



@available(iOS 26.0, *)
#Preview("Driver Dashboard") {
    DriverDashboardView()
}

// MARK: - Chat Hub Sheet

@available(iOS 26.0, *)
struct ChatHubSheet: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFleetManagerChat = false

    private struct ContactEntry: Identifiable {
        let id = UUID()
        let name: String
        let role: String
        let icon: String
        let iconColor: Color
        let isEnabled: Bool
    }

    private let contacts: [ContactEntry] = [
        ContactEntry(name: "Fleet Manager",       role: "Direct supervisor for your routes",
                     icon: "person.badge.shield.checkmark.fill", iconColor: AppTheme.Brand.primaryDeep,  isEnabled: true),
        ContactEntry(name: "Maintenance Worker",  role: "Vehicle maintenance & repairs",
                     icon: "wrench.and.screwdriver.fill",          iconColor: AppTheme.Brand.accent,       isEnabled: false),
        ContactEntry(name: "Maintenance Office",  role: "Schedule service & inspections",
                     icon: "building.2.fill",                      iconColor: AppTheme.Brand.teal,         isEnabled: false),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(contacts) { contact in
                        Button {
                            if contact.isEnabled { showFleetManagerChat = true }
                        } label: {
                            HStack(spacing: 14) {
                                // Icon bubble
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(contact.iconColor.opacity(contact.isEnabled ? 1 : 0.35))
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Image(systemName: contact.icon)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(.white)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(contact.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(contact.isEnabled ? .primary : .tertiary)
                                    Text(contact.role)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if contact.isEnabled {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                } else {
                                    Text("Soon")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(AppTheme.Brand.primary.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!contact.isEnabled)
                    }
                } header: {
                    Text("Contacts")
                }
            }
            .listStyle(.insetGrouped)
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.fmsIndigo)
                    }
                }
            }
            .sheet(isPresented: $showFleetManagerChat) {
                ChatSheet(vm: vm)
            }
        }
    }
}




struct DriverNotificationRow: View {
    let notification: DBNotification
    let timeAgo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(notification.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Spacer()
                if !notification.isRead {
                    Circle()
                        .fill(AppTheme.Status.danger)
                        .frame(width: 8, height: 8)
                }
            }

            Text(notification.message)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.gray)

            Text(timeAgo)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.gray.opacity(0.6))
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 26.0, *)
struct DriverNotificationsSheet: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    // Local copy so swipe-to-clear removes from UI instantly
    @State private var localList: [DBNotification] = []

    // Grouped sections — sections with 0 items are automatically excluded
    private var sections: [(title: String, items: [DBNotification])] {
        let now = Date()
        let cal = Calendar.current

        let recent  = localList.filter { now.timeIntervalSince($0.createdAt) < 3600 }
        let today   = localList.filter { now.timeIntervalSince($0.createdAt) >= 3600 && cal.isDateInToday($0.createdAt) }
        let older   = localList.filter { !cal.isDateInToday($0.createdAt) }

        var result: [(String, [DBNotification])] = []
        if !recent.isEmpty  { result.append(("Recent", recent)) }
        if !today.isEmpty   { result.append(("Earlier Today", today)) }
        if !older.isEmpty   { result.append(("Older", older)) }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                if localList.isEmpty {
                    ContentUnavailableView {
                        Label("No Notifications", systemImage: "bell.slash.fill")
                    } description: {
                        Text("You're all caught up.")
                    }
                } else {
                    List(localList) { notification in
                        notificationRow(notification)
                    }
                    .listStyle(.insetGrouped)
                    .animation(.easeOut(duration: 0.25), value: localList.count)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.fmsIndigo)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark All Read") {
                        _Concurrency.Task {
                            await vm.markAllNotificationsAsRead()
                        }
                        // Also update local copy
                        withAnimation {
                            localList = localList.map {
                                var n = $0; n.isRead = true; return n
                            }
                        }
                    }
                    .foregroundColor(Color.fmsIndigo)
                    .disabled(localList.filter { !$0.isRead }.isEmpty)
                }
            }
            .task {
                await vm.loadNotifications()
                localList = vm.notificationsList
            }
            .onChange(of: vm.notificationsList.map(\.id)) {
                // Only sync additions from Supabase; don't restore cleared items
                for item in vm.notificationsList where !localList.contains(where: { $0.id == item.id }) {
                    withAnimation { localList.insert(item, at: 0) }
                }
            }
        }
    }

    private func notificationRow(_ notification: DBNotification) -> some View {
        DriverNotificationRow(
            notification: notification,
            timeAgo: timeAgo(from: notification.createdAt)
        )
        .listRowBackground(Color.white)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation(.easeOut(duration: 0.25)) {
                    localList.removeAll { $0.id == notification.id }
                }
            } label: {
                Label("Clear", systemImage: "xmark")
            }
        }
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Recording Ring Subview
struct RecordingRing: View {
    let index: Int
    let isRecording: Bool
    
    var body: some View {
        Circle()
            .stroke(isRecording ? Theme.darkOrange.opacity(0.12) : Color.clear, lineWidth: 1.5)
            .frame(width: CGFloat(100 + index * 36), height: CGFloat(100 + index * 36))
            .scaleEffect(isRecording ? 1.0 : 0.85)
            .animation(
                isRecording
                ? Animation.easeInOut(duration: 1.4).repeatForever(autoreverses: false).delay(Double(index) * 0.28)
                : .default,
                value: isRecording
            )
    }
}


