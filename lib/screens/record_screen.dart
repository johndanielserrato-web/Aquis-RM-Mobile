import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aquis_rm_flutter/theme/app_colors.dart';
import 'package:aquis_rm_flutter/models/user.dart';
import 'package:aquis_rm_flutter/models/consumer.dart';
import 'package:aquis_rm_flutter/models/reading_record.dart';
import 'package:aquis_rm_flutter/data/mock_data.dart';
import 'package:aquis_rm_flutter/services/offline_storage_service.dart';
import 'package:aquis_rm_flutter/services/connectivity_service.dart';

class RecordScreen extends StatefulWidget {
  final AppUser? user;
  final ValueChanged<ReadingRecordMobile> onSaved;
  final List<ReadingRecordMobile> history;
  final Consumer? selectedConsumer;
  final String assignedBarangay;
  final String filterRequest;
  final int filterNonce;

  const RecordScreen({
    super.key,
    required this.user,
    required this.onSaved,
    this.history = const [],
    this.selectedConsumer,
    this.assignedBarangay = '',
    this.filterRequest = 'all',
    this.filterNonce = 0,
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _searchCtl = TextEditingController();
  final _readingCtl = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  final ConnectivityService _connectivity = ConnectivityService();

  Consumer? _selected;
  String _statusFilter = 'all';
  bool _saving = false;
  bool _saved = false;
  bool _showSuccess = false;
  String _error = '';
  String? _photoPath;
  ReadingRecordMobile? _savedRecord;

  @override
  void initState() {
    super.initState();
    _connectivity.startMonitoring();
    _statusFilter = widget.filterRequest;
    if (widget.selectedConsumer != null) {
      _selected = widget.selectedConsumer;
      _searchCtl.text = widget.selectedConsumer!.meterNo;
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _readingCtl.dispose();
    _focusNode.dispose();
    _connectivity.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RecordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filterNonce != oldWidget.filterNonce) {
      setState(() {
        _statusFilter = widget.filterRequest;
        _selected = null;
        _searchCtl.clear();
        _readingCtl.clear();
        _error = '';
        _saved = false;
        _photoPath = null;
        _showSuccess = false;
        _savedRecord = null;
      });
    } else if (widget.selectedConsumer != null &&
        widget.selectedConsumer != oldWidget.selectedConsumer) {
      setState(() {
        _selected = widget.selectedConsumer;
        _searchCtl.text = widget.selectedConsumer!.meterNo;
        _readingCtl.clear();
        _error = '';
        _saved = false;
        _photoPath = null;
        _showSuccess = false;
      });
    }
  }

  SyncStatus? _getLatestStatus(String accountNo) {
    for (final r in widget.history.reversed) {
      if (r.consumer.accountNo == accountNo) return r.syncStatus;
    }
    return null;
  }

  List<Consumer> get _suggestions {
    if (_selected != null) return [];
    final q = _searchCtl.text.toLowerCase();
    final assigned = widget.assignedBarangay;
    return mockConsumers.where((c) {
      if (assigned.isNotEmpty && c.barangay != assigned) return false;
      if (!c.isActive) return false;
      if (q.isNotEmpty && !c.meterNo.toLowerCase().contains(q) && !c.accountNo.toLowerCase().contains(q)) return false;
      final status = _getLatestStatus(c.accountNo);
      if (_statusFilter == 'unrecorded' && status != null) return false;
      if (_statusFilter == 'needsCorrection' && status != SyncStatus.needsCorrection) return false;
      return true;
    }).toList();
  }

  bool get _isValid {
    if (_selected == null || _readingCtl.text.isEmpty || _photoPath == null) return false;
    final val = int.tryParse(_readingCtl.text);
    if (val == null || val < _selected!.lastReading) return false;
    return true;
  }

  void _handleSelect(Consumer c) {
    setState(() {
      _selected = c;
      _searchCtl.text = c.meterNo;
      _readingCtl.clear();
      _error = '';
      _saved = false;
    });
  }

  void _handleClear() {
    setState(() {
      _selected = null;
      _searchCtl.clear();
      _readingCtl.clear();
      _error = '';
      _saved = false;
      _photoPath = null;
    });
    _focusNode.requestFocus();
  }

  Future<void> _capturePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _photoPath = image.path);
    }
  }

  String? _serverMessage;
  SyncStatus _serverStatus = SyncStatus.synced;

  void _showReviewDialog() {
    if (!_isValid) return;
    final val = int.parse(_readingCtl.text);
    final consumption = val - _selected!.lastReading;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: AppColors.accentSurface, shape: BoxShape.circle),
                      child: const Icon(Icons.receipt_long, size: 18, color: AppColors.teal),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Review Reading',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Please confirm the information below before submitting.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 16),
                _reviewRow('Account No.', _selected!.accountNo),
                _reviewRow('Meter No.', _selected!.meterNo),
                _reviewRow('Location', _selected!.barangay),
                _reviewRow('Category', _selected!.consumerType),
                const SizedBox(height: 12),
                Container(width: double.infinity, height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                _reviewRow('Previous Reading', '${_selected!.lastReading} m\u00B3'),
                _reviewRow('Present Reading', '$val m\u00B3'),
                _reviewRow('Consumption', '$consumption m\u00B3'),
                const SizedBox(height: 12),
                Container(width: double.infinity, height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Meter Photo',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle, size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      'Attached',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ],
                ),
                if (_photoPath != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_photoPath!),
                      width: double.infinity,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Go Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleSave();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text('Confirm & Submit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  void _handleSave() {
    if (!_isValid) return;
    final val = int.parse(_readingCtl.text);
    if (val < _selected!.lastReading) {
      setState(() => _error = 'Present reading cannot be less than previous reading.');
      return;
    }
    setState(() { _error = ''; _saving = true; });
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;

      final consumption = val - _selected!.lastReading;
      final record = ReadingRecordMobile(
        id: 'r${DateTime.now().millisecondsSinceEpoch}',
        accountNo: _selected!.accountNo,
        consumer: _selected!,
        previousReading: _selected!.lastReading,
        presentReading: val,
        consumption: consumption,
        time: _now(),
        date: DateTime.now(),
        syncStatus: SyncStatus.pending,
        photoPath: _photoPath,
        recordedByUserId: widget.user?.id ?? '',
        recordedByName: widget.user?.name ?? '',
      );

      File? photoFile;
      if (_photoPath != null) {
        photoFile = File(_photoPath!);
      }
      await OfflineStorageService.saveReading(record: record, photo: photoFile);

      if (_connectivity.isOnline) {
        await Future.delayed(const Duration(milliseconds: 800));
        SyncStatus status = SyncStatus.synced;
        String? serverMsg;

        if (consumption == 0) {
          status = SyncStatus.needsCorrection;
          serverMsg = 'Zero consumption detected for account ${_selected!.accountNo}. '
              'Reading ($val m\u00B3) equals previous reading (${_selected!.lastReading} m\u00B3). '
              'Please verify the meter reading.';
        } else if (consumption > 100) {
          status = SyncStatus.needsCorrection;
          serverMsg = 'Unusually high consumption of $consumption m\u00B3 detected for account ${_selected!.accountNo}. '
              'Expected range is 5\u201350 m\u00B3. Please verify the reading is correct.';
        } else if (_photoPath == null) {
          status = SyncStatus.needsCorrection;
          serverMsg = 'No meter photo attached for account ${_selected!.accountNo}. '
              'A meter photograph is required for verification. Please resubmit with a photo.';
        } else {
          serverMsg = 'Reading for ${_selected!.accountNo} accepted by server. '
              'Consumption: $consumption m\u00B3. No issues detected.';
        }

        final message = serverMsg;

        if (status == SyncStatus.synced) {
          await OfflineStorageService.markAsSynced(record.id);
        } else {
          await OfflineStorageService.markAsNeedsCorrection(record.id, message);
        }

        final syncedRecord = record.copyWith(
          syncStatus: status,
          rejectionReason: status == SyncStatus.needsCorrection ? message : null,
        );
        setState(() {
          _saving = false;
          _saved = true;
          _savedRecord = syncedRecord;
          _serverMessage = message;
          _serverStatus = status;
        });
        widget.onSaved(syncedRecord);
      } else {
        final pendingRecord = record.copyWith(syncStatus: SyncStatus.pending);
        setState(() {
          _saving = false;
          _saved = true;
          _savedRecord = pendingRecord;
          _serverMessage = 'No internet connection. Reading saved locally and marked as Pending Synchronization. '
              'It will be submitted automatically when connectivity is restored.';
          _serverStatus = SyncStatus.pending;
        });
        widget.onSaved(pendingRecord);
      }
      if (mounted) setState(() => _showSuccess = true);
    });
  }

  void _handleDone() {
    setState(() {
      _showSuccess = false;
      _selected = null;
      _searchCtl.clear();
      _readingCtl.clear();
      _saved = false;
      _savedRecord = null;
      _serverMessage = null;
      _serverStatus = SyncStatus.synced;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _showSuccess && _savedRecord != null
                ? _buildSuccessOverlay()
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchSection(),
                        if (_selected != null) ...[
                          const SizedBox(height: 12),
                          _buildConsumerStatus(),
                          const SizedBox(height: 12),
                          _buildConsumerInfo(),
                          const SizedBox(height: 16),
                          _buildReadingInput(),
                          const SizedBox(height: 16),
                          _buildPhotoSection(),
                        ],
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildError(),
                        ],
                        if (_selected != null &&
                            _photoPath == null &&
                            _readingCtl.text.isNotEmpty &&
                            int.tryParse(_readingCtl.text) != null &&
                            int.parse(_readingCtl.text) >= (_selected?.lastReading ?? 0) &&
                            _error.isEmpty) ...[
                          const SizedBox(height: 8),
                          _buildPhotoRequiredHint(),
                        ],
                        if (_selected != null) ...[
                          const SizedBox(height: 16),
                          _buildSaveButton(),
                        ],
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
                'Record Reading',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Input present meter reading',
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

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONSUMER ACCOUNT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _searchCtl,
          focusNode: _focusNode,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search meter no (assigned area)\u2026',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search, size: 15, color: AppColors.textMuted),
            suffixIcon: _selected != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 15, color: AppColors.textMuted),
                    onPressed: _handleClear,
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
        ),
        if (_selected == null) ...[
          const SizedBox(height: 8),
          _buildFilterChips(),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildSuggestions(),
          ],
        ],
      ],
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        Expanded(
          child: _buildDropdown(
            label: 'Filter',
            value: _statusFilter,
            options: ['all', 'unrecorded', 'needsCorrection'],
            labels: {
              'all': 'All',
              'unrecorded': 'Unrecorded',
              'needsCorrection': 'Needs Correction',
            },
            onChanged: (val) => setState(() => _statusFilter = val),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required Map<String, String> labels,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
        dropdownColor: Colors.white,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        items: options.map((o) {
          return DropdownMenuItem(
            value: o,
            child: Text(labels[o] ?? o),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _suggestions.map((c) {
          return InkWell(
            onTap: () => _handleSelect(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accentSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.water_drop, size: 14, color: AppColors.teal),
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
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: AppColors.teal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              c.meterNo,
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        Text(
                          'Location: ${c.barangay}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(_getLatestStatus(c.accountNo)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConsumerStatus() {
    return _statusBadge(_getLatestStatus(_selected!.accountNo));
  }

  Widget _statusBadge(SyncStatus? status) {
    final (bgColor, textColor, label) = status == SyncStatus.needsCorrection
        ? (const Color(0xFFFEF3C7), const Color(0xFFD97706), 'Needs Correction')
        : (const Color(0xFFEFF6FF), const Color(0xFF2563EB), 'Unrecorded');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildConsumerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _selected!.accountNo,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _selected!.meterNo,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 1,
            color: AppColors.border,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Location: ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: Text(
                  _selected!.barangay,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 1,
            color: AppColors.border,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoField('Category', _selected!.consumerType),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildReadingInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PRESENT READING',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _readingCtl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            fontSize: 28,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(
              fontSize: 28,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: AppColors.border,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Enter the reading from the meter',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
        if (_readingCtl.text.isNotEmpty &&
            int.tryParse(_readingCtl.text) != null &&
            int.parse(_readingCtl.text) < (_selected?.lastReading ?? 0))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Present reading cannot be less than previous reading.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.danger.withValues(alpha: 0.8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'METER PHOTO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(Required)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.danger.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_photoPath != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_photoPath!),
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _photoPath = null),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ] else
          GestureDetector(
            onTap: _capturePhoto,
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, style: BorderStyle.solid),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 28, color: AppColors.textMuted),
                  SizedBox(height: 8),
                  Text(
                    'Tap to capture meter photo',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoRequiredHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.camera_alt_outlined, size: 14, color: AppColors.danger.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'A meter photograph is required before saving.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.danger.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: (_isValid && !_saving && !_saved) ? _showReviewDialog : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _saved ? const Color(0xFF059669) : AppColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.teal.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _saving
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Saving\u2026',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : _saved
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Saved & Bill Generated',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : const Text(
                    'Save Reading',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    final r = _savedRecord!;
    final isAccepted = _serverStatus == SyncStatus.synced;
    final isPending = _serverStatus == SyncStatus.pending;
    final statusColor = isAccepted
        ? const Color(0xFF059669)
        : isPending
            ? const Color(0xFFE65100)
            : const Color(0xFFE65100);
    final statusBg = isAccepted
        ? const Color(0xFFECFDF5)
        : isPending
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFFFF3E0);
    final statusIcon = isAccepted
        ? Icons.check_circle
        : isPending
            ? Icons.cloud_off
            : Icons.warning_amber_rounded;
    final statusTitle = isAccepted
        ? 'Reading Accepted'
        : isPending
            ? 'Saved Offline'
            : 'Needs Correction';
    final statusSubtitle = isAccepted
        ? 'Server has accepted this reading'
        : isPending
            ? 'Pending synchronization'
            : 'Server flagged this reading for review';

    return Stack(
      children: [
        ListView(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            decoration: const BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: statusBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    statusTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusSubtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.accentSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'CONSUMPTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${r.consumption}',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'm\u00B3',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (r.photoPath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(r.photoPath!),
                        width: double.infinity,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_serverMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isAccepted ? Icons.info_outline : Icons.warning_amber_rounded,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Server Validation Message',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _serverMessage!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isAccepted
                            ? Icons.check_circle
                            : isPending
                                ? Icons.cloud_queue
                                : Icons.info_outline,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAccepted
                            ? 'Bill has been generated'
                            : isPending
                                ? 'Will sync when online'
                                : 'Please check Sync Status for details',
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _handleDone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Record Another',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _now() {
  final dt = DateTime.now();
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final min = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$min $ampm';
}
