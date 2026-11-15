import AppKit
import NoyaCore
import PDFKit
import UniformTypeIdentifiers
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Language features that run entirely on this Mac.
///
/// With Apple Intelligence (macOS 26 or later, on a Mac that supports it), the on-device model
/// proposes file names and writes summaries. Without it, simple rules do the same job less well.
/// Nothing is ever sent over the network.
enum LocalIntelligence {
    /// Whether Apple Intelligence can answer on this Mac right now.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Why Apple Intelligence cannot be used, or `nil` when it can.
    static var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return String(localized: "This Mac does not support Apple Intelligence.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return String(localized: "Apple Intelligence is turned off in System Settings.")
            case .unavailable(.modelNotReady):
                return String(localized: "Apple Intelligence is still getting ready on this Mac.")
            case .unavailable:
                return String(localized: "Apple Intelligence is not available right now.")
            }
        }
        #endif
        return String(localized: "Apple Intelligence needs macOS 26 or later.")
    }

    /// The language the app speaks, “fr” or “en”.
    static var languageCode: String {
        Bundle.main.preferredLocalizations.first?.hasPrefix("fr") == true ? "fr" : "en"
    }

    private static var languageName: String {
        languageCode == "fr" ? "French" : "English"
    }

    // MARK: - Names

    /// A clearer name for a file, without its extension, read from its contents.
    ///
    /// - Parameters:
    ///   - title: What the file is, such as “Facture” or “Capture”.
    ///   - example: A name to imitate, such as “Facture EDF octobre 2026”.
    static func proposedName(for url: URL, title: String, example: String) async -> String? {
        let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
        guard let text = await text(of: url, limit: 2500),
              text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4 else { return nil }

        let instructions = """
            You give files short, clear names. Answer with the name only: no extension, no quotes, \
            no explanation, at most seven words. Never invent facts that the text does not contain.
            """
        let prompt = """
            Propose a file name in \(languageName) for this \(isImage ? "screenshot" : "document"). \
            Start with “\(title)”, then say what it is about: for a document, who sent it and the month and \
            year it covers, when the text says so. Example: “\(example)”.

            Text:
            \(text)
            """
        if let answer = await respond(to: prompt, instructions: instructions) {
            let firstLine = answer.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            var name = FileNaming.sanitized(firstLine)
            let extensionSuffix = "." + url.pathExtension
            if !url.pathExtension.isEmpty, name.lowercased().hasSuffix(extensionSuffix.lowercased()) {
                name.removeLast(extensionSuffix.count)
            }
            if (3...80).contains(name.count) { return name }
        }

        if isImage {
            return FileNaming.proposedScreenshotName(fromText: text, prefix: title)
        }
        return FileNaming.proposedName(fromText: text, title: title, languageCode: languageCode)
    }

    // MARK: - Summaries

    /// A few lines that sum up a document.
    static func summary(of url: URL) async -> String? {
        guard let text = await text(of: url, limit: 6000),
              text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40 else { return nil }

        let instructions = """
            You summarize documents faithfully, for the person who owns them. Never invent facts. \
            Keep amounts, dates and names exactly as written.
            """
        let prompt = """
            Summarize this document in \(languageName), in three to five short bullet points starting with “• ”.

            \(text)
            """
        if let answer = await respond(to: prompt, instructions: instructions),
           !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return answer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let sentences = Summarizer.keySentences(in: text, count: 4)
        guard !sentences.isEmpty else { return nil }
        return sentences.map { "• " + $0 }.joined(separator: "\n")
    }

    // MARK: - Reading files

    /// The text of a PDF, a text file or a picture, up to `limit` characters.
    ///
    /// - Parameter recognizesText: Whether to read the text of pictures and scanned PDFs, which is slower.
    static func text(of url: URL, limit: Int, recognizesText: Bool = true) async -> String? {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
        if type.conforms(to: .pdf) {
            guard let document = PDFDocument(url: url) else { return nil }
            var text = ""
            for index in 0..<min(document.pageCount, 4) {
                text += (document.page(at: index)?.string ?? "") + "\n"
                if text.count >= limit { break }
            }
            // A scanned PDF has no text layer: reads its first page as a picture.
            if recognizesText, text.filter(\.isLetter).count < 20, let page = document.page(at: 0) {
                let thumbnail = page.thumbnail(of: CGSize(width: 1700, height: 2200), for: .mediaBox)
                if let image = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil),
                   let recognized = recognizeText(in: image) {
                    text = recognized
                }
            }
            return String(text.prefix(limit))
        }
        if type.conforms(to: .image) {
            guard recognizesText, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return recognizeText(in: image).map { String($0.prefix(limit)) }
        }
        if type.conforms(to: .text) {
            guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? handle.close() }
            let data = (try? handle.read(upToCount: limit * 4)) ?? Data()
            return String(String(decoding: data, as: UTF8.self).prefix(limit))
        }
        return nil
    }

    /// The lines of text Vision reads in a picture, in reading order.
    static func recognizeText(in image: CGImage) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["fr-FR", "en-US"]
        let handler = VNImageRequestHandler(cgImage: image)
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    // MARK: - Apple Intelligence

    /// Asks the on-device model, or returns `nil` when it is unavailable or fails.
    private static func respond(to prompt: String, instructions: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            let session = LanguageModelSession(instructions: instructions)
            do {
                let response = try await session.respond(to: prompt)
                return response.content
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}
