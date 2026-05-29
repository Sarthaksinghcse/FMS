import SwiftUI
import MapKit

@available(iOS 26.0, *)
struct LocationPickerSheet: View {
    let title: String
    let initialLocation: String
    let initialCoordinate: CLLocationCoordinate2D?
    let onConfirm: (String, CLLocationCoordinate2D) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var position: MapCameraPosition = .automatic
    @State private var centerCoordinate: CLLocationCoordinate2D
    @State private var addressText: String = ""
    @State private var isGeocoding: Bool = false
    
    @State private var searchQuery = ""
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var searchCompleter = LocalSearchCompleter()
    @State private var isSearching = false
    
    init(title: String, initialLocation: String, initialCoordinate: CLLocationCoordinate2D?, onConfirm: @escaping (String, CLLocationCoordinate2D) -> Void) {
        self.title = title
        self.initialLocation = initialLocation
        self.initialCoordinate = initialCoordinate
        self.onConfirm = onConfirm
        
        let startCoord = initialCoordinate ?? CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090) // Default to New Delhi
        _centerCoordinate = State(initialValue: startCoord)
        _addressText = State(initialValue: initialLocation)
        _position = State(initialValue: .region(MKCoordinateRegion(center: startCoord, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search address or pincode", text: $searchQuery)
                        .autocorrectionDisabled()
                        .onChange(of: searchQuery) { _, newValue in
                            searchCompleter.search(query: newValue)
                        }
                    
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                if !searchResults.isEmpty && !searchQuery.isEmpty {
                    List(searchResults, id: \.self) { result in
                        Button {
                            selectSearchResult(result)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(result.title)
                                    .foregroundColor(.primary)
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    // Map View
                    ZStack(alignment: .center) {
                        Map(position: $position)
                            .onMapCameraChange(frequency: .onEnd) { context in
                                centerCoordinate = context.camera.centerCoordinate
                                reverseGeocode(coordinate: centerCoordinate)
                            }
                        
                        // Center Pin
                        VStack(spacing: 0) {
                            Image(systemName: "mappin")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(AppTheme.Brand.royalBlue)
                            Circle()
                                .fill(Color.black.opacity(0.2))
                                .frame(width: 10, height: 4)
                                .scaleEffect(x: 1, y: 0.5)
                        }
                        .offset(y: -16) // Offset so the pin tip is at the center
                        
                        // Recenter to Current Location Button
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    if let currentLoc = LocationService.shared.manager.location?.coordinate {
                                        withAnimation {
                                            position = .region(MKCoordinateRegion(center: currentLoc, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
                                        }
                                    }
                                } label: {
                                    Image(systemName: "location.fill")
                                        .padding()
                                        .background(Color(.systemBackground))
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .padding()
                            }
                        }
                    }
                }
                
                // Bottom Confirm Bar
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Selected Location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ZStack(alignment: .leading) {
                                Text(addressText.isEmpty ? "Locating..." : addressText)
                                    .font(.system(size: 16, weight: .medium))
                                    .lineLimit(2)
                                    .opacity(isGeocoding ? 0.3 : 1.0)
                                
                                if isGeocoding {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .controlSize(.small)
                                        Spacer()
                                    }
                                }
                            }
                            .frame(height: 44, alignment: .topLeading)
                        }
                        Spacer()
                    }
                    
                    Button {
                        onConfirm(addressText, centerCoordinate)
                        dismiss()
                    } label: {
                        Text("Confirm Location")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(addressText.isEmpty ? Color.gray : AppTheme.Brand.royalBlue)
                            .cornerRadius(12)
                    }
                    .disabled(addressText.isEmpty || isGeocoding)
                }
                .padding()
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                searchCompleter.onResults = { results in
                    self.searchResults = results
                }
            }
        }
    }
    
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        isGeocoding = true
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        Task {
            if let request = MKReverseGeocodingRequest(location: location) {
                do {
                    let mapItems = try await request.mapItems
                    await MainActor.run {
                        self.isGeocoding = false
                        if let item = mapItems.first {
                            let name = item.name ?? ""
                            let cityState = item.addressRepresentations?.cityWithContext ?? ""
                            
                            var parts: [String] = []
                            if !name.isEmpty { parts.append(name) }
                            if !cityState.isEmpty && !cityState.contains(name) { parts.append(cityState) }
                            
                            let newAddress = parts.joined(separator: ", ")
                            if !newAddress.isEmpty {
                                self.addressText = newAddress
                            }
                        }
                    }
                } catch {
                    await MainActor.run { self.isGeocoding = false }
                }
            } else {
                await MainActor.run { self.isGeocoding = false }
            }
        }
    }
    
    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        searchQuery = ""
        searchResults = []
        isSearching = true
        
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            isSearching = false
            guard let coordinate = response?.mapItems.first?.location.coordinate else { return }
            
            withAnimation {
                position = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
            }
            centerCoordinate = coordinate
            if let name = response?.mapItems.first?.name {
                addressText = name
            } else {
                reverseGeocode(coordinate: coordinate)
            }
        }
    }
}

// Helper class for MKLocalSearchCompleter delegate
class LocalSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    var onResults: (([MKLocalSearchCompletion]) -> Void)?
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    func search(query: String) {
        if query.isEmpty {
            onResults?([])
            return
        }
        completer.queryFragment = query
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResults?(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search failed: \(error.localizedDescription)")
    }
}
