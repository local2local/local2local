import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum L2LEnvironment { dev, staging, prod }

class EnvironmentState {
  final L2LEnvironment environment;
  final String projectId;
  final Color headerColor;
  final String version;
  final String buildTimestamp;
  final String deployHash;

  EnvironmentState({
    required this.environment,
    required this.projectId,
    required this.headerColor,
    required this.version,
    required this.buildTimestamp,
    required this.deployHash,
  });

  EnvironmentState copyWith({L2LEnvironment? environment}) {
    final newEnv = environment ?? this.environment;
    return EnvironmentState(
      environment: newEnv,
      projectId: _getProjectId(newEnv),
      headerColor: _getHeaderColor(newEnv),
      version: 'v11.43.36',
      buildTimestamp: const String.fromEnvironment('BUILD_TIME', defaultValue: 'LOCAL'),
      deployHash: const String.fromEnvironment('DEPLOY_HASH', defaultValue: 'DEBUG'),
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
    final hash = const String.fromEnvironment('DEPLOY_HASH', defaultValue: 'BOOT_HASH');
    final ts = const String.fromEnvironment('BUILD_TIME', defaultValue: 'BOOT_TS');
    
    // NUCLEAR CONSOLE LOG: Visible in browser F12 console
    debugPrint('=========================================');
    debugPrint('L2LAAF DEPLOYMENT LOG');
    debugPrint('Version: v11.43.36');
    debugPrint('Commit Hash: $hash');
    debugPrint('Timestamp: $ts');
    debugPrint('=========================================');

    return EnvironmentState(
      environment: L2LEnvironment.dev,
      projectId: 'local2local-dev',
      headerColor: const Color(0xFF1E1E2C),
      version: 'v11.43.36',
      buildTimestamp: ts,
      deployHash: hash,
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