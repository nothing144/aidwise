import 'package:hive/hive.dart';

enum NodeRole { admin, worker, volunteer }
enum NodeStatus { online, offline, unknown }

class NodeInfo {
  final String nodeId;
  final NodeRole role;
  final String name;
  NodeStatus status;
  DateTime lastSeen;
  bool isDirectlyReachable;
  String? reachableVia;

  NodeInfo({
    required this.nodeId,
    required this.role,
    required this.name,
    required this.status,
    required this.lastSeen,
    required this.isDirectlyReachable,
    this.reachableVia,
  });

  factory NodeInfo.fromJson(Map<String, dynamic> json) {
    return NodeInfo(
      nodeId: json['nodeId'] as String,
      role: NodeRole.values.byName(json['role'] as String),
      name: json['name'] as String,
      status: NodeStatus.values.byName(json['status'] as String),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int),
      isDirectlyReachable: json['isDirectlyReachable'] as bool,
      reachableVia: json['reachableVia'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'role': role.name,
      'name': name,
      'status': status.name,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'isDirectlyReachable': isDirectlyReachable,
      'reachableVia': reachableVia,
    };
  }
}

class NodeInfoAdapter extends TypeAdapter<NodeInfo> {
  @override
  final int typeId = 0; // Hive type ID

  @override
  NodeInfo read(BinaryReader reader) {
    return NodeInfo(
      nodeId: reader.readString(),
      role: NodeRole.values.byName(reader.readString()),
      name: reader.readString(),
      status: NodeStatus.values.byName(reader.readString()),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      isDirectlyReachable: reader.readBool(),
      reachableVia: reader.readBool() ? reader.readString() : null,
    );
  }

  @override
  void write(BinaryWriter writer, NodeInfo obj) {
    writer.writeString(obj.nodeId);
    writer.writeString(obj.role.name);
    writer.writeString(obj.name);
    writer.writeString(obj.status.name);
    writer.writeInt(obj.lastSeen.millisecondsSinceEpoch);
    writer.writeBool(obj.isDirectlyReachable);
    
    writer.writeBool(obj.reachableVia != null);
    if (obj.reachableVia != null) {
      writer.writeString(obj.reachableVia!);
    }
  }
}
