package com.mr.geofencebackground;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.SharedPreferences;
import androidx.annotation.Nullable;
import com.getcapacitor.JSObject;
import com.getcapacitor.PluginCall;

/**
 * The values passed to startTrackUser. They are saved so a geofence event can still send the
 * check-in request after the app has been killed, and so the geofence can be added again after
 * a reboot. Option names, defaults and storage keys match the iOS plugin.
 *
 * Writes use commit(), not apply(): the app process can be killed right after start or stop,
 * and the geofence receiver must see the saved (or cleared) values.
 */
@SuppressLint("ApplySharedPref")
final class TrackingConfig {

    static final double DEFAULT_RADIUS = 5.0;

    private static final String PREFS_NAME = "GeofenceBackground";
    private static final String KEY_LATITUDE = "StoredLatitude";
    private static final String KEY_LONGITUDE = "StoredLongitude";
    private static final String KEY_RADIUS = "StoredRadius";
    private static final String KEY_API_ENDPOINT = "StoredAPIEndpoint";
    private static final String KEY_USER_ID = "StoredUserID";
    private static final String KEY_AUTH_TOKEN = "auth_token";

    final double latitude;
    final double longitude;
    final double radius;
    final String apiEndPoint;
    final long userID;
    final String authToken;

    private TrackingConfig(double latitude, double longitude, double radius, String apiEndPoint, long userID, String authToken) {
        this.latitude = latitude;
        this.longitude = longitude;
        this.radius = radius;
        this.apiEndPoint = apiEndPoint;
        this.userID = userID;
        this.authToken = authToken;
    }

    /**
     * Reads the startTrackUser options. lat, long, radius and userID may be numbers or numeric
     * strings. Returns null if a required option is missing or invalid.
     */
    @Nullable
    static TrackingConfig fromCall(PluginCall call) {
        JSObject data = call.getData();
        Double latitude = readDouble(data.opt("lat"));
        Double longitude = readDouble(data.opt("long"));
        Long userID = readLong(data.opt("userID"));
        String apiEndPoint = call.getString("apiEndPoint");
        if (latitude == null || longitude == null || userID == null || apiEndPoint == null || apiEndPoint.trim().isEmpty()) {
            return null;
        }

        Double radius = readDouble(data.opt("radius"));
        if (radius == null || radius <= 0) {
            radius = DEFAULT_RADIUS;
        }
        String authToken = call.getString("auth_token", "");
        return new TrackingConfig(latitude, longitude, radius, apiEndPoint.trim(), userID, authToken);
    }

    /** Returns the saved config, or null when tracking is not running. */
    @Nullable
    static TrackingConfig load(Context context) {
        SharedPreferences prefs = prefs(context);
        String apiEndPoint = prefs.getString(KEY_API_ENDPOINT, null);
        if (apiEndPoint == null || apiEndPoint.isEmpty()) {
            return null;
        }
        return new TrackingConfig(
            getDouble(prefs, KEY_LATITUDE),
            getDouble(prefs, KEY_LONGITUDE),
            getDouble(prefs, KEY_RADIUS),
            apiEndPoint,
            prefs.getLong(KEY_USER_ID, 0),
            prefs.getString(KEY_AUTH_TOKEN, "")
        );
    }

    void save(Context context) {
        prefs(context)
            .edit()
            .clear()
            .putLong(KEY_LATITUDE, Double.doubleToRawLongBits(latitude))
            .putLong(KEY_LONGITUDE, Double.doubleToRawLongBits(longitude))
            .putLong(KEY_RADIUS, Double.doubleToRawLongBits(radius))
            .putString(KEY_API_ENDPOINT, apiEndPoint)
            .putLong(KEY_USER_ID, userID)
            .putString(KEY_AUTH_TOKEN, authToken)
            .commit();
    }

    static void clear(Context context) {
        prefs(context).edit().clear().commit();
    }

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    // SharedPreferences has no double type, so doubles are stored as their raw bits.
    private static double getDouble(SharedPreferences prefs, String key) {
        return Double.longBitsToDouble(prefs.getLong(key, Double.doubleToRawLongBits(0)));
    }

    @Nullable
    private static Double readDouble(@Nullable Object value) {
        double result;
        if (value instanceof Number) {
            result = ((Number) value).doubleValue();
        } else if (value instanceof String) {
            try {
                result = Double.parseDouble(((String) value).trim());
            } catch (NumberFormatException e) {
                return null;
            }
        } else {
            return null;
        }
        return Double.isNaN(result) || Double.isInfinite(result) ? null : result;
    }

    @Nullable
    private static Long readLong(@Nullable Object value) {
        if (value instanceof Integer || value instanceof Long) {
            return ((Number) value).longValue();
        }
        if (value instanceof Number) {
            // Whole-number doubles such as 42.0 are accepted; 42.5 is not.
            double number = ((Number) value).doubleValue();
            return number == Math.rint(number) && !Double.isInfinite(number) ? (long) number : null;
        }
        if (value instanceof String) {
            try {
                return Long.parseLong(((String) value).trim());
            } catch (NumberFormatException e) {
                return null;
            }
        }
        return null;
    }
}
