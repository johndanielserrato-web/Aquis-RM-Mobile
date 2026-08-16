import 'package:flutter/material.dart';
import 'package:aquis_rm_flutter/theme/app_colors.dart';
import 'package:aquis_rm_flutter/models/reading_record.dart';

class StatusBadge extends StatelessWidget {
  final SyncStatus syncStatus;

  const StatusBadge({super.key, required this.syncStatus});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, label) = switch (syncStatus) {
      SyncStatus.synced => (AppColors.successBg, AppColors.success, 'Completed'),
      SyncStatus.pending => (const Color(0xFFFFF3E0), const Color(0xFFE65100), 'Queue'),
      SyncStatus.needsCorrection => (const Color(0xFFFEF3C7), const Color(0xFFD97706), 'Needs Correction'),
      SyncStatus.failed => (AppColors.dangerBg, AppColors.danger, 'Failed'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
