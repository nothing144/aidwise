# Project Roadmap & Remaining Tasks

This document tracks technical debt, requested enhancements, and future scalability goals for the **Aidwise V2** platform.

## 🛠 Critical Technical Debt

### 1. Android Build Stability
- **Issue**: Kotlin daemon warnings regarding `flutter_plugin_android_lifecycle` path roots (`this and base files have different roots`).
- **Fix**: Resolve the conflict between the local build cache (`build/`) and the pub cache. This likely requires a `flutter clean` combined with an explicit Gradle sync or dependency override in `android/build.gradle`.

### 2. Mesh Payload Cleanup
- **Issue**: The current mesh logic uses "Epidemic Routing" (relaying everything). While robust, it can lead to high storage usage on "mule" devices over time.
- **Fix**: Implement a TTL (Time-To-Live) cleanup task in `OfflineSyncService` that purges `SharedPreferences` records older than 48 hours.

---

## 🚀 Future Feature Roadmap

### 1. Advanced Offline Triage (Local LLM)
- Move beyond static confidence scores. Explore integrating a quantized TinyML or local LLM (like Gemini Nano on supported devices) to categorize reports while completely offline.

### 2. Pre-emptive Map Caching
- Allow Admins to define "Hotspot Zones" (e.g., a 5km radius).
- When a Volunteer is online, the app should automatically pre-fetch and cache Google Maps tiles for those specific zones so they are available offline during missions.

### 3. Biometric Mission Verification
- Add a "Witness Verification" step for "Mission Accomplished".
- Allow volunteers to capture a signature or 1:1 photo that is hashed and attached to the report for audit trails.

### 4. Mesh Hop Visualization
- Update the Admin Inbox to show the "Network Path" of a report (e.g., "FieldWorker -> Mule_1 -> Admin").
- Use the `_meshHops` metadata to display a "Network Freshness" indicator.

### 5. Multi-Node Admin Sinks
- Currently, the architecture assumes one Admin "Sink". 
- Update the logic to allow multiple regional Admin Hubs to synchronize with each other via both Mesh and Firestore.
