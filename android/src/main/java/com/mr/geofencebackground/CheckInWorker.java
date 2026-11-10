package com.mr.geofencebackground;

import android.content.Context;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

/**
 * Retries one saved check-in or check-out. WorkManager runs it when there is network and repeats
 * it with growing delays (30 s, 1 min, 2 min, ... up to 5 hours) until the server answers.
 */
public class CheckInWorker extends Worker {

    public CheckInWorker(@NonNull Context context, @NonNull WorkerParameters params) {
        super(context, params);
    }

    @NonNull
    @Override
    public Result doWork() {
        CheckInRequest request = CheckInRequest.fromData(getInputData());
        if (request == null) {
            return Result.success();
        }
        if (System.currentTimeMillis() - request.timestampMillis > CheckInQueue.MAX_AGE_MS) {
            Log.w(GeofenceTracker.TAG, "Dropping a check-in older than 7 days: " + request.eventId);
            return Result.success();
        }

        // Only RETRY repeats it. A rejected request counts as done so the ones behind it still go out.
        return CheckInSender.send(request) == CheckInSender.Outcome.RETRY ? Result.retry() : Result.success();
    }
}
