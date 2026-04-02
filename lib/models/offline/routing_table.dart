import 'node_info.dart';

class RoutingTable {
  final Map<String, NodeInfo> nodes = {};

  NodeInfo? bestRouteFor(String nodeId) {
    if (!nodes.containsKey(nodeId)) return null;

    final target = nodes[nodeId]!;
    if (target.status == NodeStatus.offline) return null;
    
    // Direct link exists
    if (target.isDirectlyReachable) {
      return target;
    }

    // Rely via another node
    if (target.reachableVia != null) {
      final relay = nodes[target.reachableVia!];
      if (relay != null && relay.isDirectlyReachable && relay.status == NodeStatus.online) {
        return relay;
      }
    }
    
    return null; // Route dead
  }

  void markOffline(String nodeId) {
    if (nodes.containsKey(nodeId)) {
      nodes[nodeId]!.status = NodeStatus.offline;
      nodes[nodeId]!.isDirectlyReachable = false;
    }
    
    // Also mark any node reachable via this node as disconnected/unknown
    for (var node in nodes.values) {
      if (node.reachableVia == nodeId) {
        node.reachableVia = null;
        if (!node.isDirectlyReachable) {
          // If we can't reach this node directly anymore, mark unknown
          node.status = NodeStatus.unknown;
        }
      }
    }
  }

  void updateFromHeartbeat(NodeInfo info) {
    nodes[info.nodeId] = info;
  }
}
