package com.mr.geofencebackground;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import com.google.android.gms.tasks.Task;

/** Android removes all geofences on reboot. This adds ours back if tracking was running. */
public class BootReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            return;
        }
        Task<Void> restore = GeofenceTracker.restoreGeofence(context);
        if (restore == null) {
            return;
        }
        // Keep the receiver alive until Play services has the geofence.
        PendingResult pendingResult = goAsync();
        restore.addOnCompleteListener(task -> pendingResult.finish());
    }
}
