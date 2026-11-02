import SwiftUI
import FirebaseAuth

extension Color {
    /// Background for the signed-in screens: a soft sky blue.
    static let dashboardBackground = Color(red: 0.76, green: 0.87, blue: 1.0)

    /// Deeper blue used for the calendar days that have GPS data.
    static let calendarDayBlue = Color(red: 0.10, green: 0.31, blue: 0.68)
}

struct DashboardView: View {
    let authManager: AuthManager
    @State private var dataManager = FirestoreDataManager()
    @State private var isMapPresented = false
    @State private var selectedSessionID: String?
    @State private var isSessionSelectorExpanded = false
    @State private var sessionSelectorWidth: CGFloat = 0

    private var routeSessions: [GPSSession] {
        dataManager.gpsSessions
    }

    private var selectedMapSession: GPSSession? {
        routeSessions.first { $0.id == selectedSessionID } ?? routeSessions.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if dataManager.isLoading {
                    ProgressView("Loading your data…")
                } else if let errorMessage = dataManager.errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                        Button("Retry") {
                            Task { await dataManager.fetchData() }
                        }
                    }
                } else if dataManager.uniqueDays.isEmpty {
                    // Make an empty result obvious instead of showing a blank screen.
                    VStack(spacing: 12) {
                        Text("No documents found in unique_days")
                            .font(.custom("Josefin Sans", size: 20))
                        Text("Signed in as UID:\n\(authManager.user?.uid ?? "unknown")")
                            .font(.custom("Josefin Sans", size: 13))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                        Button("Reload") {
                            Task { await dataManager.fetchData() }
                        }
                    }
                    .padding()
                } else {
                    calendarContent
                }
            }
            // Fill the whole screen (including under the bars) with the light blue background.
            // Set here because a NavigationStack paints its own opaque background on iPad.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dashboardBackground.ignoresSafeArea())
#if !os(macOS)
            // Also color the navigation container itself, which is what shows white on iPad.
            // (The `.navigation` placement doesn't exist on macOS, where it isn't needed.)
            .containerBackground(Color.dashboardBackground, for: .navigation)
#endif
            // Black text for readability on the light background
            .foregroundStyle(Color.calendarDayBlue)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("GPS Tracker")
                        .font(.custom("Josefin Sans", size: 27))
                }
            }
            .profileToolbar(authManager: authManager)
        }
#if os(macOS)
        .sheet(isPresented: $isMapPresented) {
            routeMapPresentation
                .frame(width: 1000, height: 800)
        }
#else
        .fullScreenCover(isPresented: $isMapPresented) {
            routeMapPresentation
        }
