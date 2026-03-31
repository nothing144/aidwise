# Aidwise V2 — "Aegis Zero" Feature Documentation

Aidwise V2 is built around an **Offline-First, Resilient Architecture** designed specifically for disaster zones with zero internet connectivity.

Here is a breakdown of the core logic and features powering the platform:

---

## 1. P2P Mesh Network Engine (`OfflineSyncService`)
The backbone of Aidwise offline capabilities, utilizing the `nearby_connections` protocol to create a self-healing local network.

*   **Epidemic Routing (Data Muling):** Devices act as nodes. If Volunteer A is deep in a blackout zone and logs a report, they broadcast it via Bluetooth/Wi-Fi Direct. If Volunteer B comes into range, Volunteer B caches the payload. When Volunteer B returns to the Admin hub, the payload is delivered.
*   **Dual-Queue Syncing:** All actions (reports, dispatches, status updates) are queued locally using `SharedPreferences`. The app constantly monitors `hasInternet()`. The moment connectivity is restored, the queue is symmetrically flushed to Firebase Firestore.
*   **Payload Serialization:** Data is structured with unique `_meshId` and `_timestamp` identifiers to prevent infinite loop broadcasting and duplicate Firestore entries.

## 2. Edge AI Semantic Matcher (`OfflineMatchingEngine`)
A completely offline NLP (Natural Language Processing) engine that matches incoming SOS reports to the best available volunteers.

*   **TF-IDF Vectorization:** The app tokenizes and vectorizes volunteer skills, resources, and vehicle types directly on the device—no external API calls required.
*   **Cosine Similarity Scoring:** Automatically cross-references the required urgency, resources, and text-descriptions from the Field Report against the mathematical profiles of nearby volunteers, generating a `[0-100%]` Match Score.
*   **Offline Dispatch Routing:** If the admin dispatches a matched volunteer during a blackout, the engine bypasses Firestore and routes the dispatch payload directly into the P2P Mesh network. 

## 3. Intelligent AI Field Scanner 
A digitization tool for field workers to instantly process physical paper reports into structured digital triage data.

*   **Offline-Safe UI:** Features aggressive connection checking. If the internet drops during a scan, network images and cloud calls are dynamically bypassed to show solid-color fallbacks, keeping the UI at 60fps without timeouts.
*   **Structured Output:** Generates strictly formatted tags (e.g., `LOCATION`, `RESOURCE NEED`, `CRITICAL URGENCY`) from unstructured inputs. 

## 4. Hardened Mission Lifecycle Tracking
Closing the loop between admin dispatch and volunteer completion.

*   **Continuous Listeners:** Volunteers use `ValueNotifier` hooks in their dashboards that instantly trigger pop-up navigation workflows the second a mesh payload targets their `volunteerId`. 
*   **Coordinates Fallback System:** Prevents the app from routing volunteers to default `0.0, 0.0` GPS ghost locations by gracefully shifting the UI to a textual Location Description protocol when lat/long isn't available.
*   **Mesh Status Bubble-Up:** When a volunteer clicks "Complete Mission" offline, the system catches the Firestore crash gracefully, queues the completion status locally, and fires a `sendStatusUpdateViaMesh()` payload. This payload hops back through the mesh until it reaches the Admin's "Mesh Inbox".

## 5. Aidwise Command Analytics
The central hub for NGO administrators to manage chaos.

*   **Live Heatmap Dashboards:** Stream counts of "Unprocessed Reports", "Critical Hotspots", and "Active Volunteers" using real-time Firestore listeners.
*   **Responsive Priority Layouts:** Admin widgets (like the AI Priority Rankings) utilize complex `Flexible` and `Wrap` layouts to prevent UI overflow fragmentation across various ruggedized tablet and smartphone dimensions.
*   **Secure Authentication State:** The `AuthService` handles extreme edge cases, such as "Race Conditions" during sign-up, repeatedly retrying database pulls to ensure the Admin dashboard loads securely even under high network latency.
