import { WebPlugin } from '@capacitor/core';

import type { GeofenceBackgroundPlugin } from './definitions';

export class GeofenceBackgroundWeb
  extends WebPlugin
  implements GeofenceBackgroundPlugin
{
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
