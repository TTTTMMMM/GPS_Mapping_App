import SwiftUI
import MapKit

/// A map of one day's GPS fixes: a line through them in time order, a dot at each fix,
/// and Start / End pins. The camera is framed around all the points.
struct LocationsMapView: View {
    let points: [GPSPoint]

    var body: some View {
        Map(initialPosition: Self.cameraPosition(for: points)) {
            MapPolyline(coordinates: points.map(\.coordinate))
                .stroke(Color.calendarDayBlue, lineWidth: 4)

            ForEach(points) { point in
                Annotation("", coordinate: point.coordinate, anchor: .center) {
                    Circle()
                        .fill(Color.calendarDayBlue)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                }
            }

            if let first = points.first {
                Marker(Self.label("Start", for: first), systemImage: "flag.fill", coordinate: first.coordinate)
                    .tint(.green)
            }
            if points.count > 1, let last = points.last {
                Marker(Self.label("End", for: last), systemImage: "flag.checkered", coordinate: last.coordinate)
                    .tint(.red)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
#if os(macOS)
            // + / - buttons, since a Mac without a trackpad or touchscreen can't pinch to zoom
            MapZoomStepper()
#endif
        }
    }

    private static func label(_ name: String, for point: GPSPoint) -> String {
        guard let time = point.time else { return name }
        return "\(name) \(time.formatted(date: .omitted, time: .shortened))"
    }

    /// Frames all the points with some margin, and never zooms in tighter than ~300 m.
    private static func cameraPosition(for points: [GPSPoint]) -> MapCameraPosition {
        var rect = MKMapRect.null
        for point in points {
            let mapPoint = MKMapPoint(point.coordinate)
            rect = rect.union(MKMapRect(x: mapPoint.x, y: mapPoint.y, width: 0, height: 0))
        }
        guard !rect.isNull else { return .automatic }

        let center = MKMapPoint(x: rect.midX, y: rect.midY)
        let minimumSpan = 300 * MKMapPointsPerMeterAtLatitude(center.coordinate.latitude)
        let width = max(rect.width * 1.4, minimumSpan)
        let height = max(rect.height * 1.4, minimumSpan)

        return .rect(MKMapRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
    }
}
