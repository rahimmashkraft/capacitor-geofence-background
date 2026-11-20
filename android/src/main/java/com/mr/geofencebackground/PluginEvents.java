package com.mr.geofencebackground;

import androidx.annotation.Nullable;
import com.getcapacitor.JSObject;

/**
 * Passes geofence and request events to JavaScript. The receiver and the retry worker can run
 * without the app's web view (for example after the app was closed), so events are only delivered
 * while a plugin instance is loaded; otherwise they are skipped.
 */
final class PluginEvents {

    static final String GEOFENCE_EVENT = "geofenceEvent";
    static final String REQUEST_RESULT = "requestResult";

    static final String SENT = "sent";
    static final String QUEUED = "queued";
    static final String REJECTED = "rejected";
    static final String DROPPED = "dropped";

    @Nullable
    private static volatile GeofenceBackgroundPlugin plugin;

    private PluginEvents() {}

    static void attach(GeofenceBackgroundPlugin instance) {
        plugin = instance;
    }

    static void detach(GeofenceBackgroundPlugin instance) {
        if (plugin == instance) {
            plugin = null;
        }
    }

    static void transition(CheckInRequest request) {
        emit(GEOFENCE_EVENT, eventData(request));
    }

    static void result(CheckInRequest request, String status) {
        JSObject data = eventData(request);
        data.put("status", status);
        emit(REQUEST_RESULT, data);
    }

    static JSObject eventData(CheckInRequest request) {
        JSObject data = new JSObject();
        data.put("eventId", request.eventId);
        data.put("transition", request.isCheckin ? "enter" : "exit");
        data.put("timestamp", CheckInSender.formatTimestamp(request.timestampMillis));
        data.put("latitude", request.latitude);
        data.put("longitude", request.longitude);
        return data;
    }

    private static void emit(String eventName, JSObject data) {
        GeofenceBackgroundPlugin instance = plugin;
        if (instance != null) {
            instance.emit(eventName, data);
        }
    }
}
