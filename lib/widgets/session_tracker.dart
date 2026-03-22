import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';

class SessionTracker extends StatefulWidget {
  final Widget child;
  const SessionTracker({super.key, required this.child});

  @override
  State<SessionTracker> createState() => _SessionTrackerState();
}

class _SessionTrackerState extends State<SessionTracker> with WidgetsBindingObserver {
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionStart = DateTime.now();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionStart = DateTime.now();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _logSession();
    }
  }

  Future<void> _logSession() async {
    if (_sessionStart == null) return;
    
    // AuthProvider might not be available during detached state, safely try to get it
    try {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;

      final sessionEnd = DateTime.now();
      final durationMins = sessionEnd.difference(_sessionStart!).inSeconds / 60.0;
      
      // Only log sessions longer than 30 seconds
      if (durationMins > 0.5) {
        final loc = await LocationService.getCurrentLocation();
        await FirestoreService().logSession({
          'uid': auth.user!.uid,
          'role': auth.profile?['role'] ?? 'student',
          'sessionStart': _sessionStart,
          'sessionEnd': sessionEnd,
          'durationMinutes': double.parse(durationMins.toStringAsFixed(2)),
          'location': loc,
        });
      }
    } catch (_) {
      // Ignore context errors during app termination
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
