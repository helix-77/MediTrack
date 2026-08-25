import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/entitlement_guard.dart';
import '../services/entitlement_service.dart';
import '../theme/colors.dart';

/// Wraps a whole screen that requires an active MediTrack Premium
/// subscription for [feature].
///
/// On first build it runs [EntitlementService.requirePremium], which
/// refreshes the cached entitlement, and (if the user isn't entitled) routes
/// them through account-upgrade / the subscription offer screen. If the user
/// still isn't entitled afterwards, this pops the current route instead of
/// rendering [builder] — the caller's screen never has to know about
/// entitlement plumbing.
class PremiumGate extends StatefulWidget {
  const PremiumGate({super.key, required this.feature, required this.builder});

  final EntitlementFeature feature;
  final WidgetBuilder builder;

  @override
  State<PremiumGate> createState() => _PremiumGateState();
}

class _PremiumGateState extends State<PremiumGate> {
  bool _checking = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final entitlement = context.read<EntitlementService>();
    final allowed = await entitlement.requirePremium(
      context,
      feature: widget.feature,
    );
    if (!mounted) return;

    if (!allowed) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _checking = false;
      _allowed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_allowed) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }
    return widget.builder(context);
  }
}
