package com.mr.geofencebackground;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofenceStatusCodes;
import com.google.android.gms.location.GeofencingEvent;
import java.util.List;

/**
 * Receives geofence enter/exit events from Google Play services. Android starts the app process
 * for this even after the app has been closed, like iOS relaunching the app for a region event.
 */
public class GeofenceBroadcastReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        GeofencingEvent event = GeofencingEvent.fromIntent(intent);
        if (event == null) {
            return;
        }
        if (event.hasError()) {
            Log.e(GeofenceTracker.TAG, "Geofence error: " + GeofenceStatusCodes.getStatusCodeString(event.getErrorCode()));
            return;
        }

        int transition = event.getGeofenceTransition();
        if (transition != Geofence.GEOFENCE_TRANSITION_ENTER && transition != Geofence.GEOFENCE_TRANSITION_EXIT) {
            return;
        }
        if (!isOurRegion(event.getTriggeringGeofences())) {
            return;
        }

        // Nothing is saved once stopTrackUser has run, so a late event sends nothing.
        TrackingConfig config = TrackingConfig.load(context);
        if (config == null) {
            return;
        }

        boolean isCheckin = transition == Geofence.GEOFENCE_TRANSITION_ENTER;
        Log.d(GeofenceTracker.TAG, isCheckin ? "User entered the region" : "User exited the region");

        // Keep the receiver alive while the request is sent (or saved for retry) on a background thread.
        PendingResult pendingResult = goAsync();
        CheckInQueue.deliver(context, CheckInRequest.create(config, isCheckin), pendingResult::finish);
    }

    private static boolean isOurRegion(List<Geofence> geofences) {
        if (geofences == null) {
            return false;
        }
        for (Geofence geofence : geofences) {
            if (GeofenceTracker.REGION_ID.equals(geofence.getRequestId())) {
                return true;
            }
        }
        return false;
    }
}
