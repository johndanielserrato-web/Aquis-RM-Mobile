import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aquis_rm_flutter/theme/app_colors.dart';
import 'package:aquis_rm_flutter/models/user.dart';
import 'package:aquis_rm_flutter/models/consumer.dart';
import 'package:aquis_rm_flutter/models/reading_record.dart';
import 'package:aquis_rm_flutter/data/mock_data.dart';
import 'package:aquis_rm_flutter/screens/login_screen.dart';
import 'package:aquis_rm_flutter/screens/dashboard_screen.dart';
import 'package:aquis_rm_flutter/screens/assigned_consumers_screen.dart';
import 'package:aquis_rm_flutter/screens/record_screen.dart';
import 'package:aquis_rm_flutter/screens/history_screen.dart';
import 'package:aquis_rm_flutter/screens/sync_status_screen.dart';
import 'package:aquis_rm_flutter/services/connectivity_service.dart';
import 'package:aquis_rm_flutter/services/offline_storage_service.dart';


void main() {
  runApp(const AquisApp());
}

class AquisApp extends StatelessWidget {
  const AquisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AQUIS - Meter Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.teal,
          primary: AppColors.teal,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.pageBg,
      ),
      home: const AquisPhoneFrame(),
    );
  }
}

class AquisPhoneFrame extends StatelessWidget {
  const AquisPhoneFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a3a3d),
      body: Center(
        child: Container(
          width: 390,
          height: 844,
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(44),
            border: Border.all(color: const Color(0xFF1a3a3d), width: 8),
            boxShadow: [
              BoxShadow(
                color: AppColors.teal.withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: -8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Stack(
              children: [
                const AppShell(),
                _notch(),
                _homeIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notch() {
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: 112,
          height: 28,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF1a3a3d),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeIndicator() {
    return Positioned(
      bottom: 4,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 96,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

enum TabItem { dashboard, consumers, record, history, sync }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _loggedIn = false;
  TabItem _tab = TabItem.dashboard;
  AppUser? _currentUser;
  List<ReadingRecordMobile> _history = getInitialHistory();
  final ConnectivityService _connectivity = ConnectivityService();
  int _recordFilterNonce = 0;
  String _recordFilterRequest = 'all';
  int _historyFilterNonce = 0;
  String _historyStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _connectivity.startMonitoring();
    _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline && mounted) {
        _autoSyncPendingReadings();
      }
    });
  }

  @override
  void dispose() {
    _connectivity.dispose();
    super.dispose();
  }

  Future<void> _autoSyncPendingReadings() async {
    final pending = await OfflineStorageService.getPendingReadings();
    if (pending.isEmpty) return;
    for (final record in pending) {
      await Future.delayed(const Duration(milliseconds: 600));
      final consumption = record.consumption;
      if (consumption == 0) {
        await OfflineStorageService.markAsNeedsCorrection(record.id,
            'Zero consumption detected. Please verify the meter reading.');
      } else if (consumption > 100) {
        await OfflineStorageService.markAsNeedsCorrection(record.id,
            'Unusually high consumption of $consumption m\u00B3. Please verify.');
      } else if (record.photoPath == null || record.photoPath!.isEmpty) {
        await OfflineStorageService.markAsNeedsCorrection(record.id,
            'No meter photo attached. A meter photograph is required for verification. Please resubmit with a photo.');
      } else {
        await OfflineStorageService.markAsSynced(record.id);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pending.length} pending reading(s) synced.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onLogin(AppUser user) => setState(() {
        _loggedIn = true;
        _currentUser = user;
      });

  void _onLogout() => setState(() {
        _loggedIn = false;
        _tab = TabItem.dashboard;
      });

  void _handleTabChange(TabItem tab) {
    setState(() {
      _tab = tab;
    });
  }

  void _openRecordWithFilter(String filter) {
    setState(() {
      _recordFilterRequest = filter;
      _recordFilterNonce++;
      _tab = TabItem.record;
    });
  }

  void _openHistoryWithFilter(String filter) {
    setState(() {
      _historyStatusFilter = filter;
      _historyFilterNonce++;
      _tab = TabItem.history;
    });
  }

  void _openSyncTab() {
    setState(() {
      _tab = TabItem.sync;
    });
  }

  void _onRecordSaved(ReadingRecordMobile record) {
    setState(() {
      _history = [record, ..._history];
    });
  }

  void _onRecordUpdated(ReadingRecordMobile record) {
    setState(() {
      final idx = _history.indexWhere((r) => r.id == record.id);
      if (idx >= 0) {
        _history = [..._history]..[idx] = record;
      } else {
        _history = [record, ..._history];
      }
    });
  }

  List<Consumer> get _assignedConsumers {
    final brgy = _currentUser?.assignedBarangay ?? '';
    return mockConsumers
        .where((c) => c.barangay == brgy && c.isActive)
        .toList();
  }

  int get _unreadCount {
    final readAccounts = _history.map((r) => r.accountNo).toSet();
    return _assignedConsumers
        .where((c) => !readAccounts.contains(c.accountNo))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return LoginScreen(onLogin: _onLogin);
    }

    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          DashboardScreen(
            user: _currentUser,
            history: _history,
            assignedConsumers: _assignedConsumers,
            unreadCount: _unreadCount,
            onQueueTap: _openSyncTab,
            onCorrectionsTap: () => _openRecordWithFilter('needsCorrection'),
            onUnrecordedTap: () => _openRecordWithFilter('unrecorded'),
            onCompletedTap: () => _openHistoryWithFilter('completed'),
            onFailedTap: () => _openHistoryWithFilter('failed'),
            onLogout: _onLogout,
          ),
          AssignedConsumersScreen(
            user: _currentUser,
          ),
          RecordScreen(
            user: _currentUser,
            onSaved: _onRecordSaved,
            history: _history,
            assignedBarangay: _currentUser?.assignedBarangay ?? '',
            filterRequest: _recordFilterRequest,
            filterNonce: _recordFilterNonce,
          ),
          HistoryScreen(
            history: _history,
            statusFilter: _historyStatusFilter,
            filterNonce: _historyFilterNonce,
          ),
          SyncStatusScreen(
            history: _history,
            assignedBarangay: _currentUser?.assignedBarangay ?? '',
            onRecordUpdated: _onRecordUpdated,
          ),
        ],
      ),
      bottomNavigationBar: _BottomTabBar(
        active: _tab,
        onChange: _handleTabChange,
        history: _history,
      ),
    );
  }
}

class _BottomTabBar extends StatelessWidget {
  final TabItem active;
  final ValueChanged<TabItem> onChange;
  final List<ReadingRecordMobile> history;

  const _BottomTabBar({
    required this.active,
    required this.onChange,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      height: 64,
      child: Row(
        children: [
          _tabItem(TabItem.dashboard, Icons.home, 'Dashboard'),
          _tabItem(TabItem.consumers, Icons.people, 'Consumers'),
          _tabItem(TabItem.record, Icons.bar_chart, 'Record'),
          _tabItem(TabItem.history, Icons.access_time, 'History'),
          _tabItem(TabItem.sync, Icons.cloud_sync, 'Sync'),
        ],
      ),
    );
  }

  Widget _tabItem(TabItem item, IconData icon, String label) {
    final isActive = active == item;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChange(item),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppColors.teal : AppColors.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.teal : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
