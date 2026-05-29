import MapKit

func reverseGeocode(coordinate: CLLocationCoordinate2D) {
    let request = MKReverseGeocodingRequest(coordinate: coordinate)
    let search = MKLocalSearch(request: request)
    search.start { response, error in
        if let item = response?.mapItems.first {
            let name = item.name
            let city = item.placemark.locality
            let state = item.placemark.administrativeArea
        }
    }
}
