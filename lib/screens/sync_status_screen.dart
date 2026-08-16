import 'dart:io';
import 'package:flutter/material.dart';
import 'package:aquis_rm_flutter/theme/app_colors.dart';
import 'package:aquis_rm_flutter/models/reading_record.dart';
import 'package:aquis_rm_flutter/widgets/status_badge.dart';
import 'package:aquis_rm_flutter/services/offline_storage_service.dart';
import 'package:aquis_rm_flutter/services/connectivity_service.dart';

class SyncStatusScreen extends StatefulWidget {
  final List<ReadingRecordMobile> history;
  final String assignedBarangay;
  final ValueChanged<ReadingRecordMobile> onRecordUpdated;

  const SyncStatusScreen({
    super.key,
    required this.history,
    this.assignedBarangay = '',
    required this.onRecordUpdated,
  });

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  final ConnectivityService _connectivity = ConnectivityService();
  List<ReadingRecordMobile> _offlineReadings = [];

  @override
  void initState() {
    super.initState();
    _connectivity.startMonitoring();
    _loadOfflineReadings();
    _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline && mounted) {
        _loadOfflineReadings();
      }
    });
  }

  @override
  void dispose() {
    _connectivity.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineReadings() async {
    final readings = await OfflineStorageService.getPendingReadings();
    if (mounted) {
      setState(() => _offlineReadings = readings);
    }
  }

  List<ReadingRecordMobile> get _filtered {
    final brgy = widget.assignedBarangay;
    final all = <ReadingRecordMobile>[];
    all.addAll(widget.history.reversed.where((r) => r.isPending));
    for (final offline in _offlineReadings) {
      if (!all.any((r) => r.id == offline.id)) {
        all.add(offline);
      }
    }
    if (brgy.isNotEmpty) {
      all.removeWhere((r) => r.consumer.barangay != brgy);
    }
    return all;
  }

  void _handleCorrect(ReadingRecordMobile record, int newReading) async {
    final updated = record.copyWith(
      presentReading: newReading,
      syncStatus: SyncStatus.pending,
      rejectionReason: null,
      attempts: record.attempts + 1,
    );
    await OfflineStorageService.markAsSynced(record.id);
    widget.onRecordUpdated(updated);
    _loadOfflineReadings();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Corrected reading submitted for ${record.consumer.accountNo}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 4),
          Expanded(
            child: _filtered.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _filtered.length,
                    separatorBuilder: (ctx, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _SyncCard(
                      record: _filtered[index],
                      onCorrect: (newReading) => _handleCorrect(_filtered[index], newReading),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 20,
      ),
      decoration: const BoxDecoration(color: AppColors.veryDarkTeal),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sync Queue',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_done_rounded, size: 36, color: AppColors.success),
            ),
            const SizedBox(height: 16),
            const Text(
              'All Synced!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No records in the sync queue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  final ReadingRecordMobile record;
  final ValueChanged<int> onCorrect;

  const _SyncCard({
    required this.record,
    required this.onCorrect,
  });

  Color get _statusColor {
    return switch (record.syncStatus) {
      SyncStatus.synced => AppColors.success,
      SyncStatus.pending => const Color(0xFFE65100),
      SyncStatus.needsCorrection => const Color(0xFFC27803),
      SyncStatus.failed => AppColors.danger,
    };
  }

  IconData get _statusIcon {
    return switch (record.syncStatus) {
      SyncStatus.synced => Icons.check_circle_outline,
      SyncStatus.pending => Icons.schedule,
      SyncStatus.needsCorrection => Icons.edit_note,
      SyncStatus.failed => Icons.error_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon, size: 14, color: _statusColor),
                const SizedBox(width: 6),
                StatusBadge(syncStatus: record.syncStatus),
                const Spacer(),
                Text(
                  record.recordedAt,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.consumer.accountNo,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Meter: ${record.consumer.meterNo}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          Text(
                            record.consumer.barangay,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accentSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${record.consumption}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: AppColors.teal,
                            ),
                          ),
                          const Text(
                            'm\u00B3',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.teal),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.pageBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('Previous: ', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        '${record.previousReading} m\u00B3',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.arrow_forward, size: 10, color: AppColors.textMuted),
                      const SizedBox(width: 12),
                      const Text('Present: ', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        '${record.presentReading} m\u00B3',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: AppColors.teal),
                      ),
                    ],
                  ),
                ),
                if (record.rejectionReason != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 1),
                          child: const Icon(Icons.info_outline, size: 13, color: AppColors.danger),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Server Message',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.danger),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                record.rejectionReason!,
                                style: const TextStyle(fontSize: 11, color: AppColors.danger, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (record.attempts > 1) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.replay, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${record.attempts} attempts',
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
                if (record.photoPath != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(record.photoPath!),
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        height: 60,
                        color: AppColors.pageBg,
                        child: const Center(
                          child: Text('Photo unavailable', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ),
                      ),
                    ),
                  ),
                ],
                if (record.needsCorrection) ...[
                  const SizedBox(height: 12),
                  _buildActions(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: () => _showCorrectionDialog(context),
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Correct', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkTeal,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCorrectionDialog(BuildContext context) {
    final ctrl = TextEditingController(text: '${record.presentReading}');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note, size: 20, color: AppColors.teal),
                  const SizedBox(width: 8),
                  const Text(
                    'Correct Reading',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogInfo('Account', record.consumer.accountNo),
                    const SizedBox(height: 4),
                    _dialogInfo('Meter', record.consumer.meterNo),
                    const SizedBox(height: 4),
                    _dialogInfo('Previous', '${record.previousReading} m\u00B3'),
                    const SizedBox(height: 4),
                    _dialogInfo('Current (wrong)', '${record.presentReading} m\u00B3'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'NEW PRESENT READING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 24,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: AppColors.border,
                  ),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.teal, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () {
                          final val = int.tryParse(ctrl.text);
                          if (val != null && val >= record.previousReading) {
                            onCorrect(val);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text('Submit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogInfo(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
