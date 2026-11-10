import Foundation
import Network
import UIKit

/// One check-in or check-out for the server. It carries its own copy of the endpoint and token, so a
/// request waiting to be retried is still sent correctly after stopTrackUser or a new startTrackUser.
struct CheckInRequest: Codable, Equatable {
    /// Sent as event_id so the server can ignore a request it already received.
    let eventID: String
    let endpoint: String
    let authToken: String
    let userID: Int
    let latitude: Double
    let longitude: Double
    let isCheckin: Bool
    /// When the user entered or left the area.
    let timestamp: Date
}

enum CheckInOutcome: Equatable {
    /// The server accepted it.
    case sent
    /// No network, a timeout or a temporary server error: try again later.
    case retry
    /// The server rejected it (for example 400 or 401); sending it again will not help.
    case drop
}

/// Sends one check-in or check-out: the same multipart/form-data POST as the Android plugin.
enum CheckInSender {

    static func send(_ request: CheckInRequest, completion: @escaping (CheckInOutcome) -> Void) {
        guard let urlRequest = makeURLRequest(request) else {
            print("Invalid API Endpoint, dropping the request: \(request.endpoint)")
            completion(.drop)
            return
        }
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(outcome(for: error))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("Response Status Code: \(status)")
            if let data = data, let text = String(data: data, encoding: .utf8) {
                print("Response Data: \(text)")
            }
            completion(outcome(forStatus: status))
        }.resume()
    }

    static func outcome(forStatus status: Int) -> CheckInOutcome {
        if (200..<300).contains(status) {
            return .sent
        }
        // 408 Request Timeout, 429 Too Many Requests and 5xx server errors are usually temporary.
        if status == 408 || status == 429 || status >= 500 {
            return .retry
        }
        return .drop
    }

    static func outcome(for error: Error) -> CheckInOutcome {
        if let urlError = error as? URLError, [.badURL, .unsupportedURL].contains(urlError.code) {
            return .drop
        }
        return .retry
    }

    /// Fields: latitude and longitude of the area's centre, aid, auth_token, checkin, plus
    /// timestamp (when the transition happened) and event_id (the same for every retry).
    static func makeURLRequest(_ request: CheckInRequest, boundary: String = UUID().uuidString) -> URLRequest? {
        guard let url = URL(string: request.endpoint), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            return nil
        }
        var urlRequest = URLRequest(url: url, timeoutInterval: 15)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fields: [(String, String)] = [
            ("latitude", "\(request.latitude)"),
            ("longitude", "\(request.longitude)"),
            ("aid", "\(request.userID)"),
            ("auth_token", request.authToken),
            ("checkin", "\(request.isCheckin)"),
            ("timestamp", formatTimestamp(request.timestamp)),
            ("event_id", request.eventID)
        ]
        var body = ""
        for (name, value) in fields {
            body += "--\(boundary)\r\n"
            body += "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n"
        }
        body += "--\(boundary)--\r\n"
        urlRequest.httpBody = body.data(using: .utf8)
        return urlRequest
    }

    /// ISO 8601 in UTC, for example 2026-11-10T09:02:13Z. Matches the Android plugin.
    static func formatTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}

/// Gets every check-in and check-out to the server, in order. Each one is sent straight away; if that
/// fails it is saved and retried, oldest first. While the app runs it retries with growing delays
/// (30 s, 1 min, 2 min, ... up to 30 min) and as soon as the network comes back. While the app is
/// suspended, iOS doesn't run it, so saved requests go out the next time the app opens or the
/// user next enters or leaves the area.
final class CheckInQueue {

    static let shared = CheckInQueue()

    /// Requests older than this are dropped instead of retried.
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60
    /// The oldest requests are dropped beyond this many.
    static let maxCount = 100

    typealias Send = (CheckInRequest, @escaping (CheckInOutcome) -> Void) -> Void
    /// Starts extra background time and returns the function that ends it.
    typealias BeginBackgroundTime = () -> () -> Void

