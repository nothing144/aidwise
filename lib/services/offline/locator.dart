import 'package:get_it/get_it.dart';
import 'bluetooth_mesh_service.dart';
import 'offline_queue_service.dart';
import 'heartbeat_service.dart';
import 'sync_service.dart';
import '../../models/offline/node_info.dart';
import '../../models/offline/offline_message.dart';
import '../../models/offline/sync_snapshot.dart';
import 'package:hive_flutter/hive_flutter.dart';

final locator = GetIt.instance;

Future<void> setupOfflineServices() async {
  await Hive.initFlutter();
  Hive.registerAdapter(NodeInfoAdapter());
  Hive.registerAdapter(OfflineMessageAdapter());
  Hive.registerAdapter(SyncSnapshotAdapter());

  final queueService = OfflineQueueService();
  await queueService.init();
  locator.registerSingleton<OfflineQueueService>(queueService);

  final meshService = BluetoothMeshService();
  locator.registerSingleton<BluetoothMeshService>(meshService);

  final heartbeatService = HeartbeatService();
  locator.registerSingleton<HeartbeatService>(heartbeatService);
  
  final syncService = SyncService();
  syncService.init();
  locator.registerSingleton<SyncService>(syncService);
}
