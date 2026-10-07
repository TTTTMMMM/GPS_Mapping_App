import Foundation
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

/// Converts between `unique_days` document IDs (formatted `YYYY_MM_DD`) and real dates.
enum DayID {
    /// Gregorian calendar in the user's current time zone; every day is represented
    /// by its local midnight so dates compare reliably.
    static let calendar = Calendar(identifier: .gregorian)

    /// "2026_10_04" -> local midnight on Oct 4, 2026. Returns nil for anything malformed
    /// (including impossible dates such as "2026_02_31").
    static func date(from id: String) -> Date? {
        let parts = id.split(separator: "_")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }

        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return nil }

        // Reject dates the calendar silently rolled over (e.g. Feb 31 -> Mar 3).
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return date
    }

    /// Local midnight on Oct 4, 2026 -> "2026_10_04" (the document ID format).
    static func id(from date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d_%02d_%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// A single document fetched from Firestore, flattened to its id and data fields.
struct FirestoreDocument: Identifiable {
    let id: String
    let data: [String: Any]

    /// The date this document represents, parsed from its `YYYY_MM_DD` ID.
    var day: Date? { DayID.date(from: id) }

    /// A human-readable string for a field's value. Dates (Firestore `Timestamp`s,
    /// or a numeric `ttl` stored as epoch seconds/milliseconds) are formatted nicely.
    func displayValue(for key: String) -> String {
        guard let value = data[key] else { return "" }

        if let timestamp = value as? Timestamp {
            return Self.format(timestamp.dateValue())
        }
        if let date = value as? Date {
            return Self.format(date)
        }
        if let point = value as? GeoPoint {
            return String(format: "%.5f, %.5f", point.latitude, point.longitude)
        }
        // Some schemas store a TTL as a plain number (epoch seconds or milliseconds).
        if key.lowercased() == "ttl", let number = value as? NSNumber {
            let raw = number.doubleValue
            let seconds = raw > 100_000_000_000 ? raw / 1000 : raw
            return Self.format(Date(timeIntervalSince1970: seconds))
        }
        return String(describing: value)
    }

    private static func format(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

/// One recorded GPS fix from a `gps_locations` document.
struct GPSPoint: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    /// When the fix was recorded (the document's `dt` field), if present.
    let time: Date?

    /// Reads a coordinate out of a document, or returns nil if it doesn't have a usable one.
    /// Recognizes a Firestore `GeoPoint` in any field, or numeric latitude/longitude fields
    /// named lat/latitude and lon/lng/long/longitude (case-insensitive).
    init?(document: FirestoreDocument) {
        guard let coordinate = Self.coordinate(in: document.data) else { return nil }
        self.id = document.id
        self.coordinate = coordinate
        self.time = (document.data["dt"] as? Timestamp)?.dateValue()
    }

    private static func coordinate(in data: [String: Any]) -> CLLocationCoordinate2D? {
        var latitude: Double?
        var longitude: Double?

        for (key, value) in data {
            if let point = value as? GeoPoint {
                latitude = point.latitude
                longitude = point.longitude
                break
            }
            switch key.lowercased() {
            case "lat", "latitude": latitude = number(from: value)
            case "lon", "lng", "long", "longitude": longitude = number(from: value)
            default: break
            }
        }

        guard let latitude, let longitude,
              (-90...90).contains(latitude), (-180...180).contains(longitude),
              !(latitude == 0 && longitude == 0) // 0,0 is what a tracker reports with no GPS fix
        else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func number(from value: Any) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }
}

extension GPSPoint {
    /// Straight-line distance to another point, in meters.
    func distance(to other: GPSPoint) -> CLLocationDistance {
        let from = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let to = CLLocation(latitude: other.coordinate.latitude, longitude: other.coordinate.longitude)
        return from.distance(from: to)
    }
}

/// Settings for ignoring GPS jitter when measuring a route.
enum RouteFilter {
    /// A point only counts as movement once it is at least this far from the last point that
    /// counted. A GPS module sitting still (especially indoors) reports positions that wander
    /// by roughly 5 to 30 m; this should be a little larger than that wander.
    /// Raise it if a parked tracker still shows distance; lower it if real, slow walks come
    /// out too short.
    static let minimumMoveMeters: CLLocationDistance = 25
}

extension Array where Element == GPSPoint {
    /// Raw length of the route, in meters: the sum of the straight-line distances between each
    /// point and the next, in time order. GPS jitter inflates this when the tracker is still.
    var totalDistanceMeters: CLLocationDistance {
        zip(self, dropFirst()).reduce(0) { total, pair in total + pair.0.distance(to: pair.1) }
    }

    /// Length of the route in meters, ignoring jitter: a point is only counted once it is at
    /// least `minimum` meters from the last point that was counted (the "anchor").
    /// Points that stay inside that radius, like a tracker wandering on a desk, add nothing.
    func distanceMeters(ignoringMovesUnder minimum: CLLocationDistance = RouteFilter.minimumMoveMeters) -> CLLocationDistance {
        guard var anchor = first else { return 0 }
        var total: CLLocationDistance = 0
        for point in dropFirst() {
            let moved = anchor.distance(to: point)
            if moved >= minimum {
                total += moved
                anchor = point
            }
        }
        return total
    }
}

/// Formats a distance in US units: feet for short routes, miles otherwise.
enum DistanceFormat {
    private static let metersPerMile = 1609.344
    private static let feetPerMeter = 3.28084

    static func string(fromMeters meters: CLLocationDistance) -> String {
        let miles = meters / metersPerMile
        if miles < 0.1 {
            return "\(Int((meters * feetPerMeter).rounded())) ft"
        }
        return String(format: "%.2f mi", miles)
    }
}

/// Fetches documents from the app's Firestore collections for the
/// currently authenticated user.
@Observable
final class FirestoreDataManager {
    var uniqueDays: [FirestoreDocument] = []
    var isLoading = false
    var errorMessage: String?

    /// The day picked in the calendar, and the `gps_locations` documents recorded on it.
    var selectedDate: Date?
    var gpsLocations: [FirestoreDocument] = []
    var isLoadingLocations = false
    var locationsErrorMessage: String?

    /// The chosen day's locations that have a usable coordinate, in time order.
    var gpsPoints: [GPSPoint] {
        gpsLocations.compactMap(GPSPoint.init(document:))
    }

    /// The dates of all fetched `unique_days` documents, oldest first.
    var availableDays: [Date] {
        uniqueDays.compactMap(\.day).sorted()
    }

    private let db = Firestore.firestore()

    func fetchData() async {
        // Reads require a signed-in user; who may read is enforced by Firestore security rules.
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "No authenticated user."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            uniqueDays = try await fetchCollection(named: "unique_days", uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Selects a day and loads the `gps_locations` documents whose `dt` timestamp falls
    /// within that day (local midnight to the next local midnight).
    func selectDay(_ date: Date) async {
        selectedDate = date
        gpsLocations = []
        locationsErrorMessage = nil
        isLoadingLocations = true

        let calendar = DayID.calendar
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            isLoadingLocations = false
            return
        }

        do {
            // A range + sort on the single field `dt` needs no composite index.
            let snapshot = try await db.collection("gps_locations")
                .whereField("dt", isGreaterThanOrEqualTo: Timestamp(date: start))
                .whereField("dt", isLessThan: Timestamp(date: end))
                .order(by: "dt")
                .getDocuments()

            // Ignore this result if the user has already picked a different day.
            guard selectedDate == date else { return }

            print("Firestore: 'gps_locations' returned \(snapshot.documents.count) document(s) for \(DayID.id(from: date))")
            gpsLocations = snapshot.documents.map { FirestoreDocument(id: $0.documentID, data: $0.data()) }
        } catch {
            guard selectedDate == date else { return }
            locationsErrorMessage = error.localizedDescription
        }
        isLoadingLocations = false
    }

    /// Reads every document in a collection (the data is shared, not filtered per user).
    private func fetchCollection(named name: String, uid: String) async throws -> [FirestoreDocument] {
        let snapshot = try await db.collection(name).getDocuments()

        print("Firestore: '\(name)' returned \(snapshot.documents.count) document(s) (signed in as \(uid))")
        return snapshot.documents.map { FirestoreDocument(id: $0.documentID, data: $0.data()) }
    }
}
