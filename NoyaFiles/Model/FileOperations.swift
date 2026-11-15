import Foundation
import NoyaCore
import Observation

enum TransferKind: Sendable {
    case copy
    case move
}

/// A copy or move in progress, shown in the corner of the window.
struct FileOperation: Identifiable, Equatable {
    let id = UUID()
    let kind: TransferKind
    let destinationName: String
    let totalCount: Int
    var completedCount = 0
    var currentName: String

    var fraction: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }
}

/// Copies and moves files in the background, one item at a time, so they can be cancelled.
@MainActor
@Observable
final class FileOperationCenter {
    private(set) var current: FileOperation?
    var lastError: String?

    @ObservationIgnored private var task: Task<Void, Never>?

    /// Copies or moves items into a folder. Items that would overwrite something get a new name.
    ///
    /// - Parameter completion: Called on the main actor with the URLs of the new items.
    func transfer(
        _ kind: TransferKind,
        _ urls: [URL],
        to folder: URL,
        completion: @escaping @MainActor @Sendable ([URL]) -> Void = { _ in }
    ) {
        let sources = urls.filter { $0.deletingLastPathComponent().standardizedFileURL != folder.standardizedFileURL || kind == .copy }
        guard !sources.isEmpty, current == nil else { return }

        current = FileOperation(
            kind: kind,
            destinationName: FileManager.default.displayName(atPath: folder.path),
            totalCount: sources.count,
            currentName: sources[0].lastPathComponent
        )

        task = Task { [weak self] in
            var created: [URL] = []
            var failures: [String] = []
            for (index, source) in sources.enumerated() {
                if Task.isCancelled { break }
                self?.current?.currentName = source.lastPathComponent
                let result = await Self.perform(kind, source, into: folder)
                switch result {
                case .success(let url): created.append(url)
                case .failure: failures.append(source.lastPathComponent)
                }
                self?.current?.completedCount = index + 1
            }
            guard let self else { return }
            self.current = nil
            if !failures.isEmpty {
                let names = failures.joined(separator: ", ")
                self.lastError = String(localized: "These items could not be copied or moved: \(names)")
            }
            completion(created)
        }
    }

    func cancel() {
        task?.cancel()
    }

    nonisolated private static func perform(_ kind: TransferKind, _ source: URL, into folder: URL) async -> Result<URL, any Error> {
        let destination = uniqueDestination(for: source.lastPathComponent, in: folder)
        do {
            switch kind {
            case .copy: try FileManager.default.copyItem(at: source, to: destination)
            case .move: try FileManager.default.moveItem(at: source, to: destination)
            }
            return .success(destination)
        } catch {
            return .failure(error)
        }
    }

    /// A URL in `folder` for `name` that does not exist yet, such as `Facture 2.pdf`.
    nonisolated static func uniqueDestination(for name: String, in folder: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = folder.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let fileExtension = FileCategory.pathExtension(of: name)
        let base = fileExtension.isEmpty ? name : String(name.dropLast(fileExtension.count + 1))
        let suffix = fileExtension.isEmpty ? "" : "." + (name as NSString).pathExtension
        var number = 2
        repeat {
            candidate = folder.appendingPathComponent("\(base) \(number)\(suffix)")
            number += 1
        } while fileManager.fileExists(atPath: candidate.path)
        return candidate
    }
}
