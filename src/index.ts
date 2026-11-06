import { registerPlugin } from '@capacitor/core';

export interface GeofenceBackgroundPlugin {
  startLocationService(): Promise<void>;
  stopLocationService(): Promise<void>;
  checkAndRequestPermissions(): Promise<void>;
  addGeofence(options: { id: string, latitude: number, longitude: number, radius: number, transitionType: number }): Promise<void>;
  removeGeofence(options: { id: string }): Promise<void>;
  removeAllGeofences(): Promise<void>;
  getGeofences(): Promise<{ geofences: any[] }>;
  getLocations(): Promise<{ locations: any[] }>;
  getPermissionsStatus(): Promise<{ status: string }>;
  isIgnoringBatteryOptimizations(): Promise<{ isIgnoring: boolean }>;
  requestIgnoreBatteryOptimizations(): Promise<void>;
  openSettings(): Promise<void>;
  isLocationServiceRunning(): Promise<{ isRunning: boolean }>;
  isGooglePlayServicesAvailable(): Promise<{ isAvailable: boolean }>;
  requestGooglePlayServices(): Promise<void>;
  isLocationEnabled(): Promise<{ isEnabled: boolean }>;
  requestLocationEnabling(): Promise<void>;
  isBackgroundLocationPermissionGranted(): Promise<{ isGranted: boolean }>;
  requestBackgroundLocationPermission(): Promise<void>;
  isIgnoringOptimizations(): Promise<{ isIgnoring: boolean }>;
  requestIgnoreOptimizations(): Promise<void>;
  isIgnoringDataSaver(): Promise<{ isIgnoring: boolean }>;
  requestIgnoreDataSaver(): Promise<void>;
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
   * `aid`, `auth_token`, and `checkin` (`"true"` on entry, `"false"` on exit).
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
