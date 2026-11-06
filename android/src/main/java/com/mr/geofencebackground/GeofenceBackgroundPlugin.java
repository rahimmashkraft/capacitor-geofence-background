package com.mr.geofencebackground;

import android.Manifest;
import android.os.Build;
import android.util.Log;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

/**
 * Android side of startTrackUser / stopTrackUser. Same options, results and server request as the
 * iOS plugin; uses Google Play services geofencing instead of iOS region monitoring.
 */
@CapacitorPlugin(
    name = "GeofenceBackground",
    permissions = {
        @Permission(
            alias = GeofenceBackgroundPlugin.LOCATION,
            strings = { Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION }
        ),
        @Permission(alias = GeofenceBackgroundPlugin.BACKGROUND_LOCATION, strings = { Manifest.permission.ACCESS_BACKGROUND_LOCATION })
    }
)
public class GeofenceBackgroundPlugin extends Plugin {

    static final String LOCATION = "location";
    static final String BACKGROUND_LOCATION = "backgroundLocation";

    @Override
    public void load() {
        // Android drops geofences when location is switched off or Play services data is cleared.
        // Put ours back whenever the app starts while tracking is on.
        GeofenceTracker.restoreGeofence(getContext());
    }

    @PluginMethod
    public void startTrackUser(PluginCall call) {
        TrackingConfig config = TrackingConfig.fromCall(call);
        if (config == null) {
            call.reject("Missing or invalid parameters: lat, long, userID and apiEndPoint are required");
            return;
        }

        // Android needs two separate requests: precise location first, then "Allow all the time".
        if (!GeofenceTracker.isGranted(getContext(), Manifest.permission.ACCESS_FINE_LOCATION)) {
            requestPermissionForAlias(LOCATION, call, "locationPermissionCallback");
            return;
        }
        if (!GeofenceTracker.hasLocationPermissions(getContext())) {
            requestPermissionForAlias(BACKGROUND_LOCATION, call, "backgroundLocationPermissionCallback");
            return;
        }

        // Save before adding the geofence so the receiver can read it for the first event.
        config.save(getContext());
        try {
            GeofenceTracker
                .addGeofence(getContext(), config)
                .addOnSuccessListener(unused -> call.resolve(startedResult(config)))
                .addOnFailureListener(e -> failStart(call, e));
        } catch (RuntimeException e) {
            failStart(call, e);
        }
    }

    @PluginMethod
    public void stopTrackUser(PluginCall call) {
        // Clear first so a geofence event already on its way sends nothing.
        TrackingConfig.clear(getContext());
        GeofenceTracker
            .removeGeofence(getContext())
            .addOnCompleteListener(task -> {
                if (!task.isSuccessful()) {
                    Log.w(GeofenceTracker.TAG, "Could not remove geofence", task.getException());
                }
                JSObject result = new JSObject();
                result.put("message", "User tracking stopped successfully");
                call.resolve(result);
            });
    }

    @PermissionCallback
    private void locationPermissionCallback(PluginCall call) {
        if (!GeofenceTracker.isGranted(getContext(), Manifest.permission.ACCESS_FINE_LOCATION)) {
            call.reject("Precise location permission is required");
            return;
        }
        startTrackUser(call);
    }

    @PermissionCallback
    private void backgroundLocationPermissionCallback(PluginCall call) {
        if (!GeofenceTracker.hasLocationPermissions(getContext())) {
            call.reject("Location permission \"Allow all the time\" is required to track the user when the app is closed");
            return;
        }
        startTrackUser(call);
    }

    private void failStart(PluginCall call, Exception e) {
        Log.e(GeofenceTracker.TAG, "Could not add geofence", e);
        TrackingConfig.clear(getContext());
        GeofenceTracker.removeGeofence(getContext());
        call.reject("Could not start geofence: " + e.getMessage(), e);
    }

    /** Same fields as the iOS result. */
    private static JSObject startedResult(TrackingConfig config) {
        JSObject result = new JSObject();
        result.put("message", "User tracking started successfully");
        result.put("latitude", config.latitude);
        result.put("longitude", config.longitude);
        result.put("radius", config.radius);
        result.put("apiEndPoint", config.apiEndPoint);
        result.put("userID", config.userID);
        result.put("auth_token", config.authToken);
        return result;
    }
}
