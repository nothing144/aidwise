# Aidwise V2 - Full Codebase & Architecture Guide

Welcome, Teammate AI Agents! This document is designed to give you a complete, up-to-date picture of the **Aidwise V2** Disaster Coordination Platform so you can instantly resume work.

---

## 🏗 System Architecture & Routing

The app uses [AuthWrapper](file:///d:/ProjectOutOfBox/aidwise/lib/main.dart#34-72) in [main.dart](file:///d:/ProjectOutOfBox/aidwise/lib/main.dart) to determine routing based on `Firebase Auth` and user roles stored in the `users` Firestore collection. 

There are 3 primary roles:
1. **Admin / NGO** -> [AdminHubScreen](file:///d:/ProjectOutOfBox/aidwise/lib/screens/admin_hub_screen.dart#8-14)
2. **Field Worker** -> [AIScannerScreen](file:///d:/ProjectOutOfBox/aidwise/lib/screens/ai_scanner_screen.dart#9-17)
3. **Volunteer** -> [VolunteerDashboardScreen](file:///d:/ProjectOutOfBox/aidwise/lib/screens/volunteer_dashboard_screen.dart#8-192)

---

## 🔥 Features by Role

### 1. Admin / NGO ([AdminHubScreen](file:///d:/ProjectOutOfBox/aidwise/lib/screens/admin_hub_screen.dart#8-14))
The Admin Hub is a 3-tab BottomNavigationBar setup:
- **Tab 1: AI Field Reports ([HeatmapDashboard](file:///d:/ProjectOutOfBox/aidwise/lib/screens/heatmap_dashboard.dart#8-248))**: A list of *all* problems reported by Field Workers. The UI is categorized by an AI Priority Engine. Selecting a report drills down to [ReportDetailMapScreen](file:///d:/ProjectOutOfBox/aidwise/lib/screens/report_detail_map_screen.dart#6-143).
- **Tab 2: Report Inbox ([AdminReportsTab](file:///d:/ProjectOutOfBox/aidwise/lib/screens/admin_reports_tab.dart#7-99))**: A strictly filtered list of *only* problems manually pinned by Admins from the office.
- **Tab 3: Mission Control**: Tracks dispatched volunteers and their completion statuses.

Admins can also click "Digitize Report" to open [AdminLocationPickerScreen](file:///d:/ProjectOutOfBox/aidwise/lib/screens/admin_location_picker_screen.dart#7-15). We recently added the **Geocoding Search Bar** here to let Admins search for a location by typing (e.g., "New Delhi Hospital") and drop a pin to create an Admin Report.

### 2. Field Worker ([AIScannerScreen](file:///d:/ProjectOutOfBox/aidwise/lib/screens/ai_scanner_screen.dart#9-17))
- Field workers use the device camera or gallery to capture images of disaster zones.
- The UI features a premium "Stitch" design (extraction panel, tag chips, cyan-magenta gradient).
- On submission, reports are saved to Firestore with `status: 'Open'` and `source: 'Field Worker'`.

### 3. Volunteer ([VolunteerDashboardScreen](file:///d:/ProjectOutOfBox/aidwise/lib/screens/volunteer_dashboard_screen.dart#8-192) -> [VolunteerTerminalScreen](file:///d:/ProjectOutOfBox/aidwise/lib/screens/volunteer_terminal.dart#7-28))
- Volunteers wait on their dashboard until an Admin dispatches them.
- Once dispatched (via [SmartMatcherScreen](file:///d:/ProjectOutOfBox/aidwise/lib/screens/smart_matcher_screen.dart#5-20)), a [Mission](file:///d:/ProjectOutOfBox/aidwise/lib/screens/volunteer_terminal.dart#35-55) document is created linking the volunteer to the report.
- The UI shows a "Swipe to Accept" slider, an embedded Google Map of the incident zone, and "Impact XP / Time Remaining" stats.
- Volunteers can press **"Open in Native Maps"** or **"Mission Accomplished"** (which completes the mission and sets the report to resolved).

---

## 🗄 Firestore Database Schema

### `users` collection:
- `email`: string
- `role`: string ('Admin / NGO', 'Field Worker', 'Volunteer')
- `createdAt`: timestamp

### `reports` collection:
- `type`: string (e.g., "Medical Emergency")
- `location`: string (e.g., "Sector 4")
- `latitude`: double
- `longitude`: double
- `urgency`: string ("High", "Medium", "Low")
- `status`: string ("Open", "Resolved")
- `source`: string (e.g., "Admin Dashboard" or "Field Scanner")
- `timestamp`: server timestamp

### `missions` collection:
- `reportId`: document ID of the associated report
- `volunteerId`: document ID of the assigned user
- `status`: string ("Pending", "Assigned", "Completed", "Declined")
- `assignedAt`: server timestamp

---

## 🎨 Design System ("Stitch" UI)
The app uses a premium, dark-mode cyber aesthetic defined in [lib/theme/app_theme.dart](file:///d:/ProjectOutOfBox/aidwise/lib/theme/app_theme.dart).
- **Primary Color:** Cyan (`#00E5FF`)
- **Secondary Color:** Magenta (`#FF007F`)
- **Card Styling:** Glassmorphism (`AppTheme.stitchCard`) and specific left-border highlights (`AppTheme.stitchCardWithLeftBorder`).
- **Gradients:** `AppTheme.cyanMagentaGradient` used heavily on confirmation buttons (like Dispatch or Confirm Location).

## 🚀 Getting Started for Backend Migration
If you need to connect this Flutter app to a new Firebase project:
1. Ensure the user has created the project in the Firebase Web Console.
2. Ensure Firebase CLI is logged into the team owner's Google account (`firebase login`).
3. Run `flutterfire configure` in the terminal and select the new shared project.
4. Update Firebase Security Rules.
