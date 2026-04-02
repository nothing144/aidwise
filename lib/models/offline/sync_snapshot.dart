import 'package:hive/hive.dart';
import 'dart:convert';
import 'offline_message.dart';
import 'node_info.dart';

class SyncSnapshot {
  final DateTime generatedAt;
  final String byNodeId;
  final List<OfflineMessage> pendingDispatches;
  final Map<String, String> currentAssignments; // volunteerId -> taskId
  final Map<String, NodeStatus> nodeStatuses; // nodeId -> status

  SyncSnapshot({
    required this.generatedAt,
    required this.byNodeId,
    required this.pendingDispatches,
    required this.currentAssignments,
    required this.nodeStatuses,
  });

  factory SyncSnapshot.fromJson(Map<String, dynamic> json) {
    return SyncSnapshot(
      generatedAt: DateTime.fromMillisecondsSinceEpoch(json['generatedAt'] as int),
      byNodeId: json['byNodeId'] as String,
      pendingDispatches: (jsonDecode(json['pendingDispatches'] as String) as Iterable).map((e) => OfflineMessage.fromJson(e as Map<String, dynamic>)).toList(),
      currentAssignments: Map<String, String>.from(jsonDecode(json['currentAssignments'] as String)),
      nodeStatuses: Map<String, NodeStatus>.from(jsonDecode(json['nodeStatuses'] as String).map((k, v) => MapEntry(k, NodeStatus.values.byName(v)))),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generatedAt': generatedAt.millisecondsSinceEpoch,
      'byNodeId': byNodeId,
      'pendingDispatches': jsonEncode(pendingDispatches.map((e) => e.toJson()).toList()),
      'currentAssignments': jsonEncode(currentAssignments),
      'nodeStatuses': jsonEncode(nodeStatuses.map((k, v) => MapEntry(k, v.name))),
    };
  }
}

class SyncSnapshotAdapter extends TypeAdapter<SyncSnapshot> {
  @override
  final int typeId = 2; // Hive type ID

  @override
  SyncSnapshot read(BinaryReader reader) {
    return SyncSnapshot(
      generatedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      byNodeId: reader.readString(),
      pendingDispatches: reader.readList().cast<OfflineMessage>(),
      currentAssignments: Map<String, String>.from(jsonDecode(reader.readString())),
      nodeStatuses: Map<String, NodeStatus>.from(jsonDecode(reader.readString()).map((k, v) => MapEntry(k, NodeStatus.values.byName(v)))),
    );
  }

  @override
  void write(BinaryWriter writer, SyncSnapshot obj) {
    writer.writeInt(obj.generatedAt.millisecondsSinceEpoch);
    writer.writeString(obj.byNodeId);
    writer.writeList(obj.pendingDispatches);
    writer.writeString(jsonEncode(obj.currentAssignments));
    
    final statusMap = obj.nodeStatuses.map((k, v) => MapEntry(k, v.name));
    writer.writeString(jsonEncode(statusMap));
  }
}
