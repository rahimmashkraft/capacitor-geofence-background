---
name: Bug report
about: Something isn't working as described
title: '[Bug] '
labels: bug
assignees: ''
---

## What happened

A clear description of the bug.

## What you expected

What you expected to happen instead.

## Steps to reproduce

1.
2.
3.

A minimal code sample, if you can:

```typescript
await GeofenceBackground.startTrackUser({
  // ...
});
```

## App state when it happened

- [ ] Foreground
- [ ] Background
- [ ] App killed / swiped away
- [ ] After a phone restart

## Environment

| | |
| --- | --- |
| Plugin version (`capacitor-geofence-background`) | |
| Capacitor version (`@capacitor/core`) | |
| Platform | iOS / Android |
| iOS version / Android version | |
| Device model, or Simulator / Emulator | |
| iOS: CocoaPods or Swift Package Manager | |
| Xcode / Android Studio version | |

## Permissions

Location permission granted: While Using / Always / Denied
Android: background location and notification permission granted? Battery optimisation on?

## Logs

Relevant Xcode console or `adb logcat` output, and any `requestResult` events.

```
paste logs here
```
