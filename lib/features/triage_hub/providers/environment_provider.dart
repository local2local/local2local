import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// L2L environment — staging has been removed.
/// Only dev and prod exist.
enum L2LEnvironment { dev, prod }

class EnvironmentState {
  final L2LEnvironment environment;
  final String projectId;
  final Color headerColor;

  EnvironmentState({
    required this.environment,
    required this.projectId,
    required this.headerColor,
  });

  EnvironmentState copyWith({L2LEnvironment? environment}) {
    final newEnv = environment ?? this.environment;
    return EnvironmentState(
      environment: newEnv,
      projectId: _getProjectId(newEnv),
      headerColor: _getHeaderColor(newEnv),
    );
  }

  static String _getProjectId(L2LEnvironment env) {
    switch (env) {
      case L2LEnvironment.prod:
        return 'local2local-prod';
      default:
        return 'local2local-dev';
    }
  }

  static Color _getHeaderColor(L2LEnvironment env) {
    switch (env) {
      case L2LEnvironment.prod:
        return AdminColors.rubyRed;
      default:
        return AdminColors.slateDark;
    }
  }
}

class EnvironmentNotifier extends Notifier<EnvironmentState> {
  @override
  EnvironmentState build() {
    return EnvironmentState(
      environment: L2LEnvironment.dev,
      projectId: 'local2local-dev',
      headerColor: AdminColors.slateDark,
    );
  }

  void setEnvironment(L2LEnvironment env, BuildContext context) async {
    if (env == L2LEnvironment.prod) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AdminColors.slateDark,
          title: const Text(
            '⚠️ CONFIRM PRODUCTION ACCESS',
            style: TextStyle(color: AdminColors.textPrimary),
          ),
          content: const Text(
            'You are entering the LIVE production environment. Exercise extreme caution — all actions affect real users.',
            style: TextStyle(color: AdminColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'BACK',
                style: TextStyle(color: AdminColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.rubyRed,
                foregroundColor: AdminColors.textPrimary,
              ),
              child: const Text('ENTER PROD'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    state = state.copyWith(environment: env);
  }
}

final environmentProvider =
    NotifierProvider<EnvironmentNotifier, EnvironmentState>(() {
  return EnvironmentNotifier();
});