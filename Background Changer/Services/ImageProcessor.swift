import Foundation
import AppKit
import ImageIO
import CoreGraphics
import OSLog
import UniformTypeIdentifiers

// MARK: - Image Processor with Performance Optimizations
public final class ImageProcessor {
    public static let shared = ImageProcessor()
    
    private let processingQueue: OperationQueue
    private let thumbnailCache = NSCache<NSURL, NSImage>()
    private let previewCache = NSCache<NSURL, NSImage>()
    private let metadataCache = NSCache<NSURL, ProcessedMetadata>()
    private let logger = Logger(subsystem: "WallpaperManager", category: "ImageProcessor")
    
    // Configuration
    private let thumbnailSize = CGSize(width: 200, height: 150)
    private let previewSize = CGSize(width: 800, height: 600)
    private let maxImageSize: Int64 = 50 * 1024 * 1024 // 50MB
    private let minImageSize = CGSize(width: 800, height: 600)
    
    // Supported formats
    private let supportedTypes: [UTType] = [
        .jpeg, .png, .heic, .tiff, .bmp, .gif, .webP
    ]
    
    private init() {
        processingQueue = OperationQueue()
        processingQueue.maxConcurrentOperationCount = min(4, ProcessInfo.processInfo.processorCount)
        processingQueue.qualityOfService = .userInitiated
        processingQueue.name = "ImageProcessingQueue"
        
        setupCaches()
        setupMemoryPressureHandling()
    }
    
    private func setupCaches() {
        // Thumbnail cache - smaller images, more count
        thumbnailCache.countLimit = 500
        thumbnailCache.totalCostLimit = 20 * 1024 * 1024 // 20MB
        thumbnailCache.name = "ThumbnailCache"
        
        // Preview cache - larger images, fewer count
        previewCache.countLimit = 100
        previewCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        previewCache.name = "PreviewCache"
        
        // Metadata cache - very lightweight
        metadataCache.countLimit = 1000
        metadataCache.totalCostLimit = 5 * 1024 * 1024 // 5MB
        metadataCache.name = "MetadataCache"
    }
    
    private func setupMemoryPressureHandling() {
        let memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        
        memoryPressureSource.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let event = memoryPressureSource.data
            switch event {
            case .warning:
                self.reduceCacheSize(by: 0.5)
                self.logger.warning("Memory pressure warning - reduced cache size")
            case .critical:
                self.clearAllCaches()
                self.logger.error("Memory pressure critical - cleared all caches")
            default:
                break
            }
        }
        
