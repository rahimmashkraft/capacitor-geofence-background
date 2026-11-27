# capacitor-geofence-background example

A Capacitor 8 app for trying the plugin on a real device, simulator or emulator. It installs the plugin from the parent folder, so it always runs your local changes.

```bash
# From the repository root: build the plugin
npm install && npm run build

# Then in this folder
npm install
npm run sync          # vite build + cap sync
npx cap run ios       # or: npx cap run android
```

The screen has a button for each plugin method and a log of `geofenceEvent` and `requestResult` events while the app is open. The code is in [`src/js/main.js`](src/js/main.js).

- **iOS:** the location usage texts are already in `ios/App/App/Info.plist`. Choose "Allow While Using App", then "Change to Always Allow" so tracking keeps working when the app is closed.
- **Android:** the plugin adds its permissions itself. Allow precise location, then "Allow all the time".
- In a browser (`npm start`) the page loads, but the plugin has no web implementation, so every call fails with `UNIMPLEMENTED`.
