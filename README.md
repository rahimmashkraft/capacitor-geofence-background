# capacitor-geofence-background

[![npm version](https://img.shields.io/npm/v/capacitor-geofence-background)](https://www.npmjs.com/package/capacitor-geofence-background)
[![npm downloads](https://img.shields.io/npm/dm/capacitor-geofence-background)](https://www.npmjs.com/package/capacitor-geofence-background)
[![CI](https://github.com/rahimmashkraft/capacitor-geofence-background/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/rahimmashkraft/capacitor-geofence-background/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/npm/l/capacitor-geofence-background)](https://github.com/rahimmashkraft/capacitor-geofence-background/blob/main/LICENSE)
[![Known Vulnerabilities](https://snyk.io/test/github/rahimmashkraft/capacitor-geofence-background/badge.svg)](https://snyk.io/test/github/rahimmashkraft/capacitor-geofence-background)

Automatic check-in and check-out with a geofence. You give the plugin a location, a radius and an API endpoint. When the device enters or leaves that area, the plugin sends a check-in or check-out request to your server, even when the app is in the background or has been closed.

It works the same way on iOS (region monitoring) and Android (Google Play services geofencing).

## Install

```bash
npm install capacitor-geofence-background
npx cap sync
```

Works with Capacitor 6 and later, with either CocoaPods or Swift Package Manager on iOS.

Tested with Capacitor 6, 7 and 8: Android and iOS apps build with the plugin (iOS with both CocoaPods and Swift Package Manager), and check-in, check-out, retry after a failed request and `stopTrackUser` all work in the iOS Simulator and on a real Android 16 phone.

- Xcode 27 only builds apps for iOS 15 and later. A Capacitor 6 app (iOS 13) or 7 app (iOS 14) built with it needs its iOS deployment target raised to 15.
- With Swift Package Manager on Capacitor 6, use Capacitor 6.2.2: Capacitor's Swift package has no 6.2.3 release, so a 6.2.3 project can't resolve its packages.

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
| `timestamp`  | When the user entered or left, in UTC, for example `2026-11-10T09:02:13Z` |
| `event_id`   | A unique ID for this entry or exit, the same on every retry |

No request is sent for being inside the area when tracking starts, only for crossing its edge afterwards. Use a radius of about 100 m or more: neither platform detects smaller areas reliably.

### No network? Requests are retried

Each request is sent straight away. If that fails (no network, a timeout, or a `408`, `429` or `5xx` response), it is saved on the phone and retried, oldest first, so a check-out never arrives before its check-in. Any `2xx` response counts as delivered. Other responses, such as `400` or `401`, are treated as rejected and not retried.

- **Android** retries through WorkManager as soon as there is network, even if the app is closed or the phone restarts.
- **iOS** retries while the app is running, and as soon as the network comes back. iOS doesn't let a suspended app run, so a request saved while the app is in the background goes out the next time the app opens or the user next enters or leaves the area.

Because a retried request can arrive late, record attendance using `timestamp` rather than the time the request arrives. A request can also arrive twice, for example if the connection drops just after your server saved it, so ignore any `event_id` you have already stored. Requests older than 7 days are dropped. Requests already saved are still sent after `stopTrackUser`, because they describe entries and exits that really happened.

### Events, status, location and permissions

Listen for entries, exits and what happened to each request, for example to show "Checked in at 9:02":

```typescript
await GeofenceBackground.addListener('geofenceEvent', (event) => {
  console.log(event.transition, event.timestamp, event.eventId); // 'enter' or 'exit'
});

await GeofenceBackground.addListener('requestResult', (result) => {
  // 'sent', 'queued' (saved for retry), 'rejected' (for example 401) or 'dropped' (older than 7 days)
  console.log(result.eventId, result.status);
});
```

Both events only reach JavaScript while the app is running. An entry or exit while the app is closed still reaches your server, but not the listener, so treat your server as the full history. `eventId` is the same as the `event_id` your server receives.

Check whether tracking is on and how many requests are waiting to be retried:

```typescript
const status = await GeofenceBackground.getStatus();
// { isTracking: true, latitude, longitude, radius, apiEndPoint, userID, pendingRequests: 0 }
```

Get the device's location right now, for example to show it on a map or to check before a manual check-in:

```typescript
const location = await GeofenceBackground.getCurrentLocation({ timeout: 10000 });
// { latitude, longitude, accuracy, altitude, speed, heading, timestamp,
//   distanceFromCenter, isInsideArea }  (the last two only while tracking)
```

`accuracy`, `distanceFromCenter` and `altitude` are in metres, `speed` in metres per second and `heading` in degrees. Fields the device doesn't know, such as `speed` while standing still, are left out. It asks for location permission if needed; "While Using" is enough. If it fails, the error's `code` is `PERMISSION_DENIED`, `LOCATION_DISABLED`, `TIMEOUT` or `UNAVAILABLE`.

Check or ask for location permission before starting, for example to explain "Always" to the user first:

```typescript
const { location, backgroundLocation } = await GeofenceBackground.checkPermissions();
if (backgroundLocation !== 'granted') {
  await GeofenceBackground.requestPermissions(); // "While Using" first, then "Always"
}
```

Each value is `granted`, `denied`, `prompt` or `prompt-with-rationale`. iOS shows the "Always" prompt only once, so after the user keeps "While Using", `backgroundLocation` is `denied` and only the Settings app can change it.

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

## Running the example app

The [`example/`](example) folder is a small Vite + Capacitor app that installs the plugin from this repository (`"capacitor-geofence-background": "file:.."`), so it always runs your local changes.

```bash
# 1. Build the plugin (from the repository root)
npm install
npm run build

# 2. Build the example's web app
cd example
npm install
npm run build

# 3. Add a native platform, sync, and open it in Xcode or Android Studio
npx cap add ios        # or: npx cap add android
npx cap sync
npx cap open ios       # or: npx cap open android
```

Before running on a device, add the iOS `Info.plist` keys from [Platform setup](#platform-setup), then call `GeofenceBackground.startTrackUser(...)` from `example/src/js/capacitor-welcome.js` with a location near you and an endpoint you control (a request bin works well for watching check-ins arrive). After changing plugin code, run `npm run build` at the root and `npx cap sync` in `example/` again.

## API

<docgen-index>

* [`startTrackUser(...)`](#starttrackuser)
* [`stopTrackUser()`](#stoptrackuser)
* [`getStatus()`](#getstatus)
* [`getCurrentLocation(...)`](#getcurrentlocation)
* [`checkPermissions()`](#checkpermissions)
* [`requestPermissions()`](#requestpermissions)
* [`addListener('geofenceEvent', ...)`](#addlistenergeofenceevent-)
* [`addListener('requestResult', ...)`](#addlistenerrequestresult-)
* [`removeAllListeners()`](#removealllisteners)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

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


### getStatus()

```typescript
getStatus() => Promise<TrackingStatus>
```

Whether tracking is on, the area being watched, and how many requests are waiting to be retried.

**Returns:** <code>Promise&lt;<a href="#trackingstatus">TrackingStatus</a>&gt;</code>

--------------------


### getCurrentLocation(...)

```typescript
getCurrentLocation(options?: GetCurrentLocationOptions | undefined) => Promise<CurrentLocation>
```

Gets the device's current location once. Asks for location permission if needed ("While Using"
is enough). While tracking is on, the result also says how far the device is from the area's
centre and whether it is inside.

Rejects with code `PERMISSION_DENIED`, `LOCATION_DISABLED` (location switched off on the device),
`TIMEOUT` or `UNAVAILABLE`.

| Param         | Type                                                                            |
| ------------- | ------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#getcurrentlocationoptions">GetCurrentLocationOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#currentlocation">CurrentLocation</a>&gt;</code>

--------------------


### checkPermissions()

```typescript
checkPermissions() => Promise<PermissionStatus>
```

The current location permissions, without asking the user.

**Returns:** <code>Promise&lt;<a href="#permissionstatus">PermissionStatus</a>&gt;</code>

--------------------


### requestPermissions()

```typescript
requestPermissions() => Promise<PermissionStatus>
```

Asks for location permission, then for background location ("Always" on iOS, "Allow all the
time" on Android), and resolves with the result. Permissions already granted or denied are
not asked again. `startTrackUser` also asks by itself, so calling this first is optional.

**Returns:** <code>Promise&lt;<a href="#permissionstatus">PermissionStatus</a>&gt;</code>

--------------------


### addListener('geofenceEvent', ...)

```typescript
addListener(eventName: 'geofenceEvent', listenerFunc: (event: GeofenceEvent) => void) => Promise<PluginListenerHandle>
```

Called when the device enters or leaves the area. Only while the app is running: an event
that happens while the app is closed still reaches your server, but not this listener.

| Param              | Type                                                                        |
| ------------------ | --------------------------------------------------------------------------- |
| **`eventName`**    | <code>'geofenceEvent'</code>                                                |
| **`listenerFunc`** | <code>(event: <a href="#geofenceevent">GeofenceEvent</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('requestResult', ...)

```typescript
addListener(eventName: 'requestResult', listenerFunc: (event: RequestResultEvent) => void) => Promise<PluginListenerHandle>
```

Called when a check-in or check-out request is sent, saved for retry, rejected or dropped. Only while the app is running.

| Param              | Type                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'requestResult'</code>                                                          |
| **`listenerFunc`** | <code>(event: <a href="#requestresultevent">RequestResultEvent</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### removeAllListeners()

```typescript
removeAllListeners() => Promise<void>
```

Removes every listener added with `addListener`.

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

| Prop              | Type                          | Description                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ----------------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`lat`**         | <code>string \| number</code> | Latitude of the area's centre. A number or a numeric string.                                                                                                                                                                                                                                                                                                                                                                                   |
| **`long`**        | <code>string \| number</code> | Longitude of the area's centre. A number or a numeric string.                                                                                                                                                                                                                                                                                                                                                                                  |
| **`radius`**      | <code>string \| number</code> | Radius in metres. Defaults to 5. Both platforms detect boundary crossings reliably only from about 100 m.                                                                                                                                                                                                                                                                                                                                      |
| **`apiEndPoint`** | <code>string</code>           | URL that receives a `multipart/form-data` POST with `latitude`, `longitude` (the area's centre), `aid`, `auth_token`, `checkin` (`"true"` on entry, `"false"` on exit), `timestamp` (when it happened, ISO 8601 UTC) and `event_id` (unique per entry or exit). If the request fails (no network, timeout, 408, 429 or 5xx), it is saved and retried in order, so use `timestamp` for the attendance time and `event_id` to ignore duplicates. |
| **`userID`**      | <code>string \| number</code> | Sent as `aid`. A whole number or a numeric string.                                                                                                                                                                                                                                                                                                                                                                                             |
| **`auth_token`**  | <code>string</code>           | Sent as `auth_token`. Defaults to an empty string.                                                                                                                                                                                                                                                                                                                                                                                             |


#### TrackingStatus

| Prop                  | Type                 | Description                                                                                |
| --------------------- | -------------------- | ------------------------------------------------------------------------------------------ |
| **`isTracking`**      | <code>boolean</code> | True between `startTrackUser` and `stopTrackUser`, also after the app restarts.            |
| **`latitude`**        | <code>number</code>  | The area being watched. Only set while tracking.                                           |
| **`longitude`**       | <code>number</code>  |                                                                                            |
| **`radius`**          | <code>number</code>  |                                                                                            |
| **`apiEndPoint`**     | <code>string</code>  |                                                                                            |
| **`userID`**          | <code>number</code>  |                                                                                            |
| **`pendingRequests`** | <code>number</code>  | Requests saved for retry and not yet delivered. They are still sent after `stopTrackUser`. |


#### CurrentLocation

| Prop                     | Type                 | Description                                                                   |
| ------------------------ | -------------------- | ----------------------------------------------------------------------------- |
| **`latitude`**           | <code>number</code>  |                                                                               |
| **`longitude`**          | <code>number</code>  |                                                                               |
| **`accuracy`**           | <code>number</code>  | How far off the position may be, in metres.                                   |
| **`altitude`**           | <code>number</code>  | Metres above sea level, if known.                                             |
| **`altitudeAccuracy`**   | <code>number</code>  | How far off the altitude may be, in metres, if known.                         |
| **`speed`**              | <code>number</code>  | Metres per second, if known.                                                  |
| **`heading`**            | <code>number</code>  | Direction of travel in degrees from north (0 to 360), if known.               |
| **`timestamp`**          | <code>string</code>  | When the device measured this location, ISO 8601 in UTC.                      |
| **`distanceFromCenter`** | <code>number</code>  | Metres from the centre of the area being tracked. Only set while tracking.    |
| **`isInsideArea`**       | <code>boolean</code> | Whether the device is inside the area being tracked. Only set while tracking. |


#### GetCurrentLocationOptions

| Prop                     | Type                 | Description                                                                                                              |
| ------------------------ | -------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **`enableHighAccuracy`** | <code>boolean</code> | Use GPS for the best accuracy. Slower and uses more battery. Default `true`.                                             |
| **`timeout`**            | <code>number</code>  | Give up after this many milliseconds. Default `10000`.                                                                   |
| **`maximumAge`**         | <code>number</code>  | Accept a location the device already has if it is at most this many milliseconds old. Default `0`: always get a new one. |


#### PermissionStatus

| Prop                     | Type                                                        | Description                                                                                              |
| ------------------------ | ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| **`location`**           | <code><a href="#permissionstate">PermissionState</a></code> | Location while the app is in use. Android needs precise location.                                        |
| **`backgroundLocation`** | <code><a href="#permissionstate">PermissionState</a></code> | Location while the app is in the background or closed: "Always" on iOS, "Allow all the time" on Android. |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### GeofenceEvent

| Prop             | Type                           | Description                                                                    |
| ---------------- | ------------------------------ | ------------------------------------------------------------------------------ |
| **`eventId`**    | <code>string</code>            | Same as the `event_id` sent to the server.                                     |
| **`transition`** | <code>'enter' \| 'exit'</code> | `enter` for a check-in, `exit` for a check-out.                                |
| **`timestamp`**  | <code>string</code>            | When it happened, ISO 8601 in UTC. Same as the `timestamp` sent to the server. |
| **`latitude`**   | <code>number</code>            | Latitude of the area's centre.                                                 |
| **`longitude`**  | <code>number</code>            | Longitude of the area's centre.                                                |


#### RequestResultEvent

| Prop         | Type                                                       | Description                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------ | ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`status`** | <code>'sent' \| 'queued' \| 'rejected' \| 'dropped'</code> | - `sent`: the server answered with a `2xx` status. - `queued`: sending failed (no network, timeout, `408`, `429` or `5xx`), or earlier requests are still waiting. It is saved and retried; a later `sent` follows if the app is running then. - `rejected`: the server answered with another status, such as `400` or `401`. Not retried. - `dropped`: it waited more than 7 days (or, on iOS, more than 100 requests were waiting). Not sent. |


### Type Aliases


#### PermissionState

<code>'prompt' | 'prompt-with-rationale' | 'granted' | 'denied'</code>

</docgen-api>