#endif
        // Force light appearance so the title, list rows, and buttons render dark-on-light
        .environment(\.colorScheme, .light)
        .task {
            await dataManager.fetchData()
        }
    }

    private func averageSpeedDescription(for session: GPSSession) -> String {
        guard let averageSpeedMPH = session.averageSpeedMPH else {
            return "unavailable"
        }

        return averageSpeedMPH < 1
            ? String(format: "%.1f ft/min", averageSpeedMPH * 5280 / 60)
            : String(format: "%.1f mph", averageSpeedMPH)
    }

    private func sessionTimeRange(for session: GPSSession) -> String {
        guard let first = session.points.first?.time,
              let last = session.points.last?.time else {
            return "time unavailable"
        }
        return "\(GPSDateFormat.time(first)) to \(GPSDateFormat.time(last))"
    }

    @ViewBuilder
    private var routeMapPresentation: some View {
        if let session = selectedMapSession {
            NavigationStack {
                LocationsMapView(points: session.points)
                    .id(session.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            VStack(spacing: 2) {
                                Text(dataManager.selectedDate?.formatted(date: .complete, time: .omitted) ?? "Route Map")
                                    .font(.custom("Josefin Sans", size: 20))
                                    .foregroundStyle(.black)
                                Text(sessionTimeRange(for: session))
                                    .font(.custom("Josefin Sans", size: 17))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.black)
                                Text("Session \(session.number) · \(session.points.count) locations, \(DistanceFormat.string(fromMeters: session.distanceMeters))")
                                    .font(.custom("Josefin Sans", size: 15))
                                    .foregroundStyle(.black)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isMapPresented = false
                            }
                            .font(.custom("Josefin Sans", size: 16))
                        }
                    }
            }
        }
    }

    // MARK: - Calendar and map

    /// The calendar (days with GPS data are filled in) next to, or above, the map for the chosen day.
    private var calendarContent: some View {
        ScrollView {
            // Side by side when there's room (e.g. iPad landscape), stacked otherwise.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    calendarColumn
                        .frame(width: 380)
                    resultsColumn
                        .frame(minWidth: 420)
                }

                VStack(spacing: 16) {
                    calendarColumn
                    Divider()
                    resultsColumn
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    private var calendarColumn: some View {
        VStack(spacing: 12) {
            CalendarPickerView(
                availableDays: dataManager.availableDays,
                selectedDate: dataManager.selectedDate
            ) { date in
                selectedSessionID = nil
                isSessionSelectorExpanded = false
                Task { await dataManager.selectDay(date) }
            }

            Text("Filled-in days have GPS location data")
                .font(.custom("Josefin Sans", size: 13))
                .foregroundStyle(.black)

            routeSummary
        }
    }

    /// Distance and speed for each session in the chosen day, shown under the calendar.
    @ViewBuilder
    private var routeSummary: some View {
        let sessions = routeSessions

        if dataManager.selectedDate != nil,
           !dataManager.isLoadingLocations,
           dataManager.locationsErrorMessage == nil,
           !sessions.isEmpty {
            let session = selectedMapSession ?? sessions[0]

            VStack(spacing: 8) {
                if sessions.count > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            isSessionSelectorExpanded.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Session \(session.number)")
                                    .font(.custom("Josefin Sans", size: 16))
                                Image(systemName: isSessionSelectorExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.calendarDayBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .background {
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        sessionSelectorWidth = geometry.size.width
                                    }
                                    .onChange(of: geometry.size.width) { _, width in
                                        sessionSelectorWidth = width
                                    }
                            }
                        }

                        if isSessionSelectorExpanded {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(sessions) { option in
                                    Button {
                                        selectedSessionID = option.id
                                        isSessionSelectorExpanded = false
                                    } label: {
                                        Text("Session \(option.number)")
                                            .font(.custom("Josefin Sans", size: 16))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 9)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(width: sessionSelectorWidth)
                            .background(Color.calendarDayBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.calendarDayBlue, lineWidth: 1)
                            }
                        }
                    }
                }

                Text(sessionTimeRange(for: session))
                    .font(.custom("Josefin Sans", size: 14))
                    .foregroundStyle(.black)

                Text(DistanceFormat.string(fromMeters: session.distanceMeters))
                    .font(.custom("Josefin Sans", size: 34))
                    .foregroundStyle(Color.calendarDayBlue)

                Text("Average speed: \(averageSpeedDescription(for: session))")
                    .font(.custom("Josefin Sans", size: 19))
                    .foregroundStyle(.black)

            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.calendarDayBlue, lineWidth: 1)
            )
            .shadow(color: Color.calendarDayBlue.opacity(0.25), radius: 4, x: 3, y: 3)
        }
    }

    private var resultsColumn: some View {
        VStack(spacing: 8) {
            locationsSection
        }
        .frame(maxWidth: .infinity)
    }

    /// What happened for the chosen day: a prompt, a spinner, an error, or its map.
    @ViewBuilder
    private var locationsSection: some View {
        if let selectedDate = dataManager.selectedDate {
            let title = selectedDate.formatted(date: .complete, time: .omitted)
            let points = dataManager.gpsPoints

            if dataManager.isLoadingLocations {
                ProgressView("Loading locations for \(title)…")
            } else if let message = dataManager.locationsErrorMessage {
                Text(message)
                    .foregroundStyle(.red)
            } else if dataManager.gpsLocations.isEmpty {
                Text("No gps_locations found for \(title)")
                    .font(.custom("Josefin Sans", size: 16))
            } else if points.isEmpty {
                // The documents loaded but none has a coordinate we recognize.
                VStack(spacing: 6) {
                    Text("Found \(dataManager.gpsLocations.count) locations for \(title), but couldn't find coordinates in them.")
                        .font(.custom("Josefin Sans", size: 16))
                    Text("Fields: \(dataManager.gpsLocations.first?.data.keys.sorted().joined(separator: ", ") ?? "none")")
                        .font(.custom("Josefin Sans", size: 13))
                        .foregroundStyle(.black)
                        .textSelection(.enabled)
                }
                .multilineTextAlignment(.center)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        isMapPresented = true
                    } label: {
                        Label("Open Route Map", systemImage: "map")
                            .foregroundStyle(.white)
                    }
                    .font(.custom("Josefin Sans", size: 16))
                    .buttonStyle(.borderedProminent)
                    .tint(Color.calendarDayBlue)
                }
            }
        } else {
            Text("Select a filled-in day to see its route on the map")
                .font(.custom("Josefin Sans", size: 16))
        }
    }

}
