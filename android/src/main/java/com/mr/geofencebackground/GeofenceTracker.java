package com.mr.geofencebackground;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.Task;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.Locale;
import java.util.UUID;

/** Adds and removes the geofence, and sends the check-in/check-out request. Mirrors ContinuesLocationManager on iOS. */
final class GeofenceTracker {

    static final String TAG = "GeofenceBackground";
    /** Same identifier as the iOS region. */
    static final String REGION_ID = "dynamicRegion";

    // A geofence broadcast receiver has a limited time to finish, so keep the request short.
    private static final int TIMEOUT_MS = 10_000;

    private GeofenceTracker() {}

    /** Precise location, plus "Allow all the time" on Android 10 and later. Geofences need both. */
    static boolean hasLocationPermissions(Context context) {
        if (!isGranted(context, Manifest.permission.ACCESS_FINE_LOCATION)) {
            return false;
        }
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || isGranted(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION);
    }

    static boolean isGranted(Context context, String permission) {
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED;
    }

    /** Adds the geofence, replacing any earlier one. Callers must check hasLocationPermissions first. */
    @SuppressLint("MissingPermission")
    static Task<Void> addGeofence(Context context, TrackingConfig config) {
        Geofence geofence = new Geofence.Builder()
            .setRequestId(REGION_ID)
            .setCircularRegion(config.latitude, config.longitude, (float) config.radius)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER | Geofence.GEOFENCE_TRANSITION_EXIT)
            .build();

        GeofencingRequest request = new GeofencingRequest.Builder()
            // Like iOS region monitoring: report boundary crossings only, not "already inside"
            // at the moment tracking starts.
            .setInitialTrigger(0)
            .addGeofence(geofence)
            .build();

        return LocationServices.getGeofencingClient(context.getApplicationContext()).addGeofences(request, pendingIntent(context));
    }

    static Task<Void> removeGeofence(Context context) {
        return LocationServices.getGeofencingClient(context.getApplicationContext()).removeGeofences(Collections.singletonList(REGION_ID));
    }

    /**
     * Adds the saved geofence again. Android removes geofences on reboot and when location is
     * switched off, while iOS keeps its regions. Returns null when there is nothing to restore.
     */
    @Nullable
    static Task<Void> restoreGeofence(Context context) {
        TrackingConfig config = TrackingConfig.load(context);
        if (config == null || !hasLocationPermissions(context)) {
            return null;
        }
        try {
            return addGeofence(context, config).addOnFailureListener(e -> Log.e(TAG, "Could not restore geofence", e));
        } catch (RuntimeException e) {
            Log.e(TAG, "Could not restore geofence", e);
            return null;
        }
    }

    private static PendingIntent pendingIntent(Context context) {
        Intent intent = new Intent(context.getApplicationContext(), GeofenceBroadcastReceiver.class);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Play services adds the geofence event to this intent, so it must be mutable.
            flags |= PendingIntent.FLAG_MUTABLE;
        }
        return PendingIntent.getBroadcast(context.getApplicationContext(), 0, intent, flags);
    }

    /**
     * Sends the same multipart/form-data POST as the iOS plugin: latitude and longitude of the
     * geofence centre, aid, auth_token and checkin. Blocks, so call it off the main thread.
     */
    static void sendCheckIn(TrackingConfig config, boolean isCheckin) {
        String boundary = UUID.randomUUID().toString().toUpperCase(Locale.ROOT);
        StringBuilder body = new StringBuilder();
        appendField(body, boundary, "latitude", String.valueOf(config.latitude));
        appendField(body, boundary, "longitude", String.valueOf(config.longitude));
        appendField(body, boundary, "aid", String.valueOf(config.userID));
        appendField(body, boundary, "auth_token", config.authToken);
        appendField(body, boundary, "checkin", String.valueOf(isCheckin));
        body.append("--").append(boundary).append("--\r\n");
        byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);

        HttpURLConnection connection = null;
        try {
            connection = (HttpURLConnection) new URL(config.apiEndPoint).openConnection();
            connection.setConnectTimeout(TIMEOUT_MS);
            connection.setReadTimeout(TIMEOUT_MS);
            connection.setRequestMethod("POST");
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);
            connection.setFixedLengthStreamingMode(bytes.length);
            try (OutputStream out = connection.getOutputStream()) {
                out.write(bytes);
            }

            int status = connection.getResponseCode();
            Log.d(TAG, "Response Status Code: " + status);
            InputStream stream = status >= 400 ? connection.getErrorStream() : connection.getInputStream();
            if (stream != null) {
                Log.d(TAG, "Response Data: " + readAll(stream));
            }
        } catch (Exception e) {
            Log.e(TAG, "Check-in request failed", e);
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private static void appendField(StringBuilder body, String boundary, String name, String value) {
        body.append("--").append(boundary).append("\r\n");
        body.append("Content-Disposition: form-data; name=\"").append(name).append("\"\r\n\r\n");
        body.append(value).append("\r\n");
    }

    private static String readAll(InputStream stream) throws java.io.IOException {
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
