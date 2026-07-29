//
//  MaterialImporter.swift
//  Scholar
//
//  Reads whatever the user hands over and turns it into a StudyMaterial.
//  Text extraction is local: PDFKit for documents, Vision for photographed
//  notes and slides. Nothing is uploaded anywhere.
//

import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers
@preconcurrency import Vision

nonisolated enum ImportError: LocalizedError {
    case unreadable
    case unsupported(String)
    case noText
    case tooShort

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "That file couldn't be opened."
        case .unsupported(let ext):
            return "\(ext.uppercased()) files aren't supported yet. Try a PDF, a photo, or plain text."
        case .noText:
            return "No readable text was found. If it's a scan, try a sharper photo."
        case .tooShort:
            return "There isn't enough text here to build a feed from. Add more detail."
        }
    }
}

nonisolated enum MaterialImporter {

    /// Everything the file picker should accept.
    static let readableTypes: [UTType] = [.pdf, .plainText, .text, .rtf, .image, .png, .jpeg, .utf8PlainText]

    // MARK: - Entry points

    static func material(fromFileAt url: URL) async throws -> StudyMaterial {
        // Files handed over by the picker live outside the sandbox.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let type = UTType(filenameExtension: url.pathExtension.lowercased())
        let fallbackTitle = url.deletingPathExtension().lastPathComponent

        if type?.conforms(to: .pdf) == true || url.pathExtension.lowercased() == "pdf" {
            let text = try pdfText(at: url)
            return try build(text: text, kind: .pdf, fallbackTitle: fallbackTitle)
        }
        if type?.conforms(to: .image) == true {
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
                throw ImportError.unreadable
            }
            let text = try await recognizeText(in: image)
            return try build(text: text, kind: .image, fallbackTitle: fallbackTitle)
        }
        if type?.conforms(to: .rtf) == true {
            let text = try richText(at: url)
            return try build(text: text, kind: .text, fallbackTitle: fallbackTitle)
        }
        if type?.conforms(to: .text) == true || type?.conforms(to: .plainText) == true {
            let text = (try? String(contentsOf: url, encoding: .utf8))
                ?? (try? String(contentsOf: url, encoding: .isoLatin1))
            guard let text else { throw ImportError.unreadable }
            return try build(text: text, kind: .text, fallbackTitle: fallbackTitle)
        }
        throw ImportError.unsupported(url.pathExtension.isEmpty ? "that" : url.pathExtension)
    }

    static func material(fromImageData data: Data) async throws -> StudyMaterial {
        guard let image = UIImage(data: data) else { throw ImportError.unreadable }
        let text = try await recognizeText(in: image)
        return try build(text: text, kind: .image, fallbackTitle: "Scanned notes")
    }

    static func material(fromTypedText text: String) throws -> StudyMaterial {
        try build(text: text, kind: .text, fallbackTitle: "My notes")
    }

    // MARK: - Extraction

    private static func pdfText(at url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else { throw ImportError.unreadable }

        var collected = ""
        // 40 pages is far more than the keyword extractor needs and keeps a
        // 500-page textbook from stalling the import.
        for index in 0..<min(document.pageCount, 40) {
            guard let page = document.page(at: index), let text = page.string else { continue }
            collected += text + "\n"
            if collected.count > 60_000 { break }
        }
        guard collected.trimmingCharacters(in: .whitespacesAndNewlines).count > 40 else {
            throw ImportError.noText
        }
        return collected
    }

    private static func richText(at url: URL) throws -> String {
        guard let data = try? Data(contentsOf: url),
              let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil)
        else { throw ImportError.unreadable }
        return attributed.string
    }

    /// Vision's accurate path with language correction — good enough for
    /// photographed lecture slides and reasonably tidy handwriting.
    ///
    /// The whole request is built and performed inside one detached task so
    /// the non-Sendable Vision types never cross a concurrency boundary.
    private static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw ImportError.unreadable }
        let orientation = image.cgOrientation

        return try await Task.detached(priority: .userInitiated) { () throws -> String in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])

            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")

            guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 else {
                throw ImportError.noText
            }
            return text
        }.value
    }

    // MARK: - Assembly

    /// Recomputes a stored material's topics with the current extractor.
    /// Keywords live alongside the document, so improving extraction would
    /// otherwise leave everything imported earlier stuck with weaker topics.
    static func rederived(_ material: StudyMaterial) -> StudyMaterial {
        guard material.needsRederive,
              let refreshed = try? build(text: material.excerpt,
                                         kind: material.kind,
                                         fallbackTitle: material.title)
        else { return material }

        var updated = material
        updated.title = refreshed.title
        updated.keywords = refreshed.keywords
        updated.interestIDs = refreshed.interestIDs
        updated.searchQueries = refreshed.searchQueries
        updated.extractorVersion = KeywordExtractor.version
        return updated
    }

    private static func build(text: String, kind: MaterialKind,
                              fallbackTitle: String) throws -> StudyMaterial {
        let cleaned = text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let words = cleaned.split { $0.isWhitespace }.count
        guard words >= 12 else { throw ImportError.tooShort }

        let keywords = KeywordExtractor.keywords(from: cleaned)
        guard !keywords.isEmpty else { throw ImportError.tooShort }

        let title = KeywordExtractor.inferTitle(from: cleaned, fallback: fallbackTitle)
        let interests = KeywordExtractor.matchingInterests(for: keywords, in: cleaned)

        // The document's own title is its single most reliable descriptor, so
        // it always leads the keyword list even if the extractor ranked the
        // individual words lower.
        var finalKeywords = keywords
        let titleTerm = title.lowercased()
        if titleTerm.split(separator: " ").count >= 2,
           !finalKeywords.contains(where: { $0.term == titleTerm }) {
            finalKeywords.insert(Keyword(term: titleTerm, weight: 1), at: 0)
        }

        return StudyMaterial(
            title: title,
            kind: kind,
            excerpt: String(cleaned.prefix(12_000)),
            keywords: finalKeywords,
            interestIDs: interests.map(\.id),
            searchQueries: KeywordExtractor.searchQueries(from: keywords, title: title),
            wordCount: words
        )
    }
}

private extension UIImage {
    nonisolated var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
