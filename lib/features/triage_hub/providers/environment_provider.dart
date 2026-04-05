import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum L2LEnvironment { dev, staging, prod }

class EnvironmentState {
  final L2LEnvironment environment;
  final String projectId;
  final Color headerColor;
  final String version;

  EnvironmentState({
    required this.environment,
    required this.projectId,
    required this.headerColor,
    required this.version,
  });

  EnvironmentState copyWith({L2LEnvironment? environment}) {
    final newEnv = environment ?? this.environment;
    return EnvironmentState(
      environment: newEnv,
      projectId: _getProjectId(newEnv),
      headerColor: _getHeaderColor(newEnv),
      version: 'v11.35.36',
    );
  }

  static String _getProjectId(L2LEnvironment env) {
    switch (env) {
      case L2LEnvironment.staging: return 'local2local-staging';
      case L2LEnvironment.prod: return 'local2local-prod';
      default: return 'local2local-dev';
    }
  }

  static Color _getHeaderColor(L2LEnvironment env) {
    switch (env) {
      case L2LEnvironment.prod: return const Color(0xFFFF1744);
      case L2LEnvironment.staging: return const Color(0xFFFF9100);
      default: return const Color(0xFF1E1E2C);
    }
  }
}

class EnvironmentNotifier extends Notifier<EnvironmentState> {
  @override
  EnvironmentState build() {
    return EnvironmentState(
      environment: L2LEnvironment.dev,
      projectId: 'local2local-dev',
      headerColor: const Color(0xFF1E1E2C),
      version: 'v11.35.36',
    );
  }

  void setEnvironment(L2LEnvironment env, BuildContext context) async {
    if (env == L2LEnvironment.prod) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ CONFIRM PRODUCTION ACCESS'),
          content: const Text('Entering LIVE production environment. Extreme caution required.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BACK')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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

final environmentProvider = NotifierProvider<EnvironmentNotifier, EnvironmentState>(() {
  return EnvironmentNotifier();
});