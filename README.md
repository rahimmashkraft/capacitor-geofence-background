# capacitor-geofence-background

This plugin track your location in app kill state

## Install

```bash
npm install capacitor-geofence-background
npx cap sync
```

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
* [`startTrackUser()`](#starttrackuser)
* [`stopTrackUser()`](#stoptrackuser)

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


### startTrackUser()

```typescript
startTrackUser() => Promise<void>
```

--------------------


### stopTrackUser()

```typescript
stopTrackUser() => Promise<void>
```

--------------------

</docgen-api>
