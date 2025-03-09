import { registerPlugin } from '@capacitor/core';

export interface GeofenceBackgroundPlugin {
  startLocationService(): Promise<void>;
  stopLocationService(): Promise<void>;
}

const GeofenceBackground = registerPlugin<GeofenceBackgroundPlugin>('GeofenceBackground');

export { GeofenceBackground };
