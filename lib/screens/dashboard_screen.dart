import 'package:flutter/material.dart';
import 'package:aquis_rm_flutter/theme/app_colors.dart';
import 'package:aquis_rm_flutter/models/user.dart';
import 'package:aquis_rm_flutter/models/consumer.dart';
import 'package:aquis_rm_flutter/models/reading_record.dart';
import 'package:aquis_rm_flutter/widgets/status_badge.dart';

enum ReadingFilter { all, completed, queue, corrections, failed, unread }

class DashboardScreen extends StatefulWidget {
  final AppUser? user;
  final List<ReadingRecordMobile> history;
  final List<Consumer> assignedConsumers;
  final int unreadCount;
  final VoidCallback onQueueTap;
  final VoidCallback onCorrectionsTap;
  final VoidCallback onUnrecordedTap;
  final VoidCallback onCompletedTap;
  final VoidCallback onFailedTap;
  final VoidCallback onLogout;

  const DashboardScreen({
    super.key,
    required this.user,
    required this.history,
    required this.assignedConsumers,
    required this.unreadCount,
    required this.onQueueTap,
    required this.onCorrectionsTap,
    required this.onUnrecordedTap,
    required this.onCompletedTap,
    required this.onFailedTap,
    required this.onLogout,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ReadingFilter _filter = ReadingFilter.all;
  String _monthKey = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _monthKey = 'all';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static String _monthKeyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  bool _matchesMonth(ReadingRecordMobile r) {
    if (_monthKey == 'all') return true;
    final d = r.date;
    return d != null && _monthKeyFor(d) == _monthKey;
  }

  List<ReadingRecordMobile> get _filteredRecords {
    final list = widget.history;
    return switch (_filter) {
      ReadingFilter.all => list.where(_matchesMonth).toList(),
      ReadingFilter.completed => list.where((r) => r.isSynced && _matchesMonth(r)).toList(),
      ReadingFilter.queue => list.where((r) => r.isPending && _matchesMonth(r)).toList(),
      ReadingFilter.corrections => list.where((r) => r.needsCorrection && _matchesMonth(r)).toList(),
      ReadingFilter.failed => list.where((r) => r.isFailed && _matchesMonth(r)).toList(),
      ReadingFilter.unread => const <ReadingRecordMobile>[],
    };
  }

  List<Consumer> get _unreadConsumers {
    final readAccounts = widget.history.map((r) => r.accountNo).toSet();
    return widget.assignedConsumers
        .where((c) => !readAccounts.contains(c.accountNo))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr =
        '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}, ${now.year}';
    final completedCount = widget.history.where((r) => r.isSynced).length;
    final queueCount = widget.history.where((r) => r.isPending).length;
    final needsCorrectionCount = widget.history.where((r) => r.needsCorrection).length;
    final failedCount = widget.history.where((r) => r.isFailed).length;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Column(
        children: [
          _buildTopBar(context, dateStr),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSyncSummary(completedCount, queueCount, needsCorrectionCount, widget.unreadCount, failedCount),
                const SizedBox(height: 12),
                _buildFilterDropdown(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildCardList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String dateStr) {
    final top = MediaQuery.of(context).padding.top;
    final displayName = widget.user?.name ?? 'Meter Reader';
    final displayRole = widget.user?.role ?? 'meter_reader';
    final roleLabel = displayRole.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: EdgeInsets.only(top: top + 12),
      decoration: const BoxDecoration(color: AppColors.veryDarkTeal),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onLogout,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: AppColors.textLight,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ReadingFilter>(
          value: _filter,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items: [
            _item(ReadingFilter.all, 'All'),
            _item(ReadingFilter.completed, 'Completed'),
            _item(ReadingFilter.queue, 'Queue'),
            _item(ReadingFilter.unread, 'Unrecorded'),
            _item(ReadingFilter.corrections, 'Corrections'),
            _item(ReadingFilter.failed, 'Failed'),
          ],
          onChanged: (v) => setState(() => _filter = v ?? ReadingFilter.all),
        ),
      ),
    );
  }

  DropdownMenuItem<ReadingFilter> _item(ReadingFilter value, String label) {
    return DropdownMenuItem(
      value: value,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildCardList() {
    final List<Widget> cards = [];
    if (_filter == ReadingFilter.unread) {
      final unread = _unreadConsumers;
      if (unread.isEmpty) {
        return _buildCardPanel(_buildEmpty('No unread consumers in your assigned area.'));
      }
      cards.addAll(unread.map(_unreadConsumerCard));
    } else {
      final records = _filteredRecords;
      if (records.isEmpty) {
        return _buildCardPanel(_buildEmpty('No readings match this filter.'));
      }
      cards.addAll(records.map(_recordCard));
    }

    return _buildCardPanel(
      Scrollbar(
        controller: _scrollController,
        thumbVisibility: cards.length >= 5,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: cards.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: cards[i],
          ),
        ),
      ),
    );
  }

  Widget _buildCardPanel(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'RECENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _recordCard(ReadingRecordMobile r) {
    final statusColor = switch (r.syncStatus) {
      SyncStatus.synced => AppColors.success,
      SyncStatus.pending => const Color(0xFFE65100),
      SyncStatus.needsCorrection => const Color(0xFFD97706),
      SyncStatus.failed => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      r.accountNo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: StatusBadge(syncStatus: r.syncStatus)),
                  ],
                ),
                const SizedBox(height: 5),
                _categoryChip(r.consumer.consumerType),
                const SizedBox(height: 2),
                Text(
                  r.recordedAt,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${r.presentReading}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'm\u00B3',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unreadConsumerCard(Consumer c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.accountNo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _unreadBadge(),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _categoryChip(c.consumerType),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${c.street}, ${c.barangay}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '—',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'm\u00B3',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String type) {
    final (bg, fg) = switch (type) {
      'Residential' => (const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
      'Commercial' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      _ => (const Color(0xFFF3E8FF), const Color(0xFF7E22CE)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _unreadBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Unread',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildSyncSummary(int completed, int queue, int needsCorrection, int unread, int failed) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniStat('Completed', completed, AppColors.success, const Color(0xFFECFDF5), onTap: widget.onCompletedTap),
              const SizedBox(width: 6),
              _miniStat('Queue', queue, const Color(0xFFE65100), const Color(0xFFFFF3E0), onTap: widget.onQueueTap),
              const SizedBox(width: 6),
              _miniStat('Unrecorded', unread, const Color(0xFF2563EB), const Color(0xFFEFF6FF), onTap: widget.onUnrecordedTap),
              const SizedBox(width: 6),
              _miniStat('Corrections', needsCorrection, const Color(0xFFD97706), const Color(0xFFFEF3C7), onTap: widget.onCorrectionsTap),
              const SizedBox(width: 6),
              _miniStat('Failed', failed, AppColors.danger, AppColors.dangerBg, onTap: widget.onFailedTap),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int count, Color color, Color bgColor, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: color,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _weekday(int w) =>
    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
String _month(int m) =>
    ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
