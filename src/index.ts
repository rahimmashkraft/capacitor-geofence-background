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
  startTrackUser(lat: any, long: any, radius: any, apiEndPoint: any, userID: any): Promise<void>;
  stopTrackUser(): Promise<void>;
}

const GeofenceBackground = registerPlugin<GeofenceBackgroundPlugin>('GeofenceBackground');

export { GeofenceBackground };
