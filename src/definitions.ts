export interface GeofenceBackgroundPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
