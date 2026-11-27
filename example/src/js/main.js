import { Capacitor } from '@capacitor/core';
import { GeofenceBackground } from 'capacitor-geofence-background';

const $ = (id) => document.getElementById(id);
const form = $('track-form');
const statusOut = $('status-out');
const logList = $('log');

const FORM_KEY = 'geofence-example-form';

function log(message, kind = 'info') {
  const item = document.createElement('li');
  item.className = kind;
  item.textContent = `${new Date().toLocaleTimeString()}  ${message}`;
  logList.prepend(item);
}

function show(value) {
  statusOut.textContent = JSON.stringify(value, null, 2);
}

function errorText(err) {
  return err?.code ? `${err.code}: ${err.message}` : err?.message ?? String(err);
}

// Runs a button's action with the button disabled, and logs any error.
function action(button, fn) {
  button.addEventListener('click', async (event) => {
    event.preventDefault();
    button.disabled = true;
    try {
      await fn();
    } catch (err) {
      log(errorText(err), 'error');
    } finally {
      button.disabled = false;
    }
  });
}

// Remember the form between launches so you don't retype the endpoint.
function restoreForm() {
  try {
    const saved = JSON.parse(localStorage.getItem(FORM_KEY) ?? '{}');
    for (const [name, value] of Object.entries(saved)) {
      if (form.elements[name]) form.elements[name].value = value;
    }
  } catch {
    // Ignore a missing or broken saved form.
  }
}

function saveForm() {
  const values = Object.fromEntries(new FormData(form));
  try {
    localStorage.setItem(FORM_KEY, JSON.stringify(values));
  } catch {
    // Storage unavailable: the form just won't be remembered.
  }
  return values;
}

function logPermissions(perms) {
  show(perms);
  log(`Permissions: location=${perms.location}, background=${perms.backgroundLocation}`);
}

action($('check-perms'), async () => {
  logPermissions(await GeofenceBackground.checkPermissions());
});

action($('request-perms'), async () => {
  logPermissions(await GeofenceBackground.requestPermissions());
});

action($('use-location'), async () => {
  log('Getting current location...');
  const loc = await GeofenceBackground.getCurrentLocation({ enableHighAccuracy: true });
  form.elements.lat.value = loc.latitude.toFixed(6);
  form.elements.long.value = loc.longitude.toFixed(6);
  saveForm();
  log(`Location: ${loc.latitude.toFixed(6)}, ${loc.longitude.toFixed(6)} (±${Math.round(loc.accuracy)} m)`);
});

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  const submit = form.querySelector('button[type="submit"]');
  submit.disabled = true;
  try {
    const values = saveForm();
    const result = await GeofenceBackground.startTrackUser({
      lat: Number(values.lat),
      long: Number(values.long),
      radius: Number(values.radius),
      apiEndPoint: values.apiEndPoint,
      userID: Number(values.userID),
      auth_token: values.auth_token,
    });
    show(result);
    log(`Tracking started: ${result.radius} m around ${result.latitude}, ${result.longitude}`, 'success');
  } catch (err) {
    log(errorText(err), 'error');
  } finally {
    submit.disabled = false;
  }
});

action($('stop'), async () => {
  const result = await GeofenceBackground.stopTrackUser();
  log(result.message || 'Tracking stopped');
});

action($('status'), async () => {
  show(await GeofenceBackground.getStatus());
});

action($('where'), async () => {
  const loc = await GeofenceBackground.getCurrentLocation();
  show(loc);
  if (loc.isInsideArea !== undefined) {
    log(`${loc.isInsideArea ? 'Inside' : 'Outside'} the area, ${Math.round(loc.distanceFromCenter)} m from the centre`);
  }
});

$('clear-log').addEventListener('click', () => {
  logList.replaceChildren();
});

async function init() {
  restoreForm();

  if (!Capacitor.isNativePlatform()) {
    log('Running in a browser. The plugin only works on iOS and Android: use `npx cap run ios` or `npx cap run android`.', 'error');
    return;
  }

  await GeofenceBackground.addListener('geofenceEvent', (event) => {
    const what = event.transition === 'enter' ? 'Entered (check-in)' : 'Left (check-out)';
    log(`${what} at ${event.timestamp}`, 'success');
  });

  await GeofenceBackground.addListener('requestResult', (event) => {
    const kind = event.status === 'sent' ? 'success' : event.status === 'queued' ? 'info' : 'error';
    log(`Request ${event.status}: ${event.transition} (${event.eventId.slice(0, 8)})`, kind);
  });

  try {
    const status = await GeofenceBackground.getStatus();
    show(status);
    if (status.isTracking) {
      log(`Already tracking ${status.radius} m around ${status.latitude}, ${status.longitude}`);
    }
  } catch (err) {
    log(errorText(err), 'error');
  }
}

init();
