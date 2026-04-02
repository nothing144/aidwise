import 'package:hive/hive.dart';
import 'dart:convert';

enum MessageType { heartbeat, dispatch, statusUpdate, ack, relayAck, syncRequest, syncResponse, relayForward }

class OfflineMessage {
  final String msgId;
  final String fromNodeId;
  final String toNodeId;
  final Map<String, dynamic> payload;
  final MessageType type;
  final DateTime timestamp;
  final Duration ttl;
  bool acked;
  int hopCount;
  List<String> seenByNodes;
  int retryCount;

  OfflineMessage({
    required this.msgId,
    required this.fromNodeId,
    required this.toNodeId,
    required this.payload,
    required this.type,
    required this.timestamp,
    required this.ttl,
    this.acked = false,
    this.hopCount = 0,
    required this.seenByNodes,
    this.retryCount = 0,
  });

  factory OfflineMessage.fromJson(Map<String, dynamic> json) {
    return OfflineMessage(
      msgId: json['msgId'] as String,
      fromNodeId: json['fromNodeId'] as String,
      toNodeId: json['toNodeId'] as String,
      payload: jsonDecode(json['payload'] as String) as Map<String, dynamic>,
      type: MessageType.values.byName(json['type'] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      ttl: Duration(milliseconds: json['ttl'] as int),
      acked: json['acked'] as bool,
      hopCount: json['hopCount'] as int,
      seenByNodes: List<String>.from(json['seenByNodes']),
      retryCount: json['retryCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'msgId': msgId,
      'fromNodeId': fromNodeId,
      'toNodeId': toNodeId,
      'payload': jsonEncode(payload),
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'ttl': ttl.inMilliseconds,
      'acked': acked,
      'hopCount': hopCount,
      'seenByNodes': seenByNodes,
      'retryCount': retryCount,
    };
  }
}

class OfflineMessageAdapter extends TypeAdapter<OfflineMessage> {
  @override
  final int typeId = 1;

  @override
  OfflineMessage read(BinaryReader reader) {
    return OfflineMessage(
      msgId: reader.readString(),
      fromNodeId: reader.readString(),
      toNodeId: reader.readString(),
      payload: jsonDecode(reader.readString()) as Map<String, dynamic>,
      type: MessageType.values.byName(reader.readString()),
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      ttl: Duration(milliseconds: reader.readInt()),
      acked: reader.readBool(),
      hopCount: reader.readInt(),
      seenByNodes: reader.readList().cast<String>(),
      retryCount: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineMessage obj) {
    writer.writeString(obj.msgId);
    writer.writeString(obj.fromNodeId);
    writer.writeString(obj.toNodeId);
    writer.writeString(jsonEncode(obj.payload));
    writer.writeString(obj.type.name);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
    writer.writeInt(obj.ttl.inMilliseconds);
    writer.writeBool(obj.acked);
    writer.writeInt(obj.hopCount);
    writer.writeList(obj.seenByNodes);
    writer.writeInt(obj.retryCount);
  }
}
