import Foundation
import Observation
import UniformTypeIdentifiers
import WebKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum DownloadState: String, Codable, Sendable {
    case queued
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

struct DownloadItem: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var fileName: String
    var sourceURL: URL?
    var destinationURL: URL?
    var progress: Double
    var state: DownloadState
    var errorMessage: String?
    var updatedAt: Date
    var bytesWritten: Int64
    var totalBytes: Int64

    init(
        id: UUID = UUID(),
        fileName: String,
        sourceURL: URL? = nil,
        destinationURL: URL? = nil,
        progress: Double = 0,
        state: DownloadState = .queued,
        errorMessage: String? = nil,
        updatedAt: Date = .now,
        bytesWritten: Int64 = 0,
        totalBytes: Int64 = 0
    ) {
        self.id = id
        self.fileName = fileName
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.progress = progress
        self.state = state
        self.errorMessage = errorMessage
        self.updatedAt = updatedAt
        self.bytesWritten = bytesWritten
        self.totalBytes = totalBytes
    }
}

@Observable
@MainActor
final class DownloadManager: NSObject {
    private(set) var items: [DownloadItem] = []
    private var activeTasks: [UUID: URLSessionDownloadTask] = [:]
    private var resumeData: [UUID: Data] = [:]
    private var cookieStores: [UUID: WKHTTPCookieStore] = [:]
    private var session: URLSession!

    private let destinationBookmarkKey = "oriel.downloadDestinationBookmark"
    private let historyFileName = "download-history.json"
    private let maxHistoryItems = 80
    private let maxConcurrent = 3

