import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../services/offline_sync_service.dart';

class MeshSyncScreen extends StatefulWidget {
  const MeshSyncScreen({super.key});

  @override
  State<MeshSyncScreen> createState() => _MeshSyncScreenState();
}

class _MeshSyncScreenState extends State<MeshSyncScreen> with SingleTickerProviderStateMixin {
  final OfflineSyncService _syncService = OfflineSyncService();
  bool _permissionsGranted = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _checkPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _syncService.stopDiscovery();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();

    bool allGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );
    if (mounted) setState(() => _permissionsGranted = allGranted);
  }

  Future<void> _startScanning() async {
    if (!_permissionsGranted) {
      await _checkPermissions();
      if (!_permissionsGranted) return;
    }
    await _syncService.startDiscovery();
  }

  Future<void> _stopScanning() async {
    await _syncService.stopDiscovery();
  }

  Future<void> _trySyncOnline() async {
    await _syncService.trySyncQueueToFirestore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildOfflineQueueCard(),
              const SizedBox(height: 16),
              _buildSyncStatusCard(),
              const SizedBox(height: 16),
              _buildActionButtons(),
              const SizedBox(height: 20),
              _buildNearbyDevicesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.5 + _pulseController.value * 0.5),
                boxShadow: [BoxShadow(
                  color: AppTheme.primary.withValues(alpha: _pulseController.value * 0.4),
                  blurRadius: 10, spreadRadius: 2,
                )],
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        Text('MESH SYNC', style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          fontSize: 16,
          shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)],
        )),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _permissionsGranted
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _permissionsGranted ? Colors.green : Colors.red, width: 0.5),
          ),
          child: Text(
            _permissionsGranted ? 'READY' : 'NO PERMS',
            style: TextStyle(
              color: _permissionsGranted ? Colors.green : Colors.red,
              fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineQueueCard() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _syncService.pendingReports,
      builder: (context, reports, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_off, color: reports.isEmpty ? AppTheme.textSecondary : AppTheme.urgencyHigh, size: 20),
                      const SizedBox(width: 8),
                      Text('OFFLINE QUEUE', style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11,
                        fontWeight: FontWeight.bold, letterSpacing: 1.5,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${reports.length}',
                        style: TextStyle(
                          color: reports.isEmpty ? AppTheme.primary : AppTheme.urgencyHigh,
                          fontSize: 48, fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('reports pending', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      ),
                    ],
                  ),
                  if (reports.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.surfaceLow),
                    const SizedBox(height: 8),
                    ...reports.take(3).map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: AppTheme.urgencyHigh, size: 6),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${r['type'] ?? 'Report'} — ${r['location'] ?? 'Unknown'}',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
                    if (reports.length > 3)
                      Text('  +${reports.length - 3} more...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSyncStatusCard() {
    return ValueListenableBuilder<String>(
      valueListenable: _syncService.syncStatus,
      builder: (context, status, _) {
        IconData icon;
        Color color;
        String label;
        
        switch (status) {
          case 'SCANNING':
            icon = Icons.bluetooth_searching;
            color = Colors.blueAccent;
            label = 'Scanning for nearby Aidwise devices...';
            break;
          case 'CONNECTING_TO_ADMIN':
            icon = Icons.link;
            color = Colors.orangeAccent;
            label = 'Admin found! Connecting...';
            break;
          case 'CONNECTED':
            icon = Icons.link;
            color = Colors.green;
            label = 'Connected to Admin device!';
            break;
          case 'SENDING':
            icon = Icons.upload;
            color = AppTheme.primary;
            label = 'Sending reports via Bluetooth...';
            break;
          case 'SENT_SUCCESS':
            icon = Icons.check_circle;
            color = Colors.green;
            label = 'Reports sent successfully!';
            break;
          case 'UPLOAD_SUCCESS':
            icon = Icons.cloud_done;
            color = Colors.green;
            label = 'Reports uploaded to cloud!';
            break;
          case 'SYNC_COMPLETE':
            icon = Icons.cloud_done;
            color = Colors.green;
            label = 'Queue synced to Firestore!';
            break;
          case 'ADVERTISING':
            icon = Icons.cell_tower;
            color = AppTheme.secondary;
            label = 'Broadcasting as Admin Sink Node...';
            break;
          default:
            icon = Icons.bluetooth_disabled;
            color = AppTheme.textSecondary;
            label = 'Idle — Tap SCAN to find devices';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (status == 'SCANNING')
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return ValueListenableBuilder<bool>(
      valueListenable: _syncService.isDiscovering,
      builder: (context, isScanning, _) {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isScanning ? _stopScanning : _startScanning,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isScanning ? AppTheme.urgencyHigh : AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(isScanning ? Icons.stop : Icons.bluetooth_searching, size: 18),
                label: Text(
                  isScanning ? 'STOP SCAN' : 'SCAN NEARBY',
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _trySyncOnline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.secondary,
                  side: BorderSide(color: AppTheme.secondary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text(
                  'SYNC ONLINE',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNearbyDevicesSection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices, color: AppTheme.textSecondary, size: 16),
              const SizedBox(width: 8),
              Text('NEARBY DEVICES', style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 11,
                fontWeight: FontWeight.bold, letterSpacing: 1.5,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ValueListenableBuilder<List<Map<String, String>>>(
              valueListenable: _syncService.discoveredDevices,
              builder: (context, devices, _) {
                if (devices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_disabled, color: AppTheme.textSecondary.withValues(alpha: 0.4), size: 48),
                        const SizedBox(height: 12),
                        Text('No devices found yet.', style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Tap SCAN to discover nearby Aidwise devices.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    bool isAdmin = device['role'] == 'ADMIN';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAdmin
                              ? AppTheme.primary.withValues(alpha: 0.4)
                              : AppTheme.surfaceLow,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? AppTheme.primary.withValues(alpha: 0.2)
                                  : AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isAdmin ? Icons.admin_panel_settings : Icons.phone_android,
                              color: isAdmin ? AppTheme.primary : AppTheme.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(device['name'] ?? 'Unknown',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(isAdmin ? 'ADMIN SINK NODE' : 'FIELD WORKER',
                                    style: TextStyle(
                                      color: isAdmin ? AppTheme.primary : AppTheme.textSecondary,
                                      fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1,
                                    )),
                              ],
                            ),
                          ),
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('AUTO-SYNC', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
