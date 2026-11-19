export interface GeofenceBackgroundPlugin {
    /**
     * Starts watching a circular area. When the device enters or leaves it, the plugin POSTs
     * a check-in or check-out to `apiEndPoint`, also when the app is in the background or closed.
     * Calling it again replaces the previous area. Works the same on iOS and Android.
     *
     * Asks for location permission if needed. Background tracking needs "Always" (iOS) or
     * "Allow all the time" (Android).
     */
    startTrackUser(options: StartTrackUserOptions): Promise<StartTrackUserResult>;
    /** Stops watching the area and forgets the saved endpoint, user ID and token. */
    stopTrackUser(): Promise<{
        message: string;
    }>;
}
export interface StartTrackUserOptions {
    /** Latitude of the area's centre. A number or a numeric string. */
    lat: number | string;
    /** Longitude of the area's centre. A number or a numeric string. */
    long: number | string;
    /**
     * Radius in metres. Defaults to 5. Both platforms detect boundary crossings reliably only
     * from about 100 m.
     */
    radius?: number | string;
    /**
     * URL that receives a `multipart/form-data` POST with `latitude`, `longitude` (the area's centre),
     * `aid`, `auth_token`, `checkin` (`"true"` on entry, `"false"` on exit), `timestamp` (when it
     * happened, ISO 8601 UTC) and `event_id` (unique per entry or exit).
     *
     * If the request fails (no network, timeout, 408, 429 or 5xx), it is saved and retried in order,
     * so use `timestamp` for the attendance time and `event_id` to ignore duplicates.
     */
    apiEndPoint: string;
    /** Sent as `aid`. A whole number or a numeric string. */
    userID: number | string;
    /** Sent as `auth_token`. Defaults to an empty string. */
    auth_token?: string;
}
export interface StartTrackUserResult {
    message: string;
    latitude: number;
    longitude: number;
    radius: number;
    apiEndPoint: string;
    userID: number;
    auth_token: string;
}
declare const GeofenceBackground: GeofenceBackgroundPlugin;
export { GeofenceBackground };
