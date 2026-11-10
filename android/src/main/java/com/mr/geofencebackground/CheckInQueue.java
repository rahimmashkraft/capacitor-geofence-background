package com.mr.geofencebackground;

import android.content.Context;
import android.util.Log;
import androidx.work.BackoffPolicy;
import androidx.work.Constraints;
import androidx.work.ExistingWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkInfo;
import androidx.work.WorkManager;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/**
 * Gets every check-in and check-out to the server, in order. Each one is sent straight away; if
 * that fails it is saved with WorkManager, which retries it once there is network, even after the
 * app is closed or the phone restarts.
 */
final class CheckInQueue {

    /** Requests older than this are dropped instead of retried. */
    static final long MAX_AGE_MS = TimeUnit.DAYS.toMillis(7);

    private static final String UNIQUE_WORK = "GeofenceBackgroundCheckIns";
    private static final long FIRST_RETRY_DELAY_SECONDS = 30;

    // One at a time, so two transitions close together reach the server in the order they happened.
    private static final ExecutorService EXECUTOR = Executors.newSingleThreadExecutor();

    private CheckInQueue() {}

    /** Delivers the request on a background thread, then runs onDone. */
    static void deliver(Context context, CheckInRequest request, Runnable onDone) {
        Context appContext = context.getApplicationContext();
        EXECUTOR.execute(() -> {
            try {
                deliverNow(appContext, request);
            } catch (RuntimeException e) {
                Log.e(GeofenceTracker.TAG, "Could not deliver check-in", e);
            } finally {
                onDone.run();
            }
        });
    }

    private static void deliverNow(Context context, CheckInRequest request) {
        // Earlier requests are still waiting: queue behind them so the server gets them in order.
        if (hasWaitingRequests(context)) {
            enqueue(context, request, 0);
            return;
        }
        if (CheckInSender.send(request) == CheckInSender.Outcome.RETRY) {
            enqueue(context, request, FIRST_RETRY_DELAY_SECONDS);
        }
    }

    private static void enqueue(Context context, CheckInRequest request, long delaySeconds) {
        OneTimeWorkRequest work = new OneTimeWorkRequest.Builder(CheckInWorker.class)
            .setInputData(request.toData())
            .setConstraints(new Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .setInitialDelay(delaySeconds, TimeUnit.SECONDS)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, FIRST_RETRY_DELAY_SECONDS, TimeUnit.SECONDS)
            .build();
        // APPEND keeps the order: this request waits until every earlier one has finished.
        WorkManager.getInstance(context).enqueueUniqueWork(UNIQUE_WORK, ExistingWorkPolicy.APPEND_OR_REPLACE, work);
        Log.d(GeofenceTracker.TAG, "Check-in saved; it will be retried when the network is available");
    }

    private static boolean hasWaitingRequests(Context context) {
        try {
            List<WorkInfo> works = WorkManager.getInstance(context).getWorkInfosForUniqueWork(UNIQUE_WORK).get();
            for (WorkInfo work : works) {
                if (!work.getState().isFinished()) {
                    return true;
                }
            }
            return false;
        } catch (Exception e) {
            // If we can't tell, queue it: that keeps the order and still delivers it.
            Log.w(GeofenceTracker.TAG, "Could not read the retry queue", e);
            return true;
        }
    }
}