    /// Custom destination folder (security-scoped bookmark). Falls back to system Downloads/Documents.
    private(set) var destinationFolderURL: URL?

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        config.timeoutIntervalForResource = 60 * 60 * 6
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        restoreDestinationBookmark()
        restoreHistory()
    }

    var hasActiveDownloads: Bool {
        items.contains { $0.state == .downloading || $0.state == .queued }
    }

    var destinationDisplayName: String {
        destinationFolderURL?.lastPathComponent ?? defaultDestinationDirectory().lastPathComponent
    }

    func enqueue(url: URL, suggestedFileName: String?, cookieStore: WKHTTPCookieStore? = nil) {
        let name = suggestedFileName?.isEmpty == false
            ? suggestedFileName!
            : (url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent)
        let item = DownloadItem(fileName: name, sourceURL: url, progress: 0, state: .queued)
        items.insert(item, at: 0)
        if let cookieStore {
            cookieStores[item.id] = cookieStore
        }
        persistHistory()
        pumpQueue()
    }

    func pause(_ id: UUID) {
        guard let task = activeTasks[id] else { return }
        task.cancel { [weak self] data in
            Task { @MainActor in
                guard let self else { return }
                self.activeTasks[id] = nil
                if let data {
                    self.resumeData[id] = data
                }
                self.update(id) { item in
                    item.state = .paused
                    item.updatedAt = .now
                }
                self.pumpQueue()
            }
        }
    }

    func resume(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }),
              item.state == .paused || item.state == .failed || item.state == .cancelled else { return }
        update(id) { item in
            item.state = .queued
            item.errorMessage = nil
            item.updatedAt = .now
        }
        pumpQueue()
    }

    func cancel(_ id: UUID) {
        activeTasks[id]?.cancel()
        activeTasks[id] = nil
        resumeData[id] = nil
        cookieStores[id] = nil
        update(id) { item in
            item.state = .cancelled
            item.errorMessage = "Cancelled"
            item.updatedAt = .now
        }
        pumpQueue()
    }

    func retry(_ id: UUID) {
        resumeData[id] = nil
        update(id) { item in
            item.state = .queued
            item.progress = 0
            item.bytesWritten = 0
            item.totalBytes = 0
            item.errorMessage = nil
            item.updatedAt = .now
        }
        pumpQueue()
    }

    func remove(_ id: UUID) {
        cancel(id)
        items.removeAll { $0.id == id }
        persistHistory()
    }

    func clearCompleted() {
        items.removeAll { $0.state == .completed || $0.state == .cancelled }
        persistHistory()
    }

    func clearAll() {
        for item in items where item.state == .downloading || item.state == .queued || item.state == .paused {
            cancel(item.id)
        }
        items.removeAll()
        persistHistory()
    }

    func setDestinationFolder(_ url: URL?) {
        guard let url else {
            destinationFolderURL = nil
            UserDefaults.standard.removeObject(forKey: destinationBookmarkKey)
            return
        }
        destinationFolderURL = url
        do {
            let data = try url.bookmarkData(
                options: bookmarkCreationOptions,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: destinationBookmarkKey)
        } catch {
            // Keep in-memory path even if bookmark persistence fails.
        }
    }

    private var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if os(macOS)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    private var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if os(macOS)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    private func pumpQueue() {
        let activeCount = items.filter { $0.state == .downloading }.count
        let slots = max(0, maxConcurrent - activeCount)
        guard slots > 0 else { return }
        let queued = items.filter { $0.state == .queued }.prefix(slots)
        for item in queued {
            start(itemID: item.id)
        }
    }

    private func start(itemID: UUID) {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        update(itemID) { item in
            item.state = .downloading
            item.updatedAt = .now
        }

        Task { @MainActor in
            await Self.copyWebKitCookies(from: cookieStores[itemID], into: HTTPCookieStorage.shared)
            guard items.contains(where: { $0.id == itemID && $0.state == .downloading }) else { return }

            let task: URLSessionDownloadTask
            if let data = resumeData[itemID] {
                task = session.downloadTask(withResumeData: data)
            } else if let source = item.sourceURL {
                task = session.downloadTask(with: source)
            } else {
                update(itemID) { item in
                    item.state = .failed
                    item.errorMessage = "Missing download URL."
                    item.updatedAt = .now
                }
                return
            }
            activeTasks[itemID] = task
            task.taskDescription = itemID.uuidString
            task.resume()
        }
    }

    private static func copyWebKitCookies(from cookieStore: WKHTTPCookieStore?, into storage: HTTPCookieStorage) async {
        let store = cookieStore ?? WKWebsiteDataStore.default().httpCookieStore
        let cookies: [HTTPCookie] = await withCheckedContinuation { continuation in
            store.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
        for cookie in cookies {
            storage.setCookie(cookie)
        }
    }

    private func update(_ id: UUID, mutate: (inout DownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items[index]
        mutate(&item)
        items[index] = item
        if item.state == .completed || item.state == .failed || item.state == .cancelled || item.state == .paused {
            persistHistory()
        }
    }

    private func persistHistory() {
        // Keep finished / paused rows so Downloads survives relaunch; drop in-flight jobs.
        let durable = items
            .filter { $0.state != .downloading && $0.state != .queued }
            .prefix(maxHistoryItems)
        try? JSONFileStore.save(Array(durable), to: historyFileName, prettyPrinted: false)
    }

    private func restoreHistory() {
        guard let loaded = try? JSONFileStore.load([DownloadItem].self, from: historyFileName) else { return }
            items = Array(
                loaded
                    .map { item -> DownloadItem in
                        var copy = item
                        // Never restore as actively downloading — user can Retry.
                        if copy.state == .downloading || copy.state == .queued {
                            copy.state = .paused
                            copy.errorMessage = copy.errorMessage ?? "Interrupted"
                        }
                        return copy
                    }
                    .prefix(maxHistoryItems)
            )
    }

    private func defaultDestinationDirectory() -> URL {
        #if os(iOS)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #else
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #endif
    }

    private func resolvedDestinationDirectory() -> URL {
        if let destinationFolderURL {
            _ = destinationFolderURL.startAccessingSecurityScopedResource()
            return destinationFolderURL
        }
        return defaultDestinationDirectory()
    }

    private func moveToDestination(from tempURL: URL, preferredName: String?) throws -> URL {
        let downloads = resolvedDestinationDirectory()
        let baseName = preferredName?.isEmpty == false ? preferredName! : tempURL.lastPathComponent
        var destination = downloads.appendingPathComponent(baseName)
        var counter = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            let stem = (baseName as NSString).deletingPathExtension
            let ext = (baseName as NSString).pathExtension
            let suffix = ext.isEmpty ? "\(stem)-\(counter)" : "\(stem)-\(counter).\(ext)"
            destination = downloads.appendingPathComponent(suffix)
            counter += 1
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    private func restoreDestinationBookmark() {
        guard let data = UserDefaults.standard.data(forKey: destinationBookmarkKey) else { return }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: bookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            _ = url.startAccessingSecurityScopedResource()
            destinationFolderURL = url
            if isStale {
                setDestinationFolder(url)
            }
        } catch {
            destinationFolderURL = nil
        }
    }

    private func itemID(for task: URLSessionTask) -> UUID? {
        guard let raw = task.taskDescription else { return nil }
        return UUID(uuidString: raw)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            guard let id = itemID(for: downloadTask) else { return }
            let progress: Double
            if totalBytesExpectedToWrite > 0 {
                progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            } else {
                progress = items.first(where: { $0.id == id })?.progress ?? 0
            }
            update(id) { item in
                item.progress = min(max(progress, 0), 0.99)
                item.bytesWritten = totalBytesWritten
                item.totalBytes = max(totalBytesExpectedToWrite, 0)
                item.updatedAt = .now
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let tempCopy: URL
        do {
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(location.pathExtension)
            try FileManager.default.copyItem(at: location, to: copy)
            tempCopy = copy
        } catch {
            Task { @MainActor in
                guard let id = itemID(for: downloadTask) else { return }
                activeTasks[id] = nil
                update(id) { item in
                    item.state = .failed
                    item.errorMessage = error.localizedDescription
                    item.updatedAt = .now
                }
                pumpQueue()
            }
            return
        }

        Task { @MainActor in
            guard let id = itemID(for: downloadTask) else { return }
            activeTasks[id] = nil
            resumeData[id] = nil
            do {
                let preferred = items.first(where: { $0.id == id })?.fileName
                    ?? downloadTask.response?.suggestedFilename
                    ?? items.first(where: { $0.id == id })?.sourceURL?.lastPathComponent
                    ?? "download"
                let destination = try moveToDestination(from: tempCopy, preferredName: preferred)
                cookieStores[id] = nil
                update(id) { item in
                    item.state = .completed
                    item.progress = 1
                    item.destinationURL = destination
                    item.fileName = destination.lastPathComponent
                    item.errorMessage = nil
                    item.updatedAt = .now
                }
            } catch {
                update(id) { item in
                    item.state = .failed
                    item.errorMessage = error.localizedDescription
                    item.updatedAt = .now
                }
            }
            pumpQueue()
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        Task { @MainActor in
            guard let id = itemID(for: task) else { return }
            activeTasks[id] = nil
            if let data = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                resumeData[id] = data
            }
            update(id) { item in
                item.state = .failed
                item.errorMessage = error.localizedDescription
                item.updatedAt = .now
            }
            pumpQueue()
        }
    }
}
