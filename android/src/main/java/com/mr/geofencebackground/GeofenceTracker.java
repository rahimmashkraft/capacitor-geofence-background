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
import java.util.Collections;

/** Adds and removes the geofence. Mirrors ContinuesLocationManager on iOS; CheckInQueue sends the requests. */
final class GeofenceTracker {

    static final String TAG = "GeofenceBackground";
    /** Same identifier as the iOS region. */
    static final String REGION_ID = "dynamicRegion";

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
}
