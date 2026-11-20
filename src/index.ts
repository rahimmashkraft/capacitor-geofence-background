import { registerPlugin } from '@capacitor/core';
import type { PermissionState, PluginListenerHandle } from '@capacitor/core';

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
  stopTrackUser(): Promise<{ message: string }>;
  /** Whether tracking is on, the area being watched, and how many requests are waiting to be retried. */
  getStatus(): Promise<TrackingStatus>;
  /**
   * Gets the device's current location once. Asks for location permission if needed ("While Using"
   * is enough). While tracking is on, the result also says how far the device is from the area's
   * centre and whether it is inside.
   *
   * Rejects with code `PERMISSION_DENIED`, `LOCATION_DISABLED` (location switched off on the device),
   * `TIMEOUT` or `UNAVAILABLE`.
   */
  getCurrentLocation(options?: GetCurrentLocationOptions): Promise<CurrentLocation>;
  /** The current location permissions, without asking the user. */
  checkPermissions(): Promise<PermissionStatus>;
  /**
   * Asks for location permission, then for background location ("Always" on iOS, "Allow all the
   * time" on Android), and resolves with the result. Permissions already granted or denied are
   * not asked again. `startTrackUser` also asks by itself, so calling this first is optional.
   */
  requestPermissions(): Promise<PermissionStatus>;
  /**
   * Called when the device enters or leaves the area. Only while the app is running: an event
   * that happens while the app is closed still reaches your server, but not this listener.
   */
  addListener(eventName: 'geofenceEvent', listenerFunc: (event: GeofenceEvent) => void): Promise<PluginListenerHandle>;
  /** Called when a check-in or check-out request is sent, saved for retry, rejected or dropped. Only while the app is running. */
  addListener(eventName: 'requestResult', listenerFunc: (event: RequestResultEvent) => void): Promise<PluginListenerHandle>;
  /** Removes every listener added with `addListener`. */
  removeAllListeners(): Promise<void>;
}

export interface GeofenceEvent {
  /** Same as the `event_id` sent to the server. */
  eventId: string;
  /** `enter` for a check-in, `exit` for a check-out. */
  transition: 'enter' | 'exit';
  /** When it happened, ISO 8601 in UTC. Same as the `timestamp` sent to the server. */
  timestamp: string;
  /** Latitude of the area's centre. */
  latitude: number;
  /** Longitude of the area's centre. */
  longitude: number;
}

export interface RequestResultEvent extends GeofenceEvent {
  /**
   * - `sent`: the server answered with a `2xx` status.
   * - `queued`: sending failed (no network, timeout, `408`, `429` or `5xx`), or earlier requests
   *   are still waiting. It is saved and retried; a later `sent` follows if the app is running then.
   * - `rejected`: the server answered with another status, such as `400` or `401`. Not retried.
   * - `dropped`: it waited more than 7 days (or, on iOS, more than 100 requests were waiting). Not sent.
   */
  status: 'sent' | 'queued' | 'rejected' | 'dropped';
}

export interface GetCurrentLocationOptions {
  /** Use GPS for the best accuracy. Slower and uses more battery. Default `true`. */
  enableHighAccuracy?: boolean;
  /** Give up after this many milliseconds. Default `10000`. */
  timeout?: number;
  /** Accept a location the device already has if it is at most this many milliseconds old. Default `0`: always get a new one. */
  maximumAge?: number;
}

export interface CurrentLocation {
  latitude: number;
  longitude: number;
  /** How far off the position may be, in metres. */
  accuracy: number;
  /** Metres above sea level, if known. */
  altitude?: number;
  /** How far off the altitude may be, in metres, if known. */
  altitudeAccuracy?: number;
  /** Metres per second, if known. */
  speed?: number;
  /** Direction of travel in degrees from north (0 to 360), if known. */
  heading?: number;
  /** When the device measured this location, ISO 8601 in UTC. */
  timestamp: string;
  /** Metres from the centre of the area being tracked. Only set while tracking. */
  distanceFromCenter?: number;
  /** Whether the device is inside the area being tracked. Only set while tracking. */
  isInsideArea?: boolean;
}

export interface TrackingStatus {
  /** True between `startTrackUser` and `stopTrackUser`, also after the app restarts. */
  isTracking: boolean;
  /** The area being watched. Only set while tracking. */
  latitude?: number;
  longitude?: number;
  radius?: number;
  apiEndPoint?: string;
  userID?: number;
  /** Requests saved for retry and not yet delivered. They are still sent after `stopTrackUser`. */
  pendingRequests: number;
}

export interface PermissionStatus {
  /** Location while the app is in use. Android needs precise location. */
  location: PermissionState;
  /** Location while the app is in the background or closed: "Always" on iOS, "Allow all the time" on Android. */
  backgroundLocation: PermissionState;
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

const GeofenceBackground = registerPlugin<GeofenceBackgroundPlugin>('GeofenceBackground');

export { GeofenceBackground };
