# Aidwise Project Status Report

This document serves as the master status report for the **Aidwise V2 "Aegis Zero"** codebase, intended for teammate hand-offs. It tracks the completion state of every core service, screen, and feature.

---

## ✅ 1. Built, Hardened, and Working

These components have been implemented, tested for offline-resilience, and are considered production-ready for the current scope.

### Core Services & Engines
- **`lib/services/offline_sync_service.dart`**: The backbone of the P2P mesh network. Successfully handles Epidemic Routing, dual-queue syncing to Firestore, idempotent deduplication (preventing duplicate cloud creates), and Hive-based data vault caching.
- **`lib/services/offline_matching_engine.dart`**: The Edge AI semantic matcher. Successfully runs TF-IDF vectorization locally and applies Geo-Aware Euclidean distance penalties to volunteer scores.
- **`lib/services/ai_service.dart`**: Connects to the Gemini API for semantic parsing of text and images. Extracts confidence scores correctly for automated triage workflows.
- **`lib/services/auth_service.dart`**: Manages Firebase Authentication and role-based metadata fetching.

### Admin / NGO Screens
- **`lib/screens/admin_hub_screen.dart`**: The primary tab shell container for the Admin workflow.
- **`lib/screens/admin_mesh_inbox_screen.dart`**: The "Mission Control" triage center. Dynamically updates via the P2P mesh payload feed. Successfully splits records into "Needs Review" (manual approval) and "Auto-Synced" (high confidence $ \ge 0.6 $) queues.
- **`lib/screens/smart_matcher_screen.dart`**: The offline dispatch UI. Successfully parses `OfflineMatchingEngine` data to allow Admins to route missions to volunteers seamlessly without cloud access.
- **`lib/screens/heatmap_dashboard.dart`**: General map dashboard visualizer for active incidents.
- **`lib/screens/admin_reports_tab.dart`**: Pinned reports lists for office use.

### Field Worker Screens
- **`lib/screens/ai_scanner_screen.dart`**: The primary data entry node for Field Workers. Includes MLKit Image Labeling, Text Recognition, and connection-aware fallbacks that maintain 60fps UI performance even when the network drops mid-scan.

### Volunteer Screens
- **`lib/screens/volunteer_dashboard_screen.dart`**: Volunteer waiting lobby. Successfully intercepts mesh dispatches via `ValueNotifier` hooks.
- **`lib/screens/volunteer_offline_mission_screen.dart`**: Active mission workflow. Includes the newly working "Ping Target for Coordinates" mesh protocol to retrieve missing GPS data and "Mission Accomplished" mesh relay.
- **`lib/screens/data_vault_tab.dart`**: Offline archive. Fetches the 50 most recent cached Firestore records via Hive when the user is completely offline, complete with an offline status banner.

---

## ⚠️ 2. Built, But Incomplete / Needs Work (Technical Debt)

These components exist in the codebase but have known issues, incomplete functionality, or require cleanup before a massive scale-up.

### Known Issues & Minor Broken Features
- **Android Gradle / Kotlin Daemon Warnings**: As noted in recent analysis, the build cache frequently throws `this and base files have different roots` related to `flutter_plugin_android_lifecycle`. Requires a deep `flutter clean` and build cache wipe to resolve instability.
- **`lib/screens/demo_launcher.dart`**: This screen is primarily a debugging scaffold. It hasn't been hardened into a true user-facing tutorial layout and is safe to ignore or refactor.
- **`lib/screens/analytics_dashboard_tab.dart`**: Exists in the UI but currently lacks deep integration with real-time aggregate Firestore metrics (e.g., dynamically charting aid delivery times over 30 days). Relies on heavy mockup data.

### Architectural Incompleteness
- **Mesh Payload TTL Cleanup (`OfflineSyncService`)**: The Epidemic Routing protocol currently stores payloads indefinitely in `SharedPreferences` as it mules them. It desperately needs a Time-To-Live (TTL) cleanup loop to delete payloads older than 48+ hours to prevent device storage bloating on heavy use.
- **Single Admin Sink Assumption**: The current mesh sync logic assumes *any* connected admin can serve as a sink. In a multi-NGO scenario, this could cause conflicts if Admin A and Admin B try to approve the exact same mesh payload. Idempotency helps, but a true locking mechanism isn't implemented.

---

## ❌ 3. Not Built Yet (Future Roadmap)

These are planned architectural features necessary for the ultimate vision of Aidwise, but which do not currently exist in the `lib` folder in any capacity.

### Future Features
- **Fully Local LLM Triage (`ai_scanner_screen.dart` expansion)**: Currently, if the user is offline, the AI scanner falls back to standard text extraction. A local, quantized TinyML/Gemini Nano approach for complete offline semantic categorization without an API key has not been built yet.
- **Pre-emptive Map Tile Caching**: The Google Maps integration does not dynamically cache maps of "Disaster Zones" before a worker goes offline. If a volunteer hasn't opened Google Maps recently, their mission screen will just show a blank grid instead of roads. Needs a foreground map-tile pre-fetcher.
- **Biometric Audit Trails**: The "Mission Accomplished" logic trusts the volunteer button press. Proof of Delivery (e.g., an offline captured image, signature, or biometric hash) attached to the completion payload has not been developed.
- **Mesh Hop UI Visualization**: The system backend tracks how many "Network Hops" a payload takes to reach the Admin Inbox, but there is no Admin UI screen built yet to visualize this mesh network health/freshness visually.