        memoryPressureSource.resume()
    }
    
    // MARK: - Main Processing Method
    public func processWallpaper(at url: URL) async throws -> ProcessedWallpaper {
        logger.debug("Processing wallpaper: \(url.lastPathComponent)")
        
        // Validate file exists and is readable
        try await validateImageFile(at: url)
        
        // Process in parallel for efficiency
        async let thumbnail = generateThumbnail(url)
        async let preview = generatePreview(url)
        async let metadata = extractMetadata(url)
        
        do {
            let processedWallpaper = try await ProcessedWallpaper(
                thumbnail: thumbnail,
                preview: preview,
                metadata: metadata,
                originalURL: url
            )
            
            logger.debug("Successfully processed wallpaper: \(url.lastPathComponent)")
            return processedWallpaper
            
        } catch {
            logger.error("Failed to process wallpaper \(url.lastPathComponent): \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Thumbnail Generation
    public func generateThumbnail(_ url: URL) async throws -> NSImage {
        // Check cache first
        if let cached = thumbnailCache.object(forKey: url as NSURL) {
            logger.debug("Thumbnail cache hit for: \(url.lastPathComponent)")
            return cached
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.addOperation {
                do {
                    let thumbnail = try self.createThumbnail(from: url, targetSize: self.thumbnailSize)
                    
                    // Cache the result
                    let estimatedSize = Int(thumbnail.size.width * thumbnail.size.height * 4)
                    self.thumbnailCache.setObject(thumbnail, forKey: url as NSURL, cost: estimatedSize)
                    
                    continuation.resume(returning: thumbnail)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Preview Generation
    public func generatePreview(_ url: URL) async throws -> NSImage {
        // Check cache first
        if let cached = previewCache.object(forKey: url as NSURL) {
            logger.debug("Preview cache hit for: \(url.lastPathComponent)")
            return cached
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.addOperation {
                do {
                    let preview = try self.createThumbnail(from: url, targetSize: self.previewSize)
                    
                    // Cache the result
                    let estimatedSize = Int(preview.size.width * preview.size.height * 4)
                    self.previewCache.setObject(preview, forKey: url as NSURL, cost: estimatedSize)
                    
                    continuation.resume(returning: preview)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Metadata Extraction
    public func extractMetadata(_ url: URL) async throws -> ProcessedMetadata {
        // Check cache first
        if let cached = metadataCache.object(forKey: url as NSURL) {
            logger.debug("Metadata cache hit for: \(url.lastPathComponent)")
            return cached
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.addOperation {
                do {
                    let metadata = try self.extractImageMetadata(from: url)
                    
                    // Cache the result
                    self.metadataCache.setObject(metadata, forKey: url as NSURL, cost: MemoryLayout<ProcessedMetadata>.size)
                    
                    continuation.resume(returning: metadata)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Core Image Processing
    private func createThumbnail(from url: URL, targetSize: CGSize) throws -> NSImage {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw AppError.invalidImage(url, reason: .corruptedFile)
        }
        
        let maxPixelSize = max(targetSize.width, targetSize.height)
        
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw AppError.invalidImage(url, reason: .corruptedFile)
        }
        
        return NSImage(cgImage: thumbnail, size: targetSize)
    }
    
    private func extractImageMetadata(from url: URL) throws -> ProcessedMetadata {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw AppError.invalidImage(url, reason: .corruptedFile)
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            throw AppError.invalidImage(url, reason: .corruptedFile)
        }
        
        // Extract basic properties
        let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        let colorDepth = properties[kCGImagePropertyDepth] as? Int ?? 8
        let hasAlpha = properties[kCGImagePropertyHasAlpha] as? Bool ?? false
        
        // Get file attributes
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        let modificationDate = fileAttributes[.modificationDate] as? Date ?? Date()
        
        // Determine color space
        let colorSpace: ColorSpaceInfo
        if let colorSpaceRef = properties[kCGImagePropertyColorModel] as? String {
            colorSpace = ColorSpaceInfo(from: colorSpaceRef)
        } else {
            colorSpace = .unknown
        }
        
        // Extract EXIF data if available
        var cameraInfo: CameraInfo?
        if let exifDict = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            cameraInfo = CameraInfo(from: exifDict)
        }
        
        // Determine optimal time of day for display (based on image analysis)
        let timePreference = try analyzeImageForTimePreference(imageSource: imageSource)
        
        return ProcessedMetadata(
            dimensions: CGSize(width: pixelWidth, height: pixelHeight),
            fileSize: fileSize,
            colorDepth: colorDepth,
            hasAlpha: hasAlpha,
            colorSpace: colorSpace,
            modificationDate: modificationDate,
            cameraInfo: cameraInfo,
            timeOfDayPreference: timePreference,
            dominantColors: try extractDominantColors(imageSource: imageSource)
        )
    }
    
    // MARK: - Image Analysis
    private func analyzeImageForTimePreference(imageSource: CGImageSource) throws -> Set<Int> {
        // Analyze image brightness and color temperature to suggest optimal display times
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            imageSource, 0,
            [kCGImageSourceThumbnailMaxPixelSize: 100] as CFDictionary
        ) else {
            return Set(0...23) // Default to all hours if analysis fails
        }
        
        let brightness = calculateImageBrightness(thumbnail)
        let warmth = calculateColorWarmth(thumbnail)
        
        // Determine optimal hours based on image characteristics
        var preferredHours: Set<Int> = []
        
        if brightness < 0.3 {
            // Dark images - better for evening/night
            preferredHours = Set([18, 19, 20, 21, 22, 23, 0, 1, 2, 3, 4, 5])
        } else if brightness > 0.7 {
            // Bright images - better for day time
            preferredHours = Set([6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17])
        } else {
            // Medium brightness - good anytime
            preferredHours = Set(0...23)
        }
        
        if warmth > 0.6 {
            // Warm images - better for morning and evening
            preferredHours = preferredHours.intersection(Set([5, 6, 7, 8, 17, 18, 19, 20]))
        }
        
        return preferredHours.isEmpty ? Set(0...23) : preferredHours
    }
    
    private func calculateImageBrightness(_ cgImage: CGImage) -> Double {
        // Simple brightness calculation based on luminance
        let width = cgImage.width
        let height = cgImage.height
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pixelData = CFDataGetBytePtr(data) else {
            return 0.5 // Default brightness
        }
        
        var totalBrightness: Double = 0
        let pixelCount = width * height
        
        for i in stride(from: 0, to: pixelCount * 4, by: 4) {
            let r = Double(pixelData[i])
            let g = Double(pixelData[i + 1])
            let b = Double(pixelData[i + 2])
            
            // Calculate luminance
            let brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            totalBrightness += brightness
        }
        
        return totalBrightness / Double(pixelCount)
    }
    
    private func calculateColorWarmth(_ cgImage: CGImage) -> Double {
        // Calculate color temperature (warmth vs coolness)
        let width = cgImage.width
        let height = cgImage.height
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pixelData = CFDataGetBytePtr(data) else {
            return 0.5 // Default warmth
        }
        
        var totalWarmth: Double = 0
        let pixelCount = width * height
        
        for i in stride(from: 0, to: pixelCount * 4, by: 4) {
            let r = Double(pixelData[i])
            let g = Double(pixelData[i + 1])
            let b = Double(pixelData[i + 2])
            
            // Simple warmth calculation: more red/yellow = warmer
            let warmth = (r + g/2) / (b + 1) // Avoid division by zero
            totalWarmth += warmth
        }
        
        let averageWarmth = totalWarmth / Double(pixelCount)
        return min(1.0, averageWarmth / 2.0) // Normalize to 0-1 range
    }
    
    private func extractDominantColors(imageSource: CGImageSource) throws -> [NSColor] {
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            imageSource, 0,
            [kCGImageSourceThumbnailMaxPixelSize: 50] as CFDictionary
        ) else {
            return []
        }
        
        // Extract dominant colors using simple color quantization
        var colorCounts: [UInt32: Int] = [:]
        
        let width = thumbnail.width
        let height = thumbnail.height
        
        guard let dataProvider = thumbnail.dataProvider,
              let data = dataProvider.data,
              let pixelData = CFDataGetBytePtr(data) else {
            return []
        }
        
        // Sample every 4th pixel for performance
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                let pixelIndex = (y * width + x) * 4
                guard pixelIndex + 3 < CFDataGetLength(data) else { continue }
                
                let r = pixelData[pixelIndex]
                let g = pixelData[pixelIndex + 1]
                let b = pixelData[pixelIndex + 2]
                
                // Quantize colors to reduce similar colors
                let quantizedR = (r / 32) * 32
                let quantizedG = (g / 32) * 32
                let quantizedB = (b / 32) * 32
                
                let colorKey = UInt32(quantizedR) << 16 | UInt32(quantizedG) << 8 | UInt32(quantizedB)
                colorCounts[colorKey, default: 0] += 1
            }
        }
        
        // Get top 5 colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }.prefix(5)
        
        return sortedColors.map { colorKey, _ in
            let r = CGFloat((colorKey >> 16) & 0xFF) / 255.0
            let g = CGFloat((colorKey >> 8) & 0xFF) / 255.0
            let b = CGFloat(colorKey & 0xFF) / 255.0
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)
        }
    }
    
    // MARK: - Validation
    private func validateImageFile(at url: URL) async throws {
        let fileManager = FileManager.default
        
        // Check file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw AppError.systemOperation(.insufficientPermissions("File not found: \(url.path)"))
        }
        
        // Check file size
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        guard fileSize <= maxImageSize else {
            throw AppError.invalidImage(url, reason: .tooLarge(size: fileSize, maxSize: maxImageSize))
        }

        guard fileSize > 0 else {
            throw AppError.invalidImage(url, reason: .corruptedFile)
        }
        
        // Check file type
        let resourceValues = try url.resourceValues(forKeys: [.typeIdentifierKey])
        guard let typeIdentifier = resourceValues.typeIdentifier,
              let utType = UTType(typeIdentifier),
              supportedTypes.contains(where: { utType.conforms(to: $0) }) else {
            let fileExtension = url.pathExtension.lowercased()
            throw AppError.invalidImage(url, reason: .unsupportedFormat(fileExtension))
        }
    }
    
    // MARK: - Cache Management
    public func clearAllCaches() {
        thumbnailCache.removeAllObjects()
        previewCache.removeAllObjects()
        metadataCache.removeAllObjects()
        logger.info("All image caches cleared")
    }
    
    public func reduceCacheSize(by factor: Double) {
        let thumbnailNewLimit = Int(Double(thumbnailCache.totalCostLimit) * (1 - factor))
        thumbnailCache.totalCostLimit = max(5 * 1024 * 1024, thumbnailNewLimit) // Min 5MB
        
        let previewNewLimit = Int(Double(previewCache.totalCostLimit) * (1 - factor))
        previewCache.totalCostLimit = max(10 * 1024 * 1024, previewNewLimit) // Min 10MB
        
        logger.info("Cache sizes reduced by \(Int(factor * 100))%")
    }
    
    public func getCacheInfo() -> CacheInfo {
        return CacheInfo(
            thumbnailCount: thumbnailCache.countLimit,
            thumbnailSize: thumbnailCache.totalCostLimit,
            previewCount: previewCache.countLimit,
            previewSize: previewCache.totalCostLimit,
            metadataCount: metadataCache.countLimit
        )
    }
    
    // MARK: - Repair Operations
    public func repairImage(at url: URL) async throws {
        // Attempt to repair corrupted image by re-encoding
        let originalImage = NSImage(contentsOf: url)
        guard let originalImage = originalImage else {
            throw AppError.invalidImage(url, reason: .corruptedFile)
        }
        
        // Create backup
        let backupURL = url.appendingPathExtension("backup")
        try FileManager.default.copyItem(at: url, to: backupURL)
        
        // Re-save as JPEG with high quality
        guard let tiffData = originalImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            throw AppError.invalidImage(url, reason: .corruptedFile)
        }
        
        try jpegData.write(to: url)
        logger.info("Image repaired: \(url.lastPathComponent)")
    }
}

// MARK: - Supporting Types
public struct ProcessedWallpaper {
    public let thumbnail: NSImage
    public let preview: NSImage
    public let metadata: ProcessedMetadata
    public let originalURL: URL
    
    public init(thumbnail: NSImage, preview: NSImage, metadata: ProcessedMetadata, originalURL: URL) {
        self.thumbnail = thumbnail
        self.preview = preview
        self.metadata = metadata
        self.originalURL = originalURL
    }
}

public struct ProcessedMetadata {
    public let dimensions: CGSize
    public let fileSize: Int64
    public let colorDepth: Int
    public let hasAlpha: Bool
    public let colorSpace: ColorSpaceInfo
    public let modificationDate: Date
    public let cameraInfo: CameraInfo?
    public let timeOfDayPreference: Set<Int>
    public let dominantColors: [NSColor]
}

public enum ColorSpaceInfo {
    case sRGB
    case displayP3
    case adobeRGB
    case rec2020
    case gray
    case cmyk
    case unknown
    
    init(from colorModel: String) {
        switch colorModel.lowercased() {
        case "rgb":
            self = .sRGB
        case "gray", "grey":
            self = .gray
        case "cmyk":
            self = .cmyk
        default:
            self = .unknown
        }
    }
}

public struct CameraInfo {
    public let make: String?
    public let model: String?
    public let dateTimeOriginal: Date?
    public let fNumber: Double?
    public let exposureTime: Double?
    public let iso: Int?
    
    init(from exifDict: [CFString: Any]) {
        self.make = exifDict[kCGImagePropertyExifLensMake] as? String
        self.model = exifDict[kCGImagePropertyExifLensModel] as? String
        
        if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            self.dateTimeOriginal = formatter.date(from: dateString)
        } else {
            self.dateTimeOriginal = nil
        }
        
        self.fNumber = exifDict[kCGImagePropertyExifFNumber] as? Double
        self.exposureTime = exifDict[kCGImagePropertyExifExposureTime] as? Double
        self.iso = exifDict[kCGImagePropertyExifISOSpeedRatings] as? Int
    }
}

public struct CacheInfo {
    public let thumbnailCount: Int
    public let thumbnailSize: Int
    public let previewCount: Int
    public let previewSize: Int
    public let metadataCount: Int
}