    private let queue = DispatchQueue(label: "GeofenceBackground.CheckInQueue")
    private let defaults: UserDefaults
    private let storageKey: String
    private let send: Send
    private let now: () -> Date
    private let beginBackgroundTime: BeginBackgroundTime
    private let minRetryDelay: TimeInterval
    private let maxRetryDelay: TimeInterval

    private var pending: [CheckInRequest]
    private var isSending = false
    private var isRetryScheduled = false
    private var retryDelay: TimeInterval
    private var isStarted = false
    private var pathMonitor: NWPathMonitor?

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "PendingCheckIns",
        send: @escaping Send = CheckInSender.send,
        now: @escaping () -> Date = Date.init,
        beginBackgroundTime: @escaping BeginBackgroundTime = BackgroundTime.begin,
        minRetryDelay: TimeInterval = 30,
        maxRetryDelay: TimeInterval = 30 * 60
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.send = send
        self.now = now
        self.beginBackgroundTime = beginBackgroundTime
        self.minRetryDelay = minRetryDelay
        self.maxRetryDelay = maxRetryDelay
        self.retryDelay = minRetryDelay
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([CheckInRequest].self, from: data) {
            pending = saved
        } else {
            pending = []
        }
    }

    /// Sends anything saved from earlier, and retries when the app opens or the network comes back.
    func start() {
        queue.async { [weak self] in
            guard let self = self, !self.isStarted else { return }
            self.isStarted = true

            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil
            ) { [weak self] _ in
                self?.flush()
            }
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                if path.status == .satisfied {
                    self?.flush()
                }
            }
            monitor.start(queue: self.queue)
            self.pathMonitor = monitor

            self.flushOnQueue()
        }
    }

    /// Sends the request now, or after the saved ones ahead of it.
    func deliver(_ request: CheckInRequest) {
        queue.async {
            self.pending.append(request)
            if self.pending.count > CheckInQueue.maxCount {
                self.pending.removeFirst(self.pending.count - CheckInQueue.maxCount)
            }
            self.save()
            self.flushOnQueue()
        }
    }

    func flush() {
        queue.async { self.flushOnQueue() }
    }

    /// Requests still waiting to be sent, oldest first.
    var pendingRequests: [CheckInRequest] {
        queue.sync { pending }
    }

    /// Waits for work already handed to the queue. For tests.
    func waitForQueuedWork() {
        queue.sync {}
    }

    private func flushOnQueue() {
        guard !isSending else { return }
        dropExpired()
        guard let head = pending.first else { return }

        isSending = true
        let endBackgroundTime = beginBackgroundTime()
        send(head) { [weak self] outcome in
            guard let self = self else { return }
            self.queue.async {
                self.isSending = false
                switch outcome {
                case .sent, .drop:
                    if self.pending.first?.eventID == head.eventID {
                        self.pending.removeFirst()
                        self.save()
                    }
                    self.retryDelay = self.minRetryDelay
                    self.flushOnQueue()
                case .retry:
                    self.scheduleRetry()
                }
                endBackgroundTime()
            }
        }
    }

    private func scheduleRetry() {
        guard !isRetryScheduled else { return }
        isRetryScheduled = true
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            self.isRetryScheduled = false
            self.flushOnQueue()
        }
    }

    private func dropExpired() {
        let cutoff = now().addingTimeInterval(-CheckInQueue.maxAge)
        let kept = pending.filter { $0.timestamp >= cutoff }
        if kept.count != pending.count {
            print("Dropping \(pending.count - kept.count) check-in(s) older than 7 days")
            pending = kept
            save()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: storageKey)
        }
    }
}

/// Asks iOS for extra time (about 30 seconds) so a request can finish if the app goes to the background.
final class BackgroundTime {

    private var identifier = UIBackgroundTaskIdentifier.invalid

    static func begin() -> () -> Void {
        let time = BackgroundTime()
        DispatchQueue.main.async {
            time.identifier = UIApplication.shared.beginBackgroundTask(withName: "GeofenceBackground check-in") {
                time.end()
            }
        }
        return { DispatchQueue.main.async { time.end() } }
    }

    private func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
