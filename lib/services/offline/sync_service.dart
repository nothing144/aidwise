import 'dart:async';
import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';
import '../../models/offline/sync_snapshot.dart';
import '../../models/offline/offline_message.dart';
import '../../models/offline/node_info.dart';
import 'bluetooth_mesh_service.dart';
import 'offline_queue_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class SyncService {
  final _syncStateController = StreamController<SyncSnapshot>.broadcast();
  Stream<SyncSnapshot> get onSyncStateUpdated => _syncStateController.stream;

  SyncSnapshot? latestSnapshot;
  
  void init() {
    GetIt.I<BluetoothMeshService>().onMessageReceived.listen((msg) {
      if (msg.type == MessageType.syncRequest) {
         _handleSyncRequest(msg);
      } else if (msg.type == MessageType.syncResponse) {
         _handleSyncResponse(msg);
      }
    });
  }

  void requestSync(String targetNodeId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final req = OfflineMessage(
      msgId: const Uuid().v4(),
      fromNodeId: uid,
      toNodeId: targetNodeId,
      payload: {'action': 'requestSync'},
      type: MessageType.syncRequest,
      timestamp: DateTime.now(),
      ttl: const Duration(minutes: 5),
      seenByNodes: [uid],
    );
    GetIt.I<BluetoothMeshService>().sendMessage(req);
  }

  void _handleSyncRequest(OfflineMessage msg) {
    if (latestSnapshot == null) {
      _generateSnapshot();
    }
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || latestSnapshot == null) return;

    final respMsg = OfflineMessage(
      msgId: const Uuid().v4(),
      fromNodeId: uid,
      toNodeId: msg.fromNodeId,
      payload: {'snapshot': latestSnapshot!.toJson()},
      type: MessageType.syncResponse,
      timestamp: DateTime.now(),
      ttl: const Duration(minutes: 5),
      seenByNodes: [uid],
    );
    GetIt.I<BluetoothMeshService>().sendMessage(respMsg);
  }

  void _handleSyncResponse(OfflineMessage msg) {
    try {
      final snapshotData = msg.payload['snapshot'] as Map<String, dynamic>;
      final snapshot = SyncSnapshot.fromJson(snapshotData);
      
      _mergeSnapshot(snapshot);
    } catch (e) {
      debugPrint('Sync merge error: $e');
    }
  }

  void _generateSnapshot() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final statuses = <String, NodeStatus>{};
    GetIt.I<BluetoothMeshService>().routingTable.nodes.forEach((key, value) {
      statuses[key] = value.status;
    });

    latestSnapshot = SyncSnapshot(
      generatedAt: DateTime.now(),
      byNodeId: uid,
      pendingDispatches: GetIt.I<OfflineQueueService>().getAllUnacked(),
      currentAssignments: {}, // Extend logic based on db state
      nodeStatuses: statuses,
    );
    _syncStateController.add(latestSnapshot!);
  }

  void _mergeSnapshot(SyncSnapshot externalSnapshot) {
    if (latestSnapshot == null) {
      latestSnapshot = externalSnapshot;
      _syncStateController.add(latestSnapshot!);
      return;
    }

    if (externalSnapshot.generatedAt.isAfter(latestSnapshot!.generatedAt)) {
      // Last-Writer-Wins tiebreaker for basic logic
      latestSnapshot = externalSnapshot;
      _syncStateController.add(latestSnapshot!);
    }
  }
}
