package com.mr.geofencebackground;

import androidx.annotation.Nullable;
import androidx.work.Data;
import java.util.UUID;

/**
 * One check-in or check-out for the server. It carries its own copy of the endpoint and token, so
 * a request waiting to be retried is still sent correctly after stopTrackUser or a new
 * startTrackUser.
 */
final class CheckInRequest {

    private static final String KEY_EVENT_ID = "eventId";
    private static final String KEY_ENDPOINT = "endpoint";
    private static final String KEY_AUTH_TOKEN = "authToken";
    private static final String KEY_USER_ID = "userID";
    private static final String KEY_LATITUDE = "latitude";
    private static final String KEY_LONGITUDE = "longitude";
    private static final String KEY_CHECKIN = "checkin";
    private static final String KEY_TIMESTAMP = "timestamp";

    /** Sent as event_id so the server can ignore a request it already received. */
    final String eventId;
    final String endpoint;
    final String authToken;
    final long userID;
    final double latitude;
    final double longitude;
    final boolean isCheckin;
    /** When the user entered or left the area, in milliseconds since 1970. */
    final long timestampMillis;

    CheckInRequest(
        String eventId,
        String endpoint,
        String authToken,
        long userID,
        double latitude,
        double longitude,
        boolean isCheckin,
        long timestampMillis
    ) {
        this.eventId = eventId;
        this.endpoint = endpoint;
        this.authToken = authToken;
        this.userID = userID;
        this.latitude = latitude;
        this.longitude = longitude;
        this.isCheckin = isCheckin;
        this.timestampMillis = timestampMillis;
    }

    /** A new request for a transition that is happening now. */
    static CheckInRequest create(TrackingConfig config, boolean isCheckin) {
        return new CheckInRequest(
            UUID.randomUUID().toString(),
            config.apiEndPoint,
            config.authToken,
            config.userID,
            config.latitude,
            config.longitude,
            isCheckin,
            System.currentTimeMillis()
        );
    }

    Data toData() {
        return new Data.Builder()
            .putString(KEY_EVENT_ID, eventId)
            .putString(KEY_ENDPOINT, endpoint)
            .putString(KEY_AUTH_TOKEN, authToken)
            .putLong(KEY_USER_ID, userID)
            .putDouble(KEY_LATITUDE, latitude)
            .putDouble(KEY_LONGITUDE, longitude)
            .putBoolean(KEY_CHECKIN, isCheckin)
            .putLong(KEY_TIMESTAMP, timestampMillis)
            .build();
    }

    @Nullable
    static CheckInRequest fromData(Data data) {
        String eventId = data.getString(KEY_EVENT_ID);
        String endpoint = data.getString(KEY_ENDPOINT);
        if (eventId == null || endpoint == null) {
            return null;
        }
        String authToken = data.getString(KEY_AUTH_TOKEN);
        return new CheckInRequest(
            eventId,
            endpoint,
            authToken == null ? "" : authToken,
            data.getLong(KEY_USER_ID, 0),
            data.getDouble(KEY_LATITUDE, 0),
            data.getDouble(KEY_LONGITUDE, 0),
            data.getBoolean(KEY_CHECKIN, false),
            data.getLong(KEY_TIMESTAMP, 0)
        );
    }
}
