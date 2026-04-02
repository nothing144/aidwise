import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Offline P2P Mesh Sync Service
/// Handles Bluetooth/WiFi-Direct based report transfer between devices.
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _queueKey = 'offline_report_queue';
  static const Strategy _strategy = Strategy.P2P_STAR;
  static const String _vaultCacheBox = 'vault_reports_cache';
  static const String _lastVaultSyncKey = 'last_vault_sync_timestamp';

  // Callbacks for UI updates
  ValueNotifier<List<Map<String, dynamic>>> pendingReports = ValueNotifier([]);
  ValueNotifier<List<Map<String, String>>> discoveredDevices = ValueNotifier([]);
  ValueNotifier<String> syncStatus = ValueNotifier('IDLE');
  ValueNotifier<bool> isAdvertising = ValueNotifier(false);
  ValueNotifier<bool> isDiscovering = ValueNotifier(false);

  String? _connectedEndpointId;
  String _userName = 'AidwiseUser';
  String _userRole = 'FieldWorker';

  // ────────── INITIALIZATION ──────────

  Future<void> init({required String userName, required String role}) async {
    _userName = userName;
    _userRole = role;
    await _loadPendingReports();
  }

  // ────────── OFFLINE QUEUE MANAGEMENT ──────────

  /// Saves a report to the local offline queue when internet is unavailable.
  Future<void> queueReportOffline(Map<String, dynamic> reportData) async {
    // Add metadata for mesh routing if not present
    if (!reportData.containsKey('_meshId')) {
      reportData['_meshId'] = DateTime.now().millisecondsSinceEpoch.toString();
      reportData['_meshOrigin'] = _userName;
      reportData['_meshTimestamp'] = DateTime.now().toIso8601String();
      reportData['_meshHops'] = 0;
      reportData['_meshMaxHops'] = 10;
      reportData['_meshTTLHours'] = 24;
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    
    // Deduplicate local queue
    bool alreadyExists = false;
    for (int i = 0; i < queue.length; i++) {
        var existing = jsonDecode(queue[i]) as Map<String, dynamic>;
        if (existing['_meshId'] == reportData['_meshId']) {
            queue[i] = jsonEncode(reportData); // Update existing
            alreadyExists = true;
            break;
        }
    }
    
    if (!alreadyExists) {
        queue.add(jsonEncode(reportData));
    }
    
    await prefs.setStringList(_queueKey, queue);
    await _loadPendingReports();
  }

  /// Admin artificially approves a report
  Future<void> approveReport(String meshId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    for (int i = 0; i < queue.length; i++) {
        var report = jsonDecode(queue[i]) as Map<String, dynamic>;
        if (report['_meshId'] == meshId) {
            report['_adminState'] = 'Approved';
            queue[i] = jsonEncode(report);
            break;
        }
    }
    await prefs.setStringList(_queueKey, queue);
    await _loadPendingReports();
    _sendAllPendingData(); // if mules are connected
    trySyncQueueToFirestore(); // sync immediately if online
  }

  /// Admin rejects a report
  Future<void> rejectReport(String meshId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    queue.removeWhere((item) {
       var report = jsonDecode(item) as Map<String, dynamic>;
       return report['_meshId'] == meshId;
    });
    await prefs.setStringList(_queueKey, queue);
    await _loadPendingReports();
  }

  /// Loads pending reports from local storage.
  Future<void> _loadPendingReports() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    pendingReports.value = queue.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  /// Clears all successfully synced reports from the queue.
  Future<void> _clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_queueKey, []);
    pendingReports.value = [];
  }

  /// Returns the count of pending offline reports.
  int get pendingCount => pendingReports.value.length;

  // ────────── VOLUNTEER CACHING ──────────

  static const String _volunteersCacheKey = 'offline_volunteers_cache';

  /// Saves a list of active volunteers from Firestore to local storage
  Future<void> cacheVolunteersOffline(List<Map<String, dynamic>> volunteers) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> encodedList = volunteers.map((v) => jsonEncode(v)).toList();
    await prefs.setStringList(_volunteersCacheKey, encodedList);
    debugPrint('[MESH] Cached ${volunteers.length} volunteers for offline matching.');
  }

  /// Retrieves the cached list of volunteers when offline
  Future<List<Map<String, dynamic>>> getOfflineVolunteers() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> encodedList = prefs.getStringList(_volunteersCacheKey) ?? [];
    return encodedList.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }
  // ────────── OFFLINE DISPATCH (ADMIN -> VOLUNTEER) ──────────

  static const String _dispatchOutboxKey = 'offline_dispatch_outbox';
  static const String _statusUpdatesKey = 'offline_status_updates';
  ValueNotifier<List<Map<String, dynamic>>> pendingDispatches = ValueNotifier([]);
  ValueNotifier<Map<String, dynamic>?> receivedMission = ValueNotifier(null);
  ValueNotifier<List<Map<String, dynamic>>> completedMissions = ValueNotifier([]);

  /// Admin creates a dispatch payload addressed to a specific volunteer
  Future<void> dispatchMissionOffline(Map<String, dynamic> report, String targetVolunteerId, String volunteerName) async {
    Map<String, dynamic> dispatchPayload = {
      ...report,
      '_isDispatch': true,
      '_targetVolunteerId': targetVolunteerId,
      '_targetVolunteerName': volunteerName,
      '_dispatchTimestamp': DateTime.now().toIso8601String(),
      '_meshId': 'DISPATCH_${DateTime.now().millisecondsSinceEpoch}',
    };

    final prefs = await SharedPreferences.getInstance();
    List<String> outbox = prefs.getStringList(_dispatchOutboxKey) ?? [];
    outbox.add(jsonEncode(dispatchPayload));
    await prefs.setStringList(_dispatchOutboxKey, outbox);
    
    await _loadPendingDispatches();
    
    // Attempt to broadcast immediately if connected
    _sendAllPendingData();
  }

  // ────────── STATUS UPDATE (VOLUNTEER -> ADMIN via MESH) ──────────

  /// Volunteer sends a mission completion status back through the mesh.
  Future<void> sendStatusUpdateViaMesh(String missionMeshId, String status) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    Map<String, dynamic> statusPayload = {
      '_isStatusUpdate': true,
      '_meshId': 'STATUS_${DateTime.now().millisecondsSinceEpoch}',
      '_originalMissionMeshId': missionMeshId,
      '_status': status,
      '_volunteerUid': currentUser?.uid ?? 'unknown',
      '_volunteerName': _userName,
      '_completedAt': DateTime.now().toIso8601String(),
    };

    // Store locally so it can be sent via mesh or synced when online
    final prefs = await SharedPreferences.getInstance();
    List<String> updates = prefs.getStringList(_statusUpdatesKey) ?? [];
    updates.add(jsonEncode(statusPayload));
    await prefs.setStringList(_statusUpdatesKey, updates);

    // Also add to dispatch outbox for mesh broadcast
    List<String> outbox = prefs.getStringList(_dispatchOutboxKey) ?? [];
    outbox.add(jsonEncode(statusPayload));
    await prefs.setStringList(_dispatchOutboxKey, outbox);
    await _loadPendingDispatches();

    // Try to broadcast immediately
    _sendAllPendingData();
    debugPrint('[MESH] Status update queued: $status for mission $missionMeshId');
  }

  /// Volunteer sends a ping via the mesh to request coordinates for a specific mission from the original reporter.
  Future<void> sendPingForCoordinatesViaMesh(String missionMeshId) async {
    Map<String, dynamic> pingPayload = {
      '_isPingForCoords': true,
      '_meshId': 'PING_${DateTime.now().millisecondsSinceEpoch}',
      '_targetMissionMeshId': missionMeshId,
      '_volunteerName': _userName,
    };

    final prefs = await SharedPreferences.getInstance();
    // Reusing the dispatch outbox for multi-hop mesh propagation
    List<String> outbox = prefs.getStringList(_dispatchOutboxKey) ?? [];
    outbox.add(jsonEncode(pingPayload));
    await prefs.setStringList(_dispatchOutboxKey, outbox);
    
    await _loadPendingDispatches();
    _sendAllPendingData();
    debugPrint('[MESH] Ping for coordinates queued for mission: $missionMeshId');
  }

  Future<void> _loadPendingDispatches() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> outbox = prefs.getStringList(_dispatchOutboxKey) ?? [];
    pendingDispatches.value = outbox.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }
  static Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi);
  }

  // ────────── ADMIN: ADVERTISE AS SINK NODE ──────────

  /// Admin starts advertising — makes this device discoverable as a data receiver.
  Future<bool> startAdvertising() async {
    try {
      // Encode role in the username so discoverers know this is an Admin
      String advName = 'ADMIN|$_userName';
      
      bool result = await Nearby().startAdvertising(
        advName,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpointId = id;
            syncStatus.value = 'CONNECTED';
            debugPrint('[MESH] Admin connected to: $id');
          } else {
            syncStatus.value = 'CONNECTION_FAILED';
          }
        },
        onDisconnected: (id) {
          _connectedEndpointId = null;
          syncStatus.value = 'DISCONNECTED';
          debugPrint('[MESH] Disconnected from: $id');
        },
        serviceId: _serviceId,
      );
      isAdvertising.value = result;
      syncStatus.value = result ? 'ADVERTISING' : 'FAILED';
      return result;
    } catch (e) {
      debugPrint('[MESH] Advertising error: $e');
      syncStatus.value = 'ERROR';
      return false;
    }
  }

  /// Stop advertising.
  Future<void> stopAdvertising() async {
    await Nearby().stopAdvertising();
    isAdvertising.value = false;
    syncStatus.value = 'IDLE';
  }

  // ────────── FIELD WORKER: DISCOVER & SEND ──────────

  /// Field Worker starts discovering nearby devices.
  Future<bool> startDiscovery() async {
    discoveredDevices.value = [];
    try {
      bool result = await Nearby().startDiscovery(
        'FIELDWORKER|$_userName',
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          debugPrint('[MESH] Found device: $name (ID: $id)');
          // Parse role from broadcast name
          String role = name.split('|').first;
          String displayName = name.split('|').length > 1 ? name.split('|')[1] : name;
          
          discoveredDevices.value = [
            ...discoveredDevices.value,
            {'id': id, 'name': displayName, 'role': role}
          ];

          // Auto-connect to Admin (Sink Node)
          if (role == 'ADMIN') {
            syncStatus.value = 'CONNECTING_TO_ADMIN';
            _requestConnection(id);
          }
        },
        onEndpointLost: (id) {
          discoveredDevices.value = discoveredDevices.value
              .where((d) => d['id'] != id).toList();
        },
        serviceId: _serviceId,
      );
      isDiscovering.value = result;
      syncStatus.value = result ? 'SCANNING' : 'SCAN_FAILED';
      return result;
    } catch (e) {
      debugPrint('[MESH] Discovery error: $e');
      syncStatus.value = 'ERROR';
      return false;
    }
  }

  /// Stop discovering.
  Future<void> stopDiscovery() async {
    await Nearby().stopDiscovery();
    isDiscovering.value = false;
  }

  /// Request connection to a discovered device.
  Future<void> _requestConnection(String endpointId) async {
    try {
      await Nearby().requestConnection(
        'FIELDWORKER|$_userName',
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpointId = id;
            syncStatus.value = 'CONNECTED';
            debugPrint('[MESH] Worker connected to Admin: $id');
            // Auto-send pending reports and dispatches once connected
            _sendAllPendingData();
          } else {
            syncStatus.value = 'CONNECTION_REJECTED';
          }
        },
        onDisconnected: (id) {
          _connectedEndpointId = null;
          syncStatus.value = 'DISCONNECTED';
        },
      );
    } catch (e) {
      debugPrint('[MESH] Connection request error: $e');
    }
  }

  // ────────── CONNECTION HANDLER (Both Sides) ──────────

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    debugPrint('[MESH] Connection initiated with: ${info.endpointName}');
    // Auto-accept all connections from Aidwise devices
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endpointId, payload) {
        _handleReceivedPayload(payload);
      },
    );
  }

  // ────────── DATA TRANSFER ──────────

  /// Sends all pending offline reports and dispatches to the connected device.
  Future<void> _sendAllPendingData() async {
    if (_connectedEndpointId == null) return;
    
    List<Map<String, dynamic>> allData = [
      ...pendingReports.value,
      ...pendingDispatches.value,
    ];

    if (allData.isEmpty) return;
    
    syncStatus.value = 'SENDING';
    try {
      // Serialize all data into a single JSON array
      String jsonData = jsonEncode(allData);
      Uint8List bytes = Uint8List.fromList(utf8.encode(jsonData));
      
      await Nearby().sendBytesPayload(_connectedEndpointId!, bytes);
      
      syncStatus.value = 'SENT_SUCCESS';
      // Clear both report and dispatch queues after successful send
      await _clearQueue();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_dispatchOutboxKey, []);
      pendingDispatches.value = [];
      debugPrint('[MESH] Successfully sent ${allData.length} records');
    } catch (e) {
      syncStatus.value = 'SEND_FAILED';
      debugPrint('[MESH] Send error: $e');
    }
  }

  /// Handle received data payload.
  void _handleReceivedPayload(Payload payload) async {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) return;

    try {
      String jsonStr = utf8.decode(payload.bytes!);
      List<dynamic> records = jsonDecode(jsonStr);
      
      syncStatus.value = 'RECEIVING';
      debugPrint('[MESH] Received ${records.length} records via P2P mesh');

      bool online = await hasInternet();
      final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
      
      for (var record in records) {
        Map<String, dynamic> data = Map<String, dynamic>.from(record);
        
        // 1. Check if this is a STATUS UPDATE (Volunteer -> Admin)
        if (data['_isStatusUpdate'] == true) {
          if (_userRole == 'Admin' || _userRole == 'Admin / NGO') {
            // Admin received completion update!
            bool alreadyHave = completedMissions.value.any((m) => m['_meshId'] == data['_meshId']);
            if (!alreadyHave) {
              completedMissions.value = [...completedMissions.value, data];
              debugPrint('✅ MISSION STATUS UPDATE RECEIVED: ${data['_status']} from ${data['_volunteerName']}');
            }
          } else {
            // Not admin — act as MULE for the status update
            bool hasIt = pendingDispatches.value.any((disp) => disp['_meshId'] == data['_meshId']);
            if (!hasIt) {
              final prefs = await SharedPreferences.getInstance();
              List<String> outbox = prefs.getStringList(_dispatchOutboxKey) ?? [];
              outbox.add(jsonEncode(data));
              await prefs.setStringList(_dispatchOutboxKey, outbox);
              await _loadPendingDispatches();
              debugPrint('[MESH] Epidemic Routing: Forwarding status update as mule');
            }
          }
          continue;
        }

        // 2. Check if this is a DISPATCH mission
        if (data['_isDispatch'] == true) {
          String targetId = data['_targetVolunteerId'] ?? '';
          
          if (targetId == currentUserUid && _userRole == 'Volunteer') {
            // WE are the target! Alert the volunteer!
            if (receivedMission.value == null || receivedMission.value!['_meshId'] != data['_meshId']) {
              receivedMission.value = data;
              debugPrint('🚨 BINGO! MISSION RECEIVED FOR ME: ${data['description']}');
            }
          } else {
            // We are not the target, or we are another role. We act as a MULE.
            bool hasIt = pendingDispatches.value.any((disp) => disp['_meshId'] == data['_meshId']);
            if (!hasIt) {
              final prefs = await SharedPreferences.getInstance();
              List<String> outbox = prefs.getStringList(_dispatchOutboxKey) ?? [];
              outbox.add(jsonEncode(data));
              await prefs.setStringList(_dispatchOutboxKey, outbox);
              await _loadPendingDispatches();
              debugPrint('[MESH] Epidemic Routing: Stored dispatch as mule');
            }
          }
          continue; // Done with this record
        }

        // 3. Otherwise, it's a standard Offline Report
        String meshId = data['_meshId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        
        bool isAdmin = _userRole == 'Admin' || _userRole == 'Admin / NGO';
        double confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
        bool autoApprove = confidence >= 0.6;
        
        if (isAdmin) {
          if (online && autoApprove && data['_adminState'] != 'Auto-Synced') {
            Map<String, dynamic> cleaned = Map<String, dynamic>.from(data);
            cleaned.remove('_meshId');
            cleaned.remove('_meshOrigin');
            cleaned.remove('_meshHops');
            cleaned.remove('_meshMaxHops');
            cleaned.remove('_meshTTLHours');
            cleaned.remove('_meshTimestamp');
            cleaned.remove('_adminState');
            
            cleaned['source'] = '${cleaned['source'] ?? 'Field Worker'} (via P2P Mesh)';
            cleaned['timestamp'] = FieldValue.serverTimestamp();
            
            await FirebaseFirestore.instance.collection('reports').doc(meshId).set(cleaned, SetOptions(merge: true));
            debugPrint('[MESH] Auto-Approved and saved to Firestore (deduped)');
            
            data['_adminState'] = 'Auto-Synced';
            await queueReportOffline(data);
          } else if (data['_adminState'] != 'Auto-Synced') {
            data['_adminState'] = 'Needs Review';
            await queueReportOffline(data);
            debugPrint('[MESH] Queued locally for Admin Review');
          }
        } else {
          // Mule logic
          await queueReportOffline(data);
          debugPrint('[MESH] Relaying admin offline — report queued locally as Mule');
        }
      }
      
      syncStatus.value = online ? 'UPLOAD_SUCCESS' : 'QUEUED_LOCALLY';
    } catch (e) {
      debugPrint('[MESH] Payload parse error: $e');
      syncStatus.value = 'RECEIVE_ERROR';
    }
  }

  // ────────── AUTO-SYNC WHEN INTERNET RETURNS ──────────

  /// Call this periodically or on connectivity change to flush the local queue.
  Future<void> trySyncQueueToFirestore() async {
    bool online = await hasInternet();
    if (!online) return;

    // 1. Sync pending reports
    if (pendingReports.value.isNotEmpty) {
      syncStatus.value = 'UPLOADING';
      List<Map<String, dynamic>> toSync = List.from(pendingReports.value);
      List<String> remainingQueue = [];
      
      bool isAdmin = _userRole == 'Admin' || _userRole == 'Admin / NGO';
      
      for (var report in toSync) {
        try {
          String adminState = report['_adminState'] ?? '';
          
          if (isAdmin && adminState == 'Needs Review') {
            remainingQueue.add(jsonEncode(report));
            continue; // Wait for manual approval via Admin Inbox
          }
          if (isAdmin && adminState == 'Auto-Synced') {
             remainingQueue.add(jsonEncode(report));
             continue; // Already synced, keep it in Inbox for viewing
          }
          
          // Proceed to upload: Mules upload everything, Admins upload 'Approved' or untracked
          Map<String, dynamic> cleaned = Map<String, dynamic>.from(report);
          String meshId = cleaned.remove('_meshId') ?? DateTime.now().millisecondsSinceEpoch.toString();
          
          cleaned.remove('_meshOrigin');
          cleaned.remove('_meshHops');
          cleaned.remove('_meshMaxHops');
          cleaned.remove('_meshTTLHours');
          cleaned.remove('_meshTimestamp');
          cleaned.remove('_adminState');
          
          cleaned['source'] = '${cleaned['source'] ?? 'Field Worker'} (via P2P Mesh)';
          cleaned['timestamp'] = FieldValue.serverTimestamp();
          
          await FirebaseFirestore.instance.collection('reports').doc(meshId).set(cleaned, SetOptions(merge: true));
          
          if (isAdmin) {
            // Admin: Turn to 'Auto-Synced' after manual/approved upload to keep it in inbox
            report['_adminState'] = 'Auto-Synced';
            remainingQueue.add(jsonEncode(report));
          } else {
            // Mule: Remove from queue once successfully uploaded to cloud
          }
        } catch (e) {
          debugPrint('[MESH] Firestore sync error: $e');
          remainingQueue.add(jsonEncode(report)); // Stop on first failure, retry later
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_queueKey, remainingQueue);
      await _loadPendingReports();
    }

    // 2. Sync completed mission status updates to Firestore
    if (completedMissions.value.isNotEmpty) {
      for (var update in completedMissions.value) {
        try {
          String originalMeshId = update['_originalMissionMeshId'] ?? '';
          String status = update['_status'] ?? 'Completed';
          // Find matching mission/report in Firestore and update status
          var reportQuery = await FirebaseFirestore.instance.collection('reports')
              .where('status', isEqualTo: 'Dispatched')
              .get();
          for (var doc in reportQuery.docs) {
            await doc.reference.update({'status': status});
          }
          debugPrint('[MESH] Synced status update to Firestore: $originalMeshId -> $status');
        } catch (e) {
          debugPrint('[MESH] Status sync error: $e');
        }
      }
      completedMissions.value = [];
    }

    // 3. Clear stale dispatch/status mule payloads (no longer needed once online)
    if (pendingDispatches.value.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_dispatchOutboxKey, []);
      await prefs.setStringList(_statusUpdatesKey, []);
      pendingDispatches.value = [];
      debugPrint('[MESH] Cleared stale mesh payloads (online now)');
    }

    syncStatus.value = 'SYNC_COMPLETE';
  }

  // ────────── DATA VAULT CACHING (HIVE) ──────────

  /// Persists the last 50 Firestore records locally for offline viewing.
  Future<void> cacheVaultReports(List<Map<String, dynamic>> reports) async {
    try {
      final box = await Hive.openBox(_vaultCacheBox);
      // Map Firestore Timestamps to ISO strings for Hive storage
      List<Map<String, dynamic>> serializable = reports.map((r) {
        var copy = Map<String, dynamic>.from(r);
        if (copy['timestamp'] is Timestamp) {
          copy['timestamp'] = (copy['timestamp'] as Timestamp).toDate().toIso8601String();
        }
        return copy;
      }).toList();

      await box.put('reports', serializable);
      await setLastVaultSyncTime(DateTime.now());
      debugPrint('[VAULT] Cached ${serializable.length} reports for offline access.');
    } catch (e) {
      debugPrint('[VAULT] Cache Error: $e');
    }
  }

  /// Retrieves cached reports when Firestore is unreachable.
  Future<List<Map<String, dynamic>>> getCachedVaultReports() async {
    try {
      final box = await Hive.openBox(_vaultCacheBox);
      final List<dynamic>? cached = box.get('reports');
      if (cached == null) return [];
      return cached.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('[VAULT] Retrieval Error: $e');
      return [];
    }
  }

  Future<void> setLastVaultSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastVaultSyncKey, time.toIso8601String());
  }

  Future<DateTime?> getLastVaultSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    String? ts = prefs.getString(_lastVaultSyncKey);
    return ts != null ? DateTime.parse(ts) : null;
  }

  // ────────── CLEANUP ──────────

  Future<void> dispose() async {
    await stopAdvertising();
    await stopDiscovery();
    if (_connectedEndpointId != null) {
      Nearby().disconnectFromEndpoint(_connectedEndpointId!);
    }
  }
}
