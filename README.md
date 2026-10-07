# GPS Mapping

A SwiftUI app (iPad, iPhone, and Mac) for viewing GPS tracker data stored in Firebase.

- Sign in with a Google account (Google Sign-In, exchanged for a Firebase Auth session).
- A calendar shows every day that has GPS data. The days are read from the `unique_days` Firestore collection, where each document ID is a date formatted `YYYY_MM_DD`.
- Tap a day to load that day's points from the `gps_locations` collection (matched on each document's `dt` timestamp) and see the route on a map, along with the total distance traveled.

## Requirements

- Xcode with the iOS 26 / macOS 26 SDKs
- iPadOS / iOS 26.0 or later, or macOS 26 or later
- An Apple developer team selected under **Signing & Capabilities**
- A Firebase project with **Authentication (Google provider)** and **Cloud Firestore** enabled

## Setup: add your Firebase config file (required)

The Firebase config file contains the project's API key and IDs, so it is **deliberately not committed** (it is listed in `.gitignore`). The app will not be able to reach Firebase until you add it.

1. In the [Firebase console](https://console.firebase.google.com), open your project and go to **Project settings → Your apps → iOS app**.
2. Download the config file (it downloads as `GoogleService-Info.plist`).
3. **Rename it to `GPS-Tracker-Pico2W.plist`** and place it in the `GPS_Mapping/` source folder, next to `Info.plist`:

   ```
   GPS_Mapping/
   ├── App/
   ├── Views/
   ├── Info.plist
   └── GPS-Tracker-Pico2W.plist   <-- put it here
   ```

   (The file name is set in `GPS_Mapping/App/MyApp.swift`. If you would rather keep Firebase's default name, `GoogleService-Info.plist`, change it there.)
4. Make sure the file's **BUNDLE_ID** matches the app's bundle identifier in Xcode (target → General → Identity).
5. The file must include `CLIENT_ID` and `REVERSED_CLIENT_ID`. If it doesn't, enable the **Google** sign-in provider in Firebase (Authentication → Sign-in method) and download the file again.

### If you use a different Firebase project

Open `GPS_Mapping/Info.plist` and replace the URL scheme under `CFBundleURLTypes` with the new file's `REVERSED_CLIENT_ID` value. Google Sign-In uses it to return to the app after you sign in.

## Firestore data

| Collection | Contents |
| --- | --- |
| `unique_days` | One document per day with GPS data. The **document ID** is the date as `YYYY_MM_DD`. Other fields (such as `TTL` and `num_records`) are not required. |
| `gps_locations` | One document per GPS fix. Needs a `dt` **Timestamp** and a position: either a Firestore `GeoPoint` field, or numeric `lat`/`latitude` and `lon`/`lng`/`longitude` fields. Fixes at exactly 0,0 are ignored. |

A "day" runs from local midnight to the next local midnight on the device.

### Security rules

Restrict reads to the Google accounts you trust, for example:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{collection}/{doc} {
      allow read: if request.auth != null
                  && request.auth.token.email_verified == true
                  && request.auth.token.email in [
                       "you@example.com"
                     ]
                  && collection in ['unique_days', 'gps_locations'];
      allow write: if false;
    }
  }
}
```

## Running

1. Open `GPS_Mapping.xcodeproj` in Xcode and let it resolve the Swift packages.
2. Choose a destination (an iPad, a simulator, or My Mac) and press Run.

On a **physical device**, turn on Developer Mode (Settings → Privacy & Security) and keep the device unlocked and connected the first time you run.

The Mac build relies on two settings already in the project: the **Outgoing Connections (Client)** App Sandbox option, and the keychain entitlement in `GPS_Mapping.entitlements`.

## Project layout

| Path | Purpose |
| --- | --- |
| `App/MyApp.swift` | App entry point; configures Firebase and Google Sign-In |
| `Services/AuthManager.swift` | Google sign-in, Firebase sign-in, sign-out |
| `Services/FirestoreDataManager.swift` | Reads `unique_days` and `gps_locations`; date, coordinate, and distance helpers |
| `Views/LoginView.swift` | Sign-in screen |
| `Views/DashboardView.swift` | Main screen: calendar, route summary, map |
| `Views/CalendarPickerView.swift` | Calendar where only days with data can be chosen |
| `Views/LocationsMapView.swift` | Map of a day's route |
| `Views/ProfileMenuView.swift` | Profile picture and Sign Out menu |
