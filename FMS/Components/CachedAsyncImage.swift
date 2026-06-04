import SwiftUI

@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    
    private init() {}
    
    func get(forKey url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }
    
    func set(_ image: UIImage, forKey url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
    
    func remove(forKey url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var uiImage: UIImage? = nil
    @State private var isLoading = false
    @State private var hasFailed = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let uiImage = uiImage {
                content(Image(uiImage: uiImage))
            } else if hasFailed {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                    Text("Failed to load image")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .padding()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
                    .onChange(of: url) { _, _ in
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        // 1. Check Cache
        if let cached = ImageCache.shared.get(forKey: url) {
            self.uiImage = cached
            self.hasFailed = false
            return
        }
        
        // 2. Fetch
        guard !isLoading else { return }
        isLoading = true
        hasFailed = false
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
            guard let data = data, let image = UIImage(data: data), error == nil else {
                DispatchQueue.main.async {
                    self.hasFailed = true
                }
                return
            }
            
            DispatchQueue.main.async {
                ImageCache.shared.set(image, forKey: url)
                self.uiImage = image
                self.hasFailed = false
            }
        }.resume()
    }
}
