import 'package:flutter/material.dart';
import 'package:aquis_rm_flutter/theme/app_colors.dart';
import 'package:aquis_rm_flutter/models/user.dart';
import 'package:aquis_rm_flutter/models/consumer.dart';
import 'package:aquis_rm_flutter/data/mock_data.dart';

class AssignedConsumersScreen extends StatefulWidget {
  final AppUser? user;

  const AssignedConsumersScreen({
    super.key,
    required this.user,
  });

  @override
  State<AssignedConsumersScreen> createState() => _AssignedConsumersScreenState();
}

class _AssignedConsumersScreenState extends State<AssignedConsumersScreen> {
  final _searchCtl = TextEditingController();
  String _categoryFilter = 'all';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  String get _assignedBarangay =>
      widget.user?.assignedBarangay ?? '';

  List<Consumer> get _filteredConsumers {
    final brgy = _assignedBarangay;
    final q = _searchCtl.text.toLowerCase();
    return mockConsumers.where((c) {
      if (brgy.isNotEmpty && c.barangay != brgy) return false;
      if (!c.isActive) return false;
      if (_categoryFilter != 'all' && c.consumerType != _categoryFilter) return false;
      if (q.isNotEmpty) {
        return c.accountNo.toLowerCase().contains(q) ||
            c.meterNo.toLowerCase().contains(q) ||
            c.barangay.toLowerCase().contains(q);
      }
      return true;
    }).toList();
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
                  _buildAssignedBarangay(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 16),
                  if (_filteredConsumers.isEmpty)
                    _buildEmpty()
                  else
                    ..._filteredConsumers.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ConsumerCard(
                            consumer: c,
                            onTap: () => _showConsumerDetails(c),
                          ),
                        )),
                  const SizedBox(height: 16),
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
                'My Assigned Area',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _assignedBarangay.isNotEmpty
                    ? 'Barangay $_assignedBarangay'
                    : 'No barangay assigned',
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

  Widget _buildAssignedBarangay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.location_on, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ASSIGNED BARANGAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _assignedBarangay.isNotEmpty ? _assignedBarangay : 'None',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtl,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search account or meter no\u2026',
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        prefixIcon: const Icon(Icons.search, size: 15, color: AppColors.textMuted),
        suffixIcon: _searchCtl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 15, color: AppColors.textMuted),
                onPressed: () {
                  _searchCtl.clear();
                  setState(() {});
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

  Widget _buildCategoryDropdown() {
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
          value: _categoryFilter,
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
              value: 'Residential',
              child: Text('Residential', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
            DropdownMenuItem(
              value: 'Commercial',
              child: Text('Commercial', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
            DropdownMenuItem(
              value: 'Industrial',
              child: Text('Industrial', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
          ],
          onChanged: (v) => setState(() => _categoryFilter = v ?? 'all'),
        ),
      ),
    );
  }

  void _showConsumerDetails(Consumer c) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.accentSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.water_drop, size: 18, color: AppColors.teal),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.accountNo,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            color: AppColors.teal,
                          ),
                        ),
                        Text(
                          c.meterNo,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow('Location', '${c.street}, ${c.barangay}'),
              const SizedBox(height: 10),
              _detailRow('Category', c.consumerType),
              const SizedBox(height: 10),
              _detailRow('Last Reading', '${c.lastReading} m\u00B3'),
              const SizedBox(height: 10),
              _detailRow('Status', c.status),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.accentSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline, size: 32, color: AppColors.teal),
          ),
          const SizedBox(height: 16),
          const Text(
            'No consumers found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchCtl.text.isNotEmpty
                ? 'Try a different search term'
                : 'No active consumers in your assigned area',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ConsumerCard extends StatelessWidget {
  final Consumer consumer;
  final VoidCallback onTap;

  const _ConsumerCard({required this.consumer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.accentSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.water_drop, size: 20, color: AppColors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    consumer.accountNo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Meter: ${consumer.meterNo}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _categoryChip(consumer.consumerType),
              ],
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
