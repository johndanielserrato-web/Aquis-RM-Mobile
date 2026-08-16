import 'package:flutter/material.dart';
import 'package:aquis_rm_flutter/theme/app_colors.dart';
import 'package:aquis_rm_flutter/models/reading_record.dart';
import 'package:aquis_rm_flutter/widgets/status_badge.dart';

class HistoryScreen extends StatefulWidget {
  final List<ReadingRecordMobile> history;
  final String statusFilter;
  final int filterNonce;

  const HistoryScreen({
    super.key,
    required this.history,
    this.statusFilter = 'all',
    this.filterNonce = 0,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtl = TextEditingController();
  String _searchQuery = '';
  String _timeFilter = 'today';
  String _statusFilter = 'all';
  DateTime? _selectedTimestamp;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.statusFilter;
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filterNonce != oldWidget.filterNonce) {
      setState(() {
        _statusFilter = widget.statusFilter;
        _searchQuery = '';
        _searchCtl.clear();
      });
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  String _formatTime12(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatTimestamp(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year} · ${_formatTime12(d)}';
  }

  Future<void> _pickTimestamp() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedTimestamp ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTimestamp != null
          ? TimeOfDay.fromDateTime(_selectedTimestamp!)
          : TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _selectedTimestamp = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _timeFilter = 'custom';
    });
  }

  bool _matchesTime(ReadingRecordMobile r) {
    if (_timeFilter == 'custom') {
      final ts = _selectedTimestamp;
      if (ts == null) return true;
      final d = r.date;
      if (d == null) return false;
      return d.year == ts.year &&
          d.month == ts.month &&
          d.day == ts.day &&
          r.time == _formatTime12(ts);
    }
    final d = r.date;
    if (d == null) return _timeFilter == 'all';
    final now = DateTime.now();
    final dateOnly = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    switch (_timeFilter) {
      case 'today':
        return dateOnly.isAtSameMomentAs(today);
      case 'yesterday':
        return dateOnly.isAtSameMomentAs(today.subtract(const Duration(days: 1)));
      case 'thisWeek':
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return !dateOnly.isBefore(startOfWeek);
      case 'thisMonth':
        return d.year == now.year && d.month == now.month;
      default:
        return true;
    }
  }

  List<ReadingRecordMobile> get _filtered {
    var result = widget.history.reversed.toList();
    result = result.where(_matchesTime).toList();
    if (_statusFilter == 'completed') {
      result = result.where((r) => r.isSynced).toList();
    } else if (_statusFilter == 'failed') {
      result = result.where((r) => r.isFailed).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((r) {
        return r.consumer.accountNo.toLowerCase().contains(q) ||
            r.consumer.meterNo.toLowerCase().contains(q) ||
            r.consumer.barangay.toLowerCase().contains(q) ||
            r.time.toLowerCase().contains(q);
      }).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildTimeDropdown()),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatusDropdown()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_filtered.isEmpty)
                    _buildEmpty()
                  else
                    ..._filtered.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _HistoryCard(record: r),
                        )),
                ],
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
          top: MediaQuery.of(context).padding.top + 12, bottom: 20),
      decoration: const BoxDecoration(color: AppColors.veryDarkTeal),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Readings Today',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_filtered.length} record${_filtered.length != 1 ? 's' : ''} shown',
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

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtl,
      onChanged: (val) => setState(() => _searchQuery = val),
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search account, meter, location\u2026',
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        prefixIcon: const Icon(Icons.search, size: 15, color: AppColors.textMuted),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 15, color: AppColors.textMuted),
                onPressed: () {
                  _searchCtl.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
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
    );
  }

  Widget _buildTimeDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _timeFilter,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items: [
            const DropdownMenuItem(
              value: 'today',
              child: Text('Today', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
            const DropdownMenuItem(
              value: 'yesterday',
              child: Text('Yesterday', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
            const DropdownMenuItem(
              value: 'thisWeek',
              child: Text('This Week', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
            const DropdownMenuItem(
              value: 'thisMonth',
              child: Text('This Month', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
            DropdownMenuItem(
              value: 'custom',
              child: Text(
                _selectedTimestamp != null
                    ? _formatTimestamp(_selectedTimestamp!)
                    : 'Select Date & Time',
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
          ],
          onChanged: (v) {
            if (v == 'custom') {
              _pickTimestamp();
            } else {
              setState(() {
                _timeFilter = v ?? 'today';
                _selectedTimestamp = null;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Text('All', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
            DropdownMenuItem(
              value: 'completed',
              child: Text('Completed', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
            DropdownMenuItem(
              value: 'failed',
              child: Text('Failed', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
          ],
          onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.access_time, size: 32, color: AppColors.border),
          const SizedBox(height: 12),
          const Text(
            'No readings recorded today.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          const Text(
            "Start by tapping 'Record'.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ReadingRecordMobile record;

  const _HistoryCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final isEncoded = record.syncStatus == SyncStatus.synced;
    final statusColor = isEncoded ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          record.consumer.accountNo,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal,
                          ),
                        ),
                        const SizedBox(width: 6),
                        StatusBadge(syncStatus: record.syncStatus),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Location: ${record.consumer.barangay}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.timestamp,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Consumption',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${record.consumption}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Text(
                          'm\u00B3',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.pageBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Previous',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                      Text(
                        '${record.previousReading} m\u00B3',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Present',
                        style: TextStyle(fontSize: 10, color: AppColors.teal),
                      ),
                      Text(
                        '${record.presentReading} m\u00B3',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
