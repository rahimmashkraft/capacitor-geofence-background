import XCTest
@testable import GeofenceBackgroundPlugin

/// Stands in for the server: records each request and lets the test decide how it ends.
private final class FakeServer {
    private let lock = NSLock()
    private var calls: [(request: CheckInRequest, complete: (CheckInOutcome) -> Void)] = []
    var onSend: ((Int) -> Void)?

    func send(_ request: CheckInRequest, _ complete: @escaping (CheckInOutcome) -> Void) {
        lock.lock()
        calls.append((request, complete))
        let count = calls.count
        let onSend = self.onSend
        lock.unlock()
        onSend?(count)
    }

    var sentIDs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return calls.map { $0.request.eventID }
    }

    func answer(_ index: Int, _ outcome: CheckInOutcome) {
        lock.lock()
        let complete = calls[index].complete
        lock.unlock()
        complete(outcome)
    }
}

final class CheckInQueueTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "CheckInQueueTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeQueue(_ server: FakeServer) -> CheckInQueue {
        CheckInQueue(
            defaults: defaults,
            storageKey: "pending",
            send: server.send,
            beginBackgroundTime: { {} },
            minRetryDelay: 0.05,
            maxRetryDelay: 0.2
        )
    }

    private func request(_ id: String, at date: Date = Date()) -> CheckInRequest {
        CheckInRequest(
            eventID: id, endpoint: "https://example.com/attendance", authToken: "token", userID: 42,
            latitude: 24.8607, longitude: 67.0011, isCheckin: true, timestamp: date
        )
    }

    func testSendsStraightAwayAndForgetsAcceptedRequest() {
        let server = FakeServer()
        let queue = makeQueue(server)

        queue.deliver(request("a"))
        queue.waitForQueuedWork()
        XCTAssertEqual(server.sentIDs, ["a"])

        server.answer(0, .sent)
        queue.waitForQueuedWork()
        XCTAssertTrue(queue.pendingRequests.isEmpty)
    }

    func testRetriesInOrderUntilAccepted() {
        let server = FakeServer()
        let queue = makeQueue(server)

        queue.deliver(request("check-in"))
        queue.deliver(request("check-out"))
        queue.waitForQueuedWork()
        // The check-out waits behind the check-in.
        XCTAssertEqual(server.sentIDs, ["check-in"])

        let retried = expectation(description: "check-in sent again")
        server.onSend = { count in if count == 2 { retried.fulfill() } }
        server.answer(0, .retry)
        wait(for: [retried], timeout: 2)
        server.onSend = nil
        XCTAssertEqual(server.sentIDs, ["check-in", "check-in"])
        XCTAssertEqual(queue.pendingRequests.map(\.eventID), ["check-in", "check-out"])

        server.answer(1, .sent)
        queue.waitForQueuedWork()
        XCTAssertEqual(server.sentIDs, ["check-in", "check-in", "check-out"])

        server.answer(2, .sent)
        queue.waitForQueuedWork()
        XCTAssertTrue(queue.pendingRequests.isEmpty)
    }

    func testRejectedRequestIsDroppedAndTheNextOneSent() {
        let server = FakeServer()
        let queue = makeQueue(server)

        queue.deliver(request("rejected"))
        queue.deliver(request("next"))
        queue.waitForQueuedWork()
        server.answer(0, .drop)
        queue.waitForQueuedWork()

        XCTAssertEqual(server.sentIDs, ["rejected", "next"])
        XCTAssertEqual(queue.pendingRequests.map(\.eventID), ["next"])
    }

    func testSavedRequestsSurviveARestart() {
        let firstServer = FakeServer()
        let firstQueue = makeQueue(firstServer)
        firstQueue.deliver(request("saved"))
        firstQueue.waitForQueuedWork()
        // The app is killed before the server answers.

        let secondServer = FakeServer()
        let secondQueue = makeQueue(secondServer)
        XCTAssertEqual(secondQueue.pendingRequests.map(\.eventID), ["saved"])

        secondQueue.flush()
        secondQueue.waitForQueuedWork()
        XCTAssertEqual(secondServer.sentIDs, ["saved"])
    }

    func testRequestsOlderThanSevenDaysAreDropped() {
        let server = FakeServer()
        let queue = makeQueue(server)

        queue.deliver(request("old", at: Date(timeIntervalSinceNow: -8 * 24 * 60 * 60)))
        queue.deliver(request("recent"))
        queue.waitForQueuedWork()

        XCTAssertEqual(server.sentIDs, ["recent"])
        XCTAssertEqual(queue.pendingRequests.map(\.eventID), ["recent"])
    }

    func testOutcomeForStatusCodes() {
        for status in [200, 201, 204, 299] {
            XCTAssertEqual(CheckInSender.outcome(forStatus: status), .sent, "status \(status)")
        }
        for status in [408, 429, 500, 502, 503, 504] {
            XCTAssertEqual(CheckInSender.outcome(forStatus: status), .retry, "status \(status)")
        }
        for status in [301, 400, 401, 403, 404, 422] {
            XCTAssertEqual(CheckInSender.outcome(forStatus: status), .drop, "status \(status)")
        }
    }

    func testOutcomeForNetworkErrors() {
        XCTAssertEqual(CheckInSender.outcome(for: URLError(.notConnectedToInternet)), .retry)
        XCTAssertEqual(CheckInSender.outcome(for: URLError(.timedOut)), .retry)
        XCTAssertEqual(CheckInSender.outcome(for: URLError(.networkConnectionLost)), .retry)
        XCTAssertEqual(CheckInSender.outcome(for: URLError(.badURL)), .drop)
    }

    func testRequestBodyHasEveryField() throws {
        let check = CheckInRequest(
            eventID: "event-1", endpoint: "https://example.com/attendance", authToken: "token-1", userID: 42,
            latitude: 24.8607, longitude: 67.0011, isCheckin: true,
            timestamp: Date(timeIntervalSince1970: 1_794_301_333)
        )
        let urlRequest = try XCTUnwrap(CheckInSender.makeURLRequest(check, boundary: "BOUNDARY"))
        let body = try XCTUnwrap(urlRequest.httpBody.flatMap { String(data: $0, encoding: .utf8) })

        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "multipart/form-data; boundary=BOUNDARY")
        let fields = [
            ("latitude", "24.8607"), ("longitude", "67.0011"), ("aid", "42"), ("auth_token", "token-1"),
            ("checkin", "true"), ("timestamp", "2026-11-10T09:02:13Z"), ("event_id", "event-1")
        ]
        for (name, value) in fields {
            XCTAssertTrue(body.contains("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n"), name)
        }
        XCTAssertTrue(body.hasSuffix("--BOUNDARY--\r\n"))
    }

    func testInvalidEndpointGivesNoRequest() {
        for endpoint in ["not a url", "ftp://example.com/attendance", ""] {
            let check = CheckInRequest(
                eventID: "x", endpoint: endpoint, authToken: "", userID: 1,
                latitude: 0, longitude: 0, isCheckin: false, timestamp: Date()
            )
            XCTAssertNil(CheckInSender.makeURLRequest(check), endpoint)
        }
    }
}
