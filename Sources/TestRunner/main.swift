import Foundation
import AppKit
import UniformTypeIdentifiers
import PDFKit
import RadialDropCore

@MainActor
func runTests() async throws {
    print("========================================")
    print("  RadialDrop Automated Test Suite")
    print("========================================")

    var passed = 0
    var failed = 0

    func assertTest(_ condition: Bool, _ name: String) {
        if condition {
            print("  [PASS] \(name)")
            passed += 1
        } else {
            print("  [FAIL] \(name)")
            failed += 1
        }
    }

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("RadialDrop_Test_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // 1. FileInspector Tests
    print("\n[1] Testing FileInspector...")
    let inspector = FileInspector()
    assertTest(inspector.categorize(url: URL(fileURLWithPath: "photo.jpg")) == .image, "JPG identified as image")
    assertTest(inspector.categorize(url: URL(fileURLWithPath: "video.mov")) == .video, "MOV identified as video")
    assertTest(inspector.categorize(url: URL(fileURLWithPath: "audio.mp3")) == .audio, "MP3 identified as audio")
    assertTest(inspector.categorize(url: URL(fileURLWithPath: "doc.pdf")) == .pdf, "PDF identified as pdf")

    let pdfItems = inspector.getConversionItems(for: URL(fileURLWithPath: "doc.pdf"))
    assertTest(pdfItems.contains { $0.id == "split" }, "PDF items include Split Pages")
    assertTest(pdfItems.contains { $0.id == "compress" }, "PDF items include Compress")

    // 2. ImageConverter Tests
    print("\n[2] Testing ImageConverter...")
    let testImage = NSImage(size: NSSize(width: 64, height: 64))
    testImage.lockFocus()
    NSColor.orange.setFill()
    NSRect(x: 0, y: 0, width: 64, height: 64).fill()
    testImage.unlockFocus()

    guard let tiffData = testImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to create test image data")
    }

    let sourceImageURL = tempDir.appendingPathComponent("source.png")
    try pngData.write(to: sourceImageURL)

    let imageConverter = ImageConverter()

    let jpegURL = try imageConverter.convert(sourceURL: sourceImageURL, to: .jpeg)
    assertTest(FileManager.default.fileExists(atPath: jpegURL.path), "Convert PNG -> JPEG")

    let webpURL = try imageConverter.convert(sourceURL: sourceImageURL, to: .webP)
    assertTest(FileManager.default.fileExists(atPath: webpURL.path), "Convert PNG -> WebP")

    let heicURL = try imageConverter.convert(sourceURL: sourceImageURL, to: .heic)
    assertTest(FileManager.default.fileExists(atPath: heicURL.path), "Convert PNG -> HEIC")

    let tiffURL = try imageConverter.convert(sourceURL: sourceImageURL, to: .tiff)
    assertTest(FileManager.default.fileExists(atPath: tiffURL.path), "Convert PNG -> TIFF")

    let compImageURL = try imageConverter.compress(sourceURL: sourceImageURL, quality: 0.5)
    assertTest(FileManager.default.fileExists(atPath: compImageURL.path), "Compress image")

    let grayURL = try imageConverter.convertToGrayscale(sourceURL: sourceImageURL)
    assertTest(FileManager.default.fileExists(atPath: grayURL.path), "Convert image to Grayscale")

    // 3. PDFProcessor Tests
    print("\n[3] Testing PDFProcessor (Split, Compress, Image Extraction)...")
    let pdfDoc = PDFDocument()
    for i in 1...3 {
        let pImg = NSImage(size: NSSize(width: 100, height: 100))
        pImg.lockFocus()
        (i == 1 ? NSColor.red : (i == 2 ? NSColor.green : NSColor.blue)).setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        pImg.unlockFocus()
        if let p = PDFPage(image: pImg) {
            pdfDoc.insert(p, at: pdfDoc.pageCount)
        }
    }

    let sourcePDFURL = tempDir.appendingPathComponent("sample_document.pdf")
    pdfDoc.write(to: sourcePDFURL)
    assertTest(FileManager.default.fileExists(atPath: sourcePDFURL.path), "Generated 3-page test PDF")

    let pdfProcessor = PDFProcessor()

    // Test PDF Split
    let splitPages = try pdfProcessor.split(sourceURL: sourcePDFURL)
    assertTest(splitPages.count == 3, "Split 3-page PDF into 3 files (count: \(splitPages.count))")
    for (idx, pURL) in splitPages.enumerated() {
        assertTest(FileManager.default.fileExists(atPath: pURL.path), "Split page \(idx + 1) exists: \(pURL.lastPathComponent)")
    }

    // Test PDF Compress
    let compressedPDF = try pdfProcessor.compress(sourceURL: sourcePDFURL, quality: 0.4)
    assertTest(FileManager.default.fileExists(atPath: compressedPDF.path), "Compress PDF: \(compressedPDF.lastPathComponent)")

    // Test PDF to Images (PNG)
    let extractedImages = try pdfProcessor.convertToImages(sourceURL: sourcePDFURL, targetType: .png)
    assertTest(extractedImages.count == 3, "Convert PDF pages to PNG (count: \(extractedImages.count))")

    // 4. AppVersion Tests
    print("\n[4] Testing AppVersion...")
    let v1 = AppVersion("v1.0.2")
    let v2 = AppVersion("1.0.3")
    let v3 = AppVersion("v1.1.0")
    let v4 = AppVersion("1.0.2")
    assertTest(v1 == v4, "AppVersion equality: v1.0.2 == 1.0.2")
    assertTest(v1 < v2, "AppVersion comparison: 1.0.2 < 1.0.3")
    assertTest(v2 < v3, "AppVersion comparison: 1.0.3 < 1.1.0")
    assertTest(AppVersion("v1.0.9") < AppVersion("v1.0.10"), "AppVersion comparison: 1.0.9 < 1.0.10")

    print("\n========================================")
    print("  Test Results: \(passed) Passed, \(failed) Failed")
    print("========================================")

    if failed > 0 {
        exit(1)
    }
}

try await runTests()
