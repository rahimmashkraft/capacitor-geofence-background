package com.mr.geofencebackground;

import android.util.Log;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;
import java.util.UUID;

/** Sends one check-in or check-out: the same multipart/form-data POST as the iOS plugin. */
final class CheckInSender {

    enum Outcome {
        /** The server accepted it. */
        SENT,
        /** No network, a timeout or a temporary server error: try again later. */
        RETRY,
        /** The server rejected it (for example 400 or 401); sending it again will not help. */
        DROP
    }

    // A geofence broadcast receiver has a limited time to finish, so keep each attempt short.
    private static final int TIMEOUT_MS = 10_000;

    private CheckInSender() {}

    /** Blocks until the server answers or the attempt fails. Call it off the main thread. */
    static Outcome send(CheckInRequest request) {
        String boundary = UUID.randomUUID().toString().toUpperCase(Locale.ROOT);
        byte[] body = buildBody(request, boundary);

        HttpURLConnection connection = null;
        try {
            connection = (HttpURLConnection) new URL(request.endpoint).openConnection();
            connection.setConnectTimeout(TIMEOUT_MS);
            connection.setReadTimeout(TIMEOUT_MS);
            connection.setRequestMethod("POST");
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);
            connection.setFixedLengthStreamingMode(body.length);
            try (OutputStream out = connection.getOutputStream()) {
                out.write(body);
            }

            int status = connection.getResponseCode();
            Log.d(GeofenceTracker.TAG, "Response Status Code: " + status);
            InputStream stream = status >= 400 ? connection.getErrorStream() : connection.getInputStream();
            if (stream != null) {
                Log.d(GeofenceTracker.TAG, "Response Data: " + readAll(stream));
            }
            return outcomeForStatus(status);
        } catch (MalformedURLException | IllegalArgumentException e) {
            Log.e(GeofenceTracker.TAG, "Invalid API endpoint, dropping the request: " + request.endpoint, e);
            return Outcome.DROP;
        } catch (IOException e) {
            Log.w(GeofenceTracker.TAG, "Check-in request failed, will retry: " + e);
            return Outcome.RETRY;
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    static Outcome outcomeForStatus(int status) {
        if (status >= 200 && status < 300) {
            return Outcome.SENT;
        }
        // 408 Request Timeout, 429 Too Many Requests and 5xx server errors are usually temporary.
        if (status == 408 || status == 429 || status >= 500) {
            return Outcome.RETRY;
        }
        return Outcome.DROP;
    }

    /**
     * Fields: latitude and longitude of the area's centre, aid, auth_token, checkin, plus
     * timestamp (when the transition happened) and event_id (the same for every retry).
     */
    static byte[] buildBody(CheckInRequest request, String boundary) {
        StringBuilder body = new StringBuilder();
        appendField(body, boundary, "latitude", String.valueOf(request.latitude));
        appendField(body, boundary, "longitude", String.valueOf(request.longitude));
        appendField(body, boundary, "aid", String.valueOf(request.userID));
        appendField(body, boundary, "auth_token", request.authToken);
        appendField(body, boundary, "checkin", String.valueOf(request.isCheckin));
        appendField(body, boundary, "timestamp", formatTimestamp(request.timestampMillis));
        appendField(body, boundary, "event_id", request.eventId);
        body.append("--").append(boundary).append("--\r\n");
        return body.toString().getBytes(StandardCharsets.UTF_8);
    }

    /** ISO 8601 in UTC, for example 2026-11-10T09:02:13Z. Matches the iOS plugin. */
    static String formatTimestamp(long millis) {
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.ROOT);
        format.setTimeZone(TimeZone.getTimeZone("UTC"));
        return format.format(new Date(millis));
    }

    private static void appendField(StringBuilder body, String boundary, String name, String value) {
        body.append("--").append(boundary).append("\r\n");
        body.append("Content-Disposition: form-data; name=\"").append(name).append("\"\r\n\r\n");
        body.append(value).append("\r\n");
    }

    private static String readAll(InputStream stream) throws IOException {
        StringBuilder text = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                text.append(line);
            }
        }
        return text.toString();
    }
}
