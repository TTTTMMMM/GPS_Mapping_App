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
                            .foregroundStyle(.black.opacity(0.7))
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
            .foregroundStyle(.black)
            .navigationTitle("GPS Tracker")
            .profileToolbar(authManager: authManager)
        }
        // Force light appearance so the title, list rows, and buttons render dark-on-light
        .environment(\.colorScheme, .light)
        .task {
            await dataManager.fetchData()
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
                    resultsColumn(mapHeight: 560)
                        .frame(minWidth: 420)
                }

                VStack(spacing: 16) {
                    calendarColumn
                    Divider()
                    resultsColumn(mapHeight: 420)
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
                Task { await dataManager.selectDay(date) }
            }

            Text("Filled-in days have GPS location data")
                .font(.custom("Josefin Sans", size: 13))
                .foregroundStyle(.black.opacity(0.7))

            routeSummary
        }
    }

    /// Total distance travelled on the chosen day, shown under the calendar.
    @ViewBuilder
    private var routeSummary: some View {
        let points = dataManager.gpsPoints

        if dataManager.selectedDate != nil,
           !dataManager.isLoadingLocations,
           dataManager.locationsErrorMessage == nil,
           points.count > 1 {
            VStack(spacing: 4) {
                Text("Distance traveled")
                    .font(.custom("Josefin Sans", size: 13))
                    .foregroundStyle(.black.opacity(0.7))

                Text(DistanceFormat.string(fromMeters: points.distanceMeters()))
                    .font(.custom("Josefin Sans", size: 34))
                    .foregroundStyle(Color.calendarDayBlue)

                // Shown so you can see how much GPS jitter the filter removed
                Text("Moves under \(DistanceFormat.string(fromMeters: RouteFilter.minimumMoveMeters)) ignored. Raw GPS path: \(DistanceFormat.string(fromMeters: points.totalDistanceMeters))")
                    .font(.custom("Josefin Sans", size: 12))
                    .foregroundStyle(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                if let first = points.first?.time, let last = points.last?.time {
                    Text("\(first.formatted(date: .omitted, time: .shortened)) to \(last.formatted(date: .omitted, time: .shortened))")
                        .font(.custom("Josefin Sans", size: 13))
                        .foregroundStyle(.black.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func resultsColumn(mapHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            locationsSection(mapHeight: mapHeight)
        }
        .frame(maxWidth: .infinity)
    }

    /// What happened for the chosen day: a prompt, a spinner, an error, or its map.
    @ViewBuilder
    private func locationsSection(mapHeight: CGFloat) -> some View {
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
                        .foregroundStyle(.black.opacity(0.7))
                        .textSelection(.enabled)
                }
                .multilineTextAlignment(.center)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.custom("Josefin Sans", size: 18))
                    Text(summary(points: points.count, total: dataManager.gpsLocations.count))
                        .font(.custom("Josefin Sans", size: 13))
                        .foregroundStyle(.black.opacity(0.7))

                    LocationsMapView(points: points)
                        .id(selectedDate) // reframe the camera whenever a new day is chosen
                        .frame(height: mapHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        } else {
            Text("Select a filled-in day to see its route on the map")
                .font(.custom("Josefin Sans", size: 16))
        }
    }

    private func summary(points: Int, total: Int) -> String {
        let base = "\(points) location\(points == 1 ? "" : "s") on the map"
        return points < total ? "\(base) (\(total - points) without a usable coordinate)" : base
    }
}
