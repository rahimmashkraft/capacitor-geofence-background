package com.mr.geofencebackground;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.nio.charset.StandardCharsets;
import org.junit.Test;

public class CheckInSenderTest {

    private static final long NOV_10_2026_09_02_13_UTC = 1794301333000L;

    @Test
    public void successResponsesCountAsSent() {
        for (int status : new int[] { 200, 201, 204, 299 }) {
            assertEquals("status " + status, CheckInSender.Outcome.SENT, CheckInSender.outcomeForStatus(status));
        }
    }

    @Test
    public void temporaryFailuresAreRetried() {
        for (int status : new int[] { 408, 429, 500, 502, 503, 504 }) {
            assertEquals("status " + status, CheckInSender.Outcome.RETRY, CheckInSender.outcomeForStatus(status));
        }
    }

    @Test
    public void rejectedRequestsAreDropped() {
        for (int status : new int[] { 301, 400, 401, 403, 404, 422 }) {
            assertEquals("status " + status, CheckInSender.Outcome.DROP, CheckInSender.outcomeForStatus(status));
        }
    }

    @Test
    public void timestampIsIso8601InUtc() {
        assertEquals("2026-11-10T09:02:13Z", CheckInSender.formatTimestamp(NOV_10_2026_09_02_13_UTC));
    }

    @Test
    public void bodyHasEveryField() {
        CheckInRequest request = new CheckInRequest(
            "event-1",
            "https://example.com/attendance",
            "token-1",
            42,
            24.8607,
            67.0011,
            true,
            NOV_10_2026_09_02_13_UTC
        );
        String body = new String(CheckInSender.buildBody(request, "BOUNDARY"), StandardCharsets.UTF_8);

        assertTrue(body.startsWith("--BOUNDARY\r\n"));
        assertTrue(body.contains(field("latitude", "24.8607")));
        assertTrue(body.contains(field("longitude", "67.0011")));
        assertTrue(body.contains(field("aid", "42")));
        assertTrue(body.contains(field("auth_token", "token-1")));
        assertTrue(body.contains(field("checkin", "true")));
        assertTrue(body.contains(field("timestamp", "2026-11-10T09:02:13Z")));
        assertTrue(body.contains(field("event_id", "event-1")));
        assertTrue(body.endsWith("--BOUNDARY--\r\n"));
    }

    private static String field(String name, String value) {
        return "Content-Disposition: form-data; name=\"" + name + "\"\r\n\r\n" + value + "\r\n";
    }
}
