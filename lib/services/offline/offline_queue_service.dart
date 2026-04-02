import 'package:hive_flutter/hive_flutter.dart';
import '../../models/offline/offline_message.dart';
import 'package:flutter/foundation.dart';

class OfflineQueueService {
  static const String queueBoxName = 'messageQueue';
  static const String receivedBoxName = 'receivedMessages';
  static const String seenIdsBoxName = 'seenMessageIds';
  
  late Box<OfflineMessage> _queueBox;
  late Box<OfflineMessage> _receivedBox;
  late Box<String> _seenBox; 
  
  final pendingCount = ValueNotifier<int>(0);
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _queueBox = await Hive.openBox<OfflineMessage>(queueBoxName);
    _receivedBox = await Hive.openBox<OfflineMessage>(receivedBoxName);
    _seenBox = await Hive.openBox<String>(seenIdsBoxName);
    
    _updatePendingCount();
    await _purgeOldData();
    _initialized = true;
  }

  void _updatePendingCount() {
    pendingCount.value = _queueBox.values.where((m) => !m.acked).length;
  }

  Future<void> enqueue(OfflineMessage message) async {
    if (hasSeen(message.msgId)) return;
    
    await _queueBox.put(message.msgId, message);
    await markSeen(message.msgId);
    _updatePendingCount();
  }

  Future<void> markAcked(String msgId) async {
    final msg = _queueBox.get(msgId);
    if (msg != null) {
      msg.acked = true;
      await _queueBox.put(msgId, msg);
      _updatePendingCount();
    }
  }

  List<OfflineMessage> getMessagesFor(String nodeId) {
    return _queueBox.values.where((m) => !m.acked && m.toNodeId == nodeId).toList();
  }
  
  List<OfflineMessage> getAllUnacked() {
    return _queueBox.values.where((m) => !m.acked).toList();
  }

  Future<void> remove(String msgId) async {
    await _queueBox.delete(msgId);
    _updatePendingCount();
  }

  bool hasSeen(String msgId) {
    return _seenBox.containsKey(msgId);
  }

  Future<void> markSeen(String msgId) async {
    if (_seenBox.length >= 500) {
      final keysToDelete = _seenBox.keys.take(100).toList();
      await _seenBox.deleteAll(keysToDelete);
    }
    await _seenBox.put(msgId, msgId);
  }

  Future<void> storeReceived(OfflineMessage message) async {
    if (!hasSeen(message.msgId)) {
      await _receivedBox.put(message.msgId, message);
      await markSeen(message.msgId);
    }
  }

  Future<void> _purgeOldData() async {
    final now = DateTime.now();
    final oldReceived = _receivedBox.keys.where((k) {
      final m = _receivedBox.get(k);
      return m != null && now.difference(m.timestamp).inHours > 24;
    }).toList();
    await _receivedBox.deleteAll(oldReceived);

    // Keep queue unacked intact, drop only if explicitly ttl bounds required
  }

  Future<void> flushFor(String nodeId, Function(OfflineMessage) deliverCallback) async {
    final msgs = getMessagesFor(nodeId);
    for (var m in msgs) {
      deliverCallback(m);
    }
  }
}
