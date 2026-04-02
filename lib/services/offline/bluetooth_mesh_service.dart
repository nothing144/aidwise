import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:flutter/foundation.dart';
import '../../models/offline/node_info.dart';
import '../../models/offline/offline_message.dart';
import '../../models/offline/routing_table.dart';
import 'offline_queue_service.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class BluetoothMeshService {
  final RoutingTable routingTable = RoutingTable();
  
  final _msgController = StreamController<OfflineMessage>.broadcast();
  Stream<OfflineMessage> get onMessageReceived => _msgController.stream;

  final _nodeDiscoveredController = StreamController<NodeInfo>.broadcast();
  Stream<NodeInfo> get onNodeDiscovered => _nodeDiscoveredController.stream;

  final _nodeLostController = StreamController<String>.broadcast();
  Stream<String> get onNodeLost => _nodeLostController.stream;

  final Strategy strategy = Strategy.P2P_STAR;
  String get _localId => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  bool _isAdvertising = false;
  bool _isScanning = false;
  
  String? _currentHostNodeId;
  final Map<String, String> _connectedEndpoints = {}; // endpointId -> nodeId

  Future<void> start({required bool isHost}) async {
    if (isHost) {
      await startAdvertising();
    } else {
      await startScanning();
    }
  }

  Future<void> startAdvertising() async {
    if (_isAdvertising) return;
    try {
      bool a = await Nearby().startAdvertising(
        _localId,
        strategy,
        onConnectionInitiated: (id, info) async {
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endId, payload) {
              if (payload.type == PayloadType.BYTES) {
                _handleIncomingBytes(payload.bytes!);
              }
            },
            onPayloadTransferUpdate: (endId, payloadTransferUpdate) {},
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpoints[id] = 'unknown'; // Needs heartbeat to resolve
          } else {
            _connectedEndpoints.remove(id);
          }
        },
        onDisconnected: (id) {
          _connectedEndpoints.remove(id);
          _evaluateHostFallback();
        },
      );
      _isAdvertising = a;
    } catch (e) {
      debugPrint('Advertising failed: $e');
    }
  }

  Future<void> startScanning() async {
    if (_isScanning) return;
    try {
      bool s = await Nearby().startDiscovery(
        _localId,
        strategy,
        onEndpointFound: (id, name, serviceId) async {
          // name is nodeId of advertiser
          Nearby().requestConnection(
            _localId,
            id,
            onConnectionInitiated: (id, info) async {
              await Nearby().acceptConnection(
                id,
                onPayLoadRecieved: (endId, payload) {
                  if (payload.type == PayloadType.BYTES) {
                    _handleIncomingBytes(payload.bytes!);
                  }
                },
                onPayloadTransferUpdate: (endId, update) {},
              );
            },
            onConnectionResult: (id, status) {
              if (status == Status.CONNECTED) {
                _connectedEndpoints[id] = name;
                _currentHostNodeId = name;
              }
            },
            onDisconnected: (id) {
              _connectedEndpoints.remove(id);
              if (_currentHostNodeId == id) {
                 _currentHostNodeId = null;
                 _evaluateHostFallback();
              }
            },
          );
        },
        onEndpointLost: (id) {
           _connectedEndpoints.remove(id);
           if (_currentHostNodeId == id) {
                 _currentHostNodeId = null;
                 _evaluateHostFallback();
           }
        },
      );
      _isScanning = s;
    } catch (e) {
      debugPrint('Discovery failed: $e');
    }
  }

  void _handleIncomingBytes(Uint8List bytes) {
    try {
      final jsonStr = utf8.decode(bytes);
      final map = jsonDecode(jsonStr);
      final msg = OfflineMessage.fromJson(map);

      if (msg.seenByNodes.contains(_localId) || msg.hopCount >= 5) {
        return; // Drop
      }

      msg.seenByNodes.add(_localId);
      msg.hopCount++;

      // If Heartbeat, process it for routing table
      if (msg.type == MessageType.heartbeat) {
        final info = NodeInfo(
          nodeId: msg.fromNodeId,
          role: NodeRole.values.byName(msg.payload['role']),
          name: msg.payload['name'],
          status: NodeStatus.online,
          lastSeen: DateTime.now(),
          isDirectlyReachable: msg.hopCount == 1,
          reachableVia: msg.hopCount == 1 ? null : msg.seenByNodes[msg.seenByNodes.length - 2],
        );
        routingTable.updateFromHeartbeat(info);
        _nodeDiscoveredController.add(info);
      }

      _msgController.add(msg);

      if (msg.toNodeId == _localId) {
        // Destination Reached
        if (msg.type != MessageType.ack && msg.type != MessageType.heartbeat) {
           _sendAck(msg.msgId, msg.fromNodeId);
        }
      } else {
        // Relay further if not for me
        sendMessage(msg);
      }
    } catch (e) {
      debugPrint("Mesh Parse Error: $e");
    }
  }

  void _sendAck(String originalMsgId, String originalSender) {
    final ackMsg = OfflineMessage(
      msgId: const Uuid().v4(),
      fromNodeId: _localId,
      toNodeId: originalSender,
      payload: {'ackFor': originalMsgId},
      type: MessageType.ack,
      timestamp: DateTime.now(),
      ttl: const Duration(minutes: 5),
      seenByNodes: [_localId],
    );
    sendMessage(ackMsg);
  }

  Future<void> sendMessage(OfflineMessage msg) async {
     try {
       final payloadData = Uint8List.fromList(utf8.encode(jsonEncode(msg.toJson())));
       
       if (msg.toNodeId == 'broadcast') {
          for (var endpointId in _connectedEndpoints.keys) {
            await Nearby().sendBytesPayload(endpointId, payloadData);
          }
          return;
       }

       final targetRoute = routingTable.bestRouteFor(msg.toNodeId);
       if (targetRoute != null && targetRoute.status == NodeStatus.online) {
         final endpointId = _connectedEndpoints.entries.firstWhere((e) => e.value == (targetRoute.reachableVia ?? targetRoute.nodeId), orElse: () => const MapEntry('', '')).key;
         
         if (endpointId.isNotEmpty) {
           await Nearby().sendBytesPayload(endpointId, payloadData);
         }
       } else {
         // Target offline, queue locally
         GetIt.I<OfflineQueueService>().enqueue(msg);
       }
     } catch (e) {
        GetIt.I<OfflineQueueService>().enqueue(msg);
     }
  }

  void _evaluateHostFallback() {
    // If admin goes offline, a worker with highest lastSeen and most connections assumes host
    String bestFallback = '';
    DateTime latest = DateTime(2000);

    for (var node in routingTable.nodes.values) {
      if (node.role == NodeRole.worker && node.status == NodeStatus.online) {
        if (node.lastSeen.isAfter(latest)) {
          latest = node.lastSeen;
          bestFallback = node.nodeId;
        }
      }
    }

    if (bestFallback == _localId) {
      stopDiscovery();
      startAdvertising();
    } else if (bestFallback.isNotEmpty) {
      // Assuming other device has taken over, wait and reconnect automatically
    }
  }

  void stopDiscovery() {
    Nearby().stopDiscovery();
    _isScanning = false;
  }
}
