package com.mr.geofencebackground;

import android.annotation.SuppressLint;
import android.content.Context;
import android.location.Location;
import android.location.LocationManager;
import android.os.Build;
import androidx.core.location.LocationManagerCompat;
import com.getcapacitor.JSObject;
import com.google.android.gms.location.CurrentLocationRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;
import com.google.android.gms.tasks.CancellationTokenSource;

/** Gets the device's location once, for getCurrentLocation. Same result fields as the iOS plugin. */
final class LocationFetcher {

    static final String PERMISSION_DENIED = "PERMISSION_DENIED";
    static final String LOCATION_DISABLED = "LOCATION_DISABLED";
    static final String TIMEOUT = "TIMEOUT";
    static final String UNAVAILABLE = "UNAVAILABLE";

    static final long DEFAULT_TIMEOUT_MS = 10_000;

    interface Callback {
        void onLocation(JSObject location);

        void onError(String message, String code);
    }

    private LocationFetcher() {}

    static boolean isLocationEnabled(Context context) {
        LocationManager manager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        return manager != null && LocationManagerCompat.isLocationEnabled(manager);
    }

    /** Callers must check for location permission first. */
    @SuppressLint("MissingPermission")
    static void fetch(Context context, boolean highAccuracy, long timeoutMs, long maximumAgeMs, Callback callback) {
        CurrentLocationRequest request = new CurrentLocationRequest.Builder()
            .setPriority(highAccuracy ? Priority.PRIORITY_HIGH_ACCURACY : Priority.PRIORITY_BALANCED_POWER_ACCURACY)
            // A location already known is used if it is at most this old; 0 always asks for a fresh one.
            .setMaxUpdateAgeMillis(maximumAgeMs)
            // Play services gives up after this and returns null.
            .setDurationMillis(timeoutMs)
            .build();
        Context appContext = context.getApplicationContext();
        LocationServices
            .getFusedLocationProviderClient(appContext)
            .getCurrentLocation(request, new CancellationTokenSource().getToken())
            .addOnSuccessListener(location -> {
                if (location == null) {
                    callback.onError("Could not get a location within " + timeoutMs + " ms", TIMEOUT);
                } else {
                    callback.onLocation(toResult(appContext, location));
                }
            })
            .addOnFailureListener(e -> callback.onError("Could not get the location: " + e.getMessage(), UNAVAILABLE));
    }

    private static JSObject toResult(Context context, Location location) {
        JSObject result = new JSObject();
        result.put("latitude", location.getLatitude());
        result.put("longitude", location.getLongitude());
        result.put("accuracy", location.getAccuracy());
        if (location.hasAltitude()) {
            result.put("altitude", location.getAltitude());
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && location.hasVerticalAccuracy()) {
            result.put("altitudeAccuracy", location.getVerticalAccuracyMeters());
        }
        if (location.hasSpeed()) {
            result.put("speed", location.getSpeed());
        }
        if (location.hasBearing()) {
            result.put("heading", location.getBearing());
        }
        result.put("timestamp", CheckInSender.formatTimestamp(location.getTime()));

        // While tracking, also say how far the device is from the area and whether it is inside.
        TrackingConfig config = TrackingConfig.load(context);
        if (config != null) {
            float[] distance = new float[1];
            Location.distanceBetween(location.getLatitude(), location.getLongitude(), config.latitude, config.longitude, distance);
            result.put("distanceFromCenter", distance[0]);
            result.put("isInsideArea", distance[0] <= config.radius);
        }
        return result;
    }
}
