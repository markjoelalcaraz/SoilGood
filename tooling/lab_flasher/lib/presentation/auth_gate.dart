/// Auth gate for Lab Flasher: login → admin check → flasher home.
///
/// Farmers / non-admins are signed out with a clear error. Not part of the
/// main SoilGood app shell — this is the Windows lab station entry.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/flash_repository.dart';
import '../theme/app_colors.dart';
import 'flasher_page.dart';
import 'login_page.dart';

/// Routes between login and the Provision & Flash screen.
class LabAuthGate extends StatefulWidget {
  const LabAuthGate({super.key});

  @override
  State<LabAuthGate> createState() => _LabAuthGateState();
}

class _LabAuthGateState extends State<LabAuthGate> {
  final _repo = FlashRepository();
  bool _checking = true;
  bool _isAdmin = false;
  String? _denyMessage;
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _refresh();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  /// Re-reads session + profiles.role.
  Future<void> _refresh() async {
    setState(() {
      _checking = true;
      _denyMessage = null;
    });
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _isAdmin = false;
      });
      return;
    }
    try {
      final admin = await _repo.isAdmin();
      if (!admin) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        setState(() {
          _checking = false;
          _isAdmin = false;
          _denyMessage =
              'Admin only. Use an account with profiles.role = admin.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _checking = false;
        _isAdmin = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _isAdmin = false;
        _denyMessage = 'Could not verify admin role: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (!_isAdmin) {
      return LoginPage(bannerMessage: _denyMessage);
    }
    return const FlasherPage();
  }
}
