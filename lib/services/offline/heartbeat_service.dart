import 'dart:async';
import '../../models/offline/node_info.dart';
import '../../models/offline/offline_message.dart';
import 'bluetooth_mesh_service.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class HeartbeatService {
  Timer? _timer;
  final _staleNodeController = StreamController<String>.broadcast();
  
  Stream<String> get onStaleNodeDetected => _staleNodeController.stream;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (t) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final msg = OfflineMessage(
      msgId: const Uuid().v4(),
      fromNodeId: uid,
      toNodeId: 'broadcast',
      payload: {
         // Default role for testing, should link to User model
        'role': NodeRole.worker.name, 
        'name': 'Node_${uid.substring(0, 4)}',
      },
      type: MessageType.heartbeat,
      timestamp: DateTime.now(),
      ttl: const Duration(minutes: 5),
      seenByNodes: [uid],
    );

    await GetIt.I<BluetoothMeshService>().sendMessage(msg);

    // Stale check
    GetIt.I<BluetoothMeshService>().routingTable.nodes.forEach((id, node) {
      if (node.status != NodeStatus.offline && DateTime.now().difference(node.lastSeen).inSeconds > 90) {
         node.status = NodeStatus.offline;
         _staleNodeController.add(id);
      }
    });
  }
}
