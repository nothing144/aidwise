import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Offline P2P Mesh Sync Service
/// Handles Bluetooth/WiFi-Direct based report transfer between devices.
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _serviceId = 'com.aidwise.mesh';
  static const String _queueKey = 'offline_report_queue';
  static const Strategy _strategy = Strategy.P2P_STAR;

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
    // Add metadata for mesh routing
    reportData['_meshId'] = DateTime.now().millisecondsSinceEpoch.toString();
    reportData['_meshOrigin'] = _userName;
    reportData['_meshTimestamp'] = DateTime.now().toIso8601String();
    reportData['_meshHops'] = 0;
    reportData['_meshMaxHops'] = 10;
    reportData['_meshTTLHours'] = 24;

    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    queue.add(jsonEncode(reportData));
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

  // ────────── INTERNET CHECK ──────────

  /// Check if device currently has internet connectivity.
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
            // Auto-send pending reports once connected
            _sendAllPendingReports();
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

  /// Sends all pending offline reports to the connected Admin.
  Future<void> _sendAllPendingReports() async {
    if (_connectedEndpointId == null || pendingReports.value.isEmpty) return;
    
    syncStatus.value = 'SENDING';
    try {
      // Serialize all reports into a single JSON array
      String jsonData = jsonEncode(pendingReports.value);
      Uint8List bytes = Uint8List.fromList(utf8.encode(jsonData));
      
      await Nearby().sendBytesPayload(_connectedEndpointId!, bytes);
      
      syncStatus.value = 'SENT_SUCCESS';
      // Clear the queue after successful send
      await _clearQueue();
      debugPrint('[MESH] Successfully sent ${pendingReports.value.length} reports');
    } catch (e) {
      syncStatus.value = 'SEND_FAILED';
      debugPrint('[MESH] Send error: $e');
    }
  }

  /// Handle received data payload (Admin side).
  void _handleReceivedPayload(Payload payload) async {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) return;

    try {
      String jsonStr = utf8.decode(payload.bytes!);
      List<dynamic> reports = jsonDecode(jsonStr);
      
      syncStatus.value = 'RECEIVING';
      debugPrint('[MESH] Received ${reports.length} reports via P2P mesh');

      // Try to upload to Firestore immediately (if Admin has internet)
      bool online = await hasInternet();
      
      for (var report in reports) {
        Map<String, dynamic> reportData = Map<String, dynamic>.from(report);
        // Remove mesh metadata before saving to Firestore
        reportData.remove('_meshId');
        reportData.remove('_meshOrigin');
        reportData.remove('_meshHops');
        reportData.remove('_meshMaxHops');
        reportData.remove('_meshTTLHours');
        // Keep _meshTimestamp as the original timestamp
        String? meshTs = reportData.remove('_meshTimestamp');
        
        if (online) {
          // Save directly to Firestore
          reportData['source'] = '${reportData['source'] ?? 'Field Worker'} (via P2P Mesh)';
          reportData['timestamp'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance.collection('reports').add(reportData);
          debugPrint('[MESH] Report saved to Firestore');
        } else {
          // Admin is also offline — queue it here too
          reportData['source'] = '${reportData['source'] ?? 'Field Worker'} (via P2P Mesh)';
          reportData['timestamp'] = meshTs;
          await queueReportOffline(reportData);
          debugPrint('[MESH] Admin offline — report queued locally');
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
    if (pendingReports.value.isEmpty) return;
    bool online = await hasInternet();
    if (!online) return;

    syncStatus.value = 'UPLOADING';
    List<Map<String, dynamic>> toSync = List.from(pendingReports.value);
    
    for (var report in toSync) {
      try {
        Map<String, dynamic> cleaned = Map<String, dynamic>.from(report);
        cleaned.remove('_meshId');
        cleaned.remove('_meshOrigin');
        cleaned.remove('_meshHops');
        cleaned.remove('_meshMaxHops');
        cleaned.remove('_meshTTLHours');
        cleaned.remove('_meshTimestamp');
        cleaned['timestamp'] = FieldValue.serverTimestamp();
        
        await FirebaseFirestore.instance.collection('reports').add(cleaned);
      } catch (e) {
        debugPrint('[MESH] Firestore sync error: $e');
        return; // Stop on first failure, will retry later
      }
    }
    
    await _clearQueue();
    syncStatus.value = 'SYNC_COMPLETE';
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
