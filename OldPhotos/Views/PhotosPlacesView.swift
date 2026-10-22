import SwiftUI
import MapKit
import Photos

/// OldOS `PlacesMapView`: a map with a red pin, dropped with the iOS 6
/// animation, wherever photos were taken. OldOS drew OpenStreetMap tiles and
/// the pins could not be tapped; the map is now the iOS 6 Apple map, it is
/// framed on your photos, and tapping a pin opens that place's photos.
struct PhotosPlacesView: View {
    @EnvironmentObject private var navigator: PhotosNavigator
    @ObservedObject private var library = PhotosLibrary.shared
    let topInset: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            PhotosMapView(places: library.places, topInset: topInset + 60) { place in
                open(place)
            }
            if library.isLoaded && library.places.isEmpty && library.canRead {
                Text("No Photos with Location")
                    .font(OldOSFont.bold(15))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.8), radius: 0, x: 0, y: -1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(.top, topInset + 76)
            }
        }
    }

    private func open(_ place: PhotosPlace) {
        let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let nav = navigator
        let fallback = "\(place.assetIdentifiers.count) \(place.assetIdentifiers.count == 1 ? "Photo" : "Photos")"
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            let name = placemarks?.first.flatMap { $0.locality ?? $0.name ?? $0.country } ?? fallback
            DispatchQueue.main.async {
                nav.open(PhotosAlbum(id: "place-\(place.id)", title: name, kind: .place(assetIdentifiers: place.assetIdentifiers)))
            }
        }
    }
}

private final class PhotosPlaceAnnotation: MKPointAnnotation {
    var place: PhotosPlace?
}

struct PhotosMapView: UIViewRepresentable {
    let places: [PhotosPlace]
    let topInset: CGFloat
    let onSelect: (PhotosPlace) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsUserLocation = false
        map.pointOfInterestFilter = .excludingAll
        map.layoutMargins = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        map.layoutMargins = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        let ids = places.map(\.id)
        guard ids != context.coordinator.shownIDs else { return }
        context.coordinator.shownIDs = ids
        map.removeAnnotations(map.annotations)
        let annotations: [PhotosPlaceAnnotation] = places.map { place in
            let annotation = PhotosPlaceAnnotation()
            annotation.coordinate = place.coordinate
            annotation.place = place
            return annotation
        }
        map.addAnnotations(annotations)
        if !annotations.isEmpty {
            map.showAnnotations(annotations, animated: false)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PhotosMapView
        var shownIDs: [String] = []

        init(_ parent: PhotosMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is PhotosPlaceAnnotation else { return nil }
            let identifier = "PhotosPin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.image = UIImage(named: "PlacePin")
            view.centerOffset = CGPoint(x: 6.5, y: -11.5)
            view.canShowCallout = false
            return view
        }

        /// The iOS 6 pin drop (OldOS `didAdd views`).
        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            let visible = mapView.annotationVisibleRect
            for view in views {
                let end = view.frame
                var start = end
                start.origin.y = visible.origin.y - start.size.height
                view.frame = start
                UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseIn, animations: {
                    view.frame = end
                }, completion: nil)
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            mapView.deselectAnnotation(view.annotation, animated: false)
            if let place = (view.annotation as? PhotosPlaceAnnotation)?.place {
                OldPhotosHaptics.tap()
                parent.onSelect(place)
            }
        }
    }
}
