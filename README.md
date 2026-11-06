# capacitor-geofence-background

Automatic check-in and check-out with a geofence. You give the plugin a location, a radius and an API endpoint. When the device enters or leaves that area, the plugin sends a check-in or check-out request to your server, even when the app is in the background or has been closed.

It works the same way on iOS (region monitoring) and Android (Google Play services geofencing).

## Install

```bash
npm install capacitor-geofence-background
npx cap sync
```

Works with Capacitor 6 and later (tested with 6, 7 and 8), with either CocoaPods or Swift Package Manager on iOS.

## Usage

```typescript
import { GeofenceBackground } from 'capacitor-geofence-background';

await GeofenceBackground.startTrackUser({
  lat: 24.8607,
  long: 67.0011,
  radius: 150, // metres
  apiEndPoint: 'https://example.com/api/attendance',
  userID: 42,
  auth_token: 'user-token',
});

// Later, for example on logout:
await GeofenceBackground.stopTrackUser();
```

On every entry and exit, your endpoint receives a `multipart/form-data` POST with these fields:

| Field        | Value                                        |
| ------------ | -------------------------------------------- |
| `latitude`   | Latitude of the area's centre                |
| `longitude`  | Longitude of the area's centre               |
| `aid`        | `userID`                                     |
| `auth_token` | `auth_token`                                 |
| `checkin`    | `true` on entry, `false` on exit             |

No request is sent for being inside the area when tracking starts, only for crossing its edge afterwards. Use a radius of about 100 m or more: neither platform detects smaller areas reliably.

## Platform setup

### iOS

