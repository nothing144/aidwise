# Aidwise V2 — "Aegis Zero" Full Codebase & Architecture Guide

Welcome, Teammate AI Agents and Developers! This document provides a complete, up-to-date picture of the **Aidwise V2** Disaster Coordination Platform, including its offline-first mesh network, AI engines, database schema, and role-based architecture.

---

## 🏗 System Architecture & Routing

The app uses `AuthWrapper` in `main.dart` to determine routing based on `Firebase Auth` and user roles stored in the `users` Firestore collection. 

There are 3 primary roles:
1. **Admin / NGO** -> `AdminHubScreen`
2. **Field Worker** -> `AIScannerScreen`
3. **Volunteer** -> `VolunteerDashboardScreen`

---

## 🔥 Features by Role

### 1. Admin / NGO (`AdminHubScreen`)
The Admin Hub is a 3-tab BottomNavigationBar setup:
- **Tab 1: AI Field Reports (`HeatmapDashboard`)**: A list of *all* problems reported by Field Workers. The UI is categorized by an AI Priority Engine tracking Active Volunteers, Critical Hotspots, and Unprocessed Reports. Selecting a report drills down to the `ReportDetailMapScreen`.
- **Tab 2: Report Inbox (`AdminReportsTab`)**: A strictly filtered list of *only* problems manually pinned by Admins from the office. Features a **Geocoding Search Bar** allowing Admins to search for a location by typing (e.g., "New Delhi Hospital") and drop a pin.
- **Tab 3: Mission Control (`AdminMeshInboxScreen`)**: A live-feed triage center that dynamically updates via Mesh. Includes **"Needs Review"** (Gemini < 0.6) and **"Auto-Synced"** (High Confidence) partitions.

### 2. Field Worker (`AIScannerScreen`)
- Field workers use the device camera or gallery to capture images of disaster zones or physical paper reports.
- **Intelligent AI Extraction:** Extracts structured data (Need, Location, Urgency, Tags) from physical paper forms.
- **Offline-Safe UI:** Features aggressive connection checking. If the internet drops during a scan, network images and cloud calls are dynamically bypassed to show solid-color fallbacks, keeping the UI at 60fps without timeouts.
- On submission, reports are saved to Firestore with `status: 'Open'` and `source: 'Field Worker'`.

### 3. Volunteer (`VolunteerDashboardScreen` -> `VolunteerTerminalScreen`)
- Volunteers wait on their dashboard until an Admin dispatches them.
- Once dispatched (via `SmartMatcherScreen`), a Mission document is created linking the volunteer to the report.
- The UI shows a "Swipe to Accept" slider, an embedded Google Map of the incident zone, and "Impact XP / Time Remaining" stats.
- Volunteers can press **"Open in Native Maps"** or **"Mission Accomplished"** (which completes the mission and sets the report to resolved).

---

## 📡 Under-The-Hood Engines & Offline Capabilities

Aidwise V2 is built around an **Offline-First, Resilient Architecture** designed specifically for disaster zones with zero internet connectivity.

### 1. P2P Mesh Network Engine (`OfflineSyncService`)
The backbone of Aidwise offline capabilities, utilizing the `nearby_connections` protocol to create a self-healing local network via Bluetooth/Wi-Fi Direct.
*   **Epidemic Routing (Data Muling):** Devices act as nodes. If Volunteer A logs a report offline, they broadcast it. Delivery happens when *any* mule reaches an Admin "Sink" node.
*   **Idempotent Deduplication:** Uses unique `_meshId` as the Firestore document ID with `merge: true`. This prevents duplicates even if multiple mules sync the same report simultaneously.
*   **Offline Data Vault (Hive Cache):** Persists the **last 50 Firestore records** locally. If the internet fails, the Data Vault tab fallbacks to this Hive-backed cache with a sync status banner.

### 2. Edge AI Semantic Matcher (`OfflineMatchingEngine`)
A completely offline NLP (Natural Language Processing) engine that matches incoming SOS reports to the best available volunteers.
*   **TF-IDF Vectorization:** Tokenizes and vectorizes volunteer skills directly on-device.
*   **Geo-Aware Distance Penalty:** Match scores are mathematically penalized based on the distance between the volunteer and the incident, prioritizing the closest responders.
*   **Offline Dispatch Routing:** Admins can dispatch volunteers during a blackout; the engine routes the payload directly into the P2P Mesh. 

### 3. Hardened Mission Lifecycle Tracking
Closing the loop between admin dispatch and volunteer completion, even entirely offline.
*   **Continuous Listeners:** Volunteers use `ValueNotifier` hooks in their dashboards that instantly trigger pop-up navigation workflows the second a mesh payload targets their `volunteerId`. 
*   **Coordinates Fallback System:** Prevents the app from routing volunteers to ghost locations (`0.0, 0.0`) by gracefully shifting the UI to a textual Location Description protocol when lat/long isn't available.
*   **Mesh Status Bubble-Up:** When a volunteer clicks "Mission Accomplished" offline, the system catches the Firestore failure gracefully, queues the completion status locally, and fires a `sendStatusUpdateViaMesh()` payload. This payload hops back through the mesh until it reaches the Admin's "Mission Control" inbox.

---

## 🗄 Firestore Database Schema

### `users` collection:
- `email`: string
- `role`: string ('Admin / NGO', 'Field Worker', 'Volunteer')
- `fullName`: string
- `displayName`: string (Synchronized to Firebase Auth profile for mesh broadcasts)
- `createdAt`: timestamp

### `reports` collection:
- `type`: string (e.g., "Medical Emergency")
- `location`: string (e.g., "Sector 4")
- `latitude`: double
- `longitude`: double
- `urgency`: string ("High", "Medium", "Low")
- `status`: string ("Open", "Assigned", "Resolved")
- `source`: string (e.g., "Admin Dashboard" or "Field Scanner")
- `timestamp`: server timestamp

### `missions` collection:
- `reportId`: document ID of the associated report
- `assignedVolunteerId`: document ID of the assigned user
- `matchScore`: double (e.g., 90.5)
- `status`: string ("Pending", "Completed")
- `timestamp`: server timestamp

---

## 🎨 Design System ("Stitch" UI)

The app uses a premium, dark-mode cyber aesthetic defined in `lib/theme/app_theme.dart`.
- **Primary Color:** Cyan (`#00E5FF`)
- **Secondary Color:** Magenta (`#FF007F`)
- **Card Styling:** Glassmorphism (`AppTheme.stitchCard`) and specific left-border highlights (`AppTheme.stitchCardWithLeftBorder`).
- **Gradients:** `AppTheme.cyanMagentaGradient` used heavily on confirmation buttons (like Dispatch or Confirm Location).
- **Responsive Layouts:** Complex `Flexible` and `Wrap` layouts prevent UI overflow fragmentation across various ruggedized tablet and smartphone dimensions.

---

## 🚀 Getting Started for Backend Migration

If you need to connect this Flutter app to a new Firebase project:
1. Ensure you have created a project in the Firebase Web Console.
2. Open terminal and run `firebase login` to authenticate.
3. Run `flutterfire configure` in the terminal and select the new shared project.
4. Update Firebase Security Rules to match the schema above.