Add both location usage descriptions to `Info.plist`. The plugin asks for "While Using", then "Always", which region monitoring needs when the app is closed.

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We use your location to check you in when you arrive.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We use your location to check you in and out even when the app is closed.</string>
```

### Android

The plugin's manifest adds the location, background location, internet and boot permissions. `startTrackUser` asks for precise location, then for "Allow all the time". Without "Allow all the time" it rejects, because Android geofences don't fire in the background otherwise.

Google Play requires you to declare background location use in the Play Console.

## API

<docgen-index>

* [`startLocationService()`](#startlocationservice)
* [`stopLocationService()`](#stoplocationservice)
* [`checkAndRequestPermissions()`](#checkandrequestpermissions)
* [`addGeofence(...)`](#addgeofence)
* [`removeGeofence(...)`](#removegeofence)
* [`removeAllGeofences()`](#removeallgeofences)
* [`getGeofences()`](#getgeofences)
* [`getLocations()`](#getlocations)
* [`getPermissionsStatus()`](#getpermissionsstatus)
* [`isIgnoringBatteryOptimizations()`](#isignoringbatteryoptimizations)
* [`requestIgnoreBatteryOptimizations()`](#requestignorebatteryoptimizations)
* [`openSettings()`](#opensettings)
* [`isLocationServiceRunning()`](#islocationservicerunning)
* [`isGooglePlayServicesAvailable()`](#isgoogleplayservicesavailable)
* [`requestGooglePlayServices()`](#requestgoogleplayservices)
* [`isLocationEnabled()`](#islocationenabled)
* [`requestLocationEnabling()`](#requestlocationenabling)
* [`isBackgroundLocationPermissionGranted()`](#isbackgroundlocationpermissiongranted)
* [`requestBackgroundLocationPermission()`](#requestbackgroundlocationpermission)
* [`isIgnoringOptimizations()`](#isignoringoptimizations)
* [`requestIgnoreOptimizations()`](#requestignoreoptimizations)
* [`isIgnoringDataSaver()`](#isignoringdatasaver)
* [`requestIgnoreDataSaver()`](#requestignoredatasaver)
* [`startTrackUser(...)`](#starttrackuser)
* [`stopTrackUser()`](#stoptrackuser)
* [Interfaces](#interfaces)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### startLocationService()

```typescript
startLocationService() => Promise<void>
```

--------------------


### stopLocationService()

```typescript
stopLocationService() => Promise<void>
```

--------------------


### checkAndRequestPermissions()

```typescript
checkAndRequestPermissions() => Promise<void>
```

--------------------


### addGeofence(...)

```typescript
addGeofence(options: { id: string; latitude: number; longitude: number; radius: number; transitionType: number; }) => Promise<void>
```

| Param         | Type                                                                                                      |
| ------------- | --------------------------------------------------------------------------------------------------------- |
| **`options`** | <code>{ id: string; latitude: number; longitude: number; radius: number; transitionType: number; }</code> |

--------------------


### removeGeofence(...)

```typescript
removeGeofence(options: { id: string; }) => Promise<void>
```

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: string; }</code> |

--------------------


### removeAllGeofences()

```typescript
removeAllGeofences() => Promise<void>
```

--------------------


### getGeofences()

```typescript
getGeofences() => Promise<{ geofences: any[]; }>
```

**Returns:** <code>Promise&lt;{ geofences: any[]; }&gt;</code>

--------------------


### getLocations()

```typescript
getLocations() => Promise<{ locations: any[]; }>
```

**Returns:** <code>Promise&lt;{ locations: any[]; }&gt;</code>

--------------------


### getPermissionsStatus()

```typescript
getPermissionsStatus() => Promise<{ status: string; }>
```

**Returns:** <code>Promise&lt;{ status: string; }&gt;</code>

--------------------


### isIgnoringBatteryOptimizations()

```typescript
isIgnoringBatteryOptimizations() => Promise<{ isIgnoring: boolean; }>
```

**Returns:** <code>Promise&lt;{ isIgnoring: boolean; }&gt;</code>

--------------------


### requestIgnoreBatteryOptimizations()

```typescript
requestIgnoreBatteryOptimizations() => Promise<void>
```

--------------------


### openSettings()

```typescript
openSettings() => Promise<void>
```

--------------------


### isLocationServiceRunning()

```typescript
isLocationServiceRunning() => Promise<{ isRunning: boolean; }>
```

**Returns:** <code>Promise&lt;{ isRunning: boolean; }&gt;</code>

--------------------


### isGooglePlayServicesAvailable()

```typescript
isGooglePlayServicesAvailable() => Promise<{ isAvailable: boolean; }>
```

**Returns:** <code>Promise&lt;{ isAvailable: boolean; }&gt;</code>

--------------------


### requestGooglePlayServices()

```typescript
requestGooglePlayServices() => Promise<void>
```

--------------------


### isLocationEnabled()

```typescript
isLocationEnabled() => Promise<{ isEnabled: boolean; }>
```

**Returns:** <code>Promise&lt;{ isEnabled: boolean; }&gt;</code>

--------------------


### requestLocationEnabling()

```typescript
requestLocationEnabling() => Promise<void>
```

--------------------


### isBackgroundLocationPermissionGranted()

```typescript
isBackgroundLocationPermissionGranted() => Promise<{ isGranted: boolean; }>
```

**Returns:** <code>Promise&lt;{ isGranted: boolean; }&gt;</code>

--------------------


### requestBackgroundLocationPermission()

```typescript
requestBackgroundLocationPermission() => Promise<void>
```

--------------------


### isIgnoringOptimizations()

```typescript
isIgnoringOptimizations() => Promise<{ isIgnoring: boolean; }>
```

**Returns:** <code>Promise&lt;{ isIgnoring: boolean; }&gt;</code>

--------------------


### requestIgnoreOptimizations()

```typescript
requestIgnoreOptimizations() => Promise<void>
```

--------------------


### isIgnoringDataSaver()

```typescript
isIgnoringDataSaver() => Promise<{ isIgnoring: boolean; }>
```

**Returns:** <code>Promise&lt;{ isIgnoring: boolean; }&gt;</code>

--------------------


### requestIgnoreDataSaver()

```typescript
requestIgnoreDataSaver() => Promise<void>
```

--------------------


### startTrackUser(...)

```typescript
startTrackUser(options: StartTrackUserOptions) => Promise<StartTrackUserResult>
```

Starts watching a circular area. When the device enters or leaves it, the plugin POSTs
a check-in or check-out to `apiEndPoint`, also when the app is in the background or closed.
Calling it again replaces the previous area. Works the same on iOS and Android.

Asks for location permission if needed. Background tracking needs "Always" (iOS) or
"Allow all the time" (Android).

| Param         | Type                                                                    |
| ------------- | ----------------------------------------------------------------------- |
| **`options`** | <code><a href="#starttrackuseroptions">StartTrackUserOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#starttrackuserresult">StartTrackUserResult</a>&gt;</code>

--------------------


### stopTrackUser()

```typescript
stopTrackUser() => Promise<{ message: string; }>
```

Stops watching the area and forgets the saved endpoint, user ID and token.

**Returns:** <code>Promise&lt;{ message: string; }&gt;</code>

--------------------


### Interfaces


#### StartTrackUserResult

| Prop              | Type                |
| ----------------- | ------------------- |
| **`message`**     | <code>string</code> |
| **`latitude`**    | <code>number</code> |
| **`longitude`**   | <code>number</code> |
| **`radius`**      | <code>number</code> |
| **`apiEndPoint`** | <code>string</code> |
| **`userID`**      | <code>number</code> |
| **`auth_token`**  | <code>string</code> |


#### StartTrackUserOptions

| Prop              | Type                          | Description                                                                                                                                                                 |
| ----------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`lat`**         | <code>string \| number</code> | Latitude of the area's centre. A number or a numeric string.                                                                                                                |
| **`long`**        | <code>string \| number</code> | Longitude of the area's centre. A number or a numeric string.                                                                                                               |
| **`radius`**      | <code>string \| number</code> | Radius in metres. Defaults to 5. Both platforms detect boundary crossings reliably only from about 100 m.                                                                   |
| **`apiEndPoint`** | <code>string</code>           | URL that receives a `multipart/form-data` POST with `latitude`, `longitude` (the area's centre), `aid`, `auth_token`, and `checkin` (`"true"` on entry, `"false"` on exit). |
| **`userID`**      | <code>string \| number</code> | Sent as `aid`. A whole number or a numeric string.                                                                                                                          |
| **`auth_token`**  | <code>string</code>           | Sent as `auth_token`. Defaults to an empty string.                                                                                                                          |

</docgen-api>
