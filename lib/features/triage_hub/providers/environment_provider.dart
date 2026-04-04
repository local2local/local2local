import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

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
      version: 'v11.29.36',
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
      case L2LEnvironment.prod: return const Color(0xFFFF1744); // VIBRANT RED FOR PROD
      case L2LEnvironment.staging: return const Color(0xFFFF9100); // ORANGE FOR STAGING
      default: return const Color(0xFF1E1E2C); // SLATE FOR DEV
    }
  }
}

class EnvironmentNotifier extends StateNotifier<EnvironmentState> {
  EnvironmentNotifier() : super(EnvironmentState(
    environment: L2LEnvironment.dev,
    projectId: 'local2local-dev',
    headerColor: const Color(0xFF1E1E2C),
    version: 'v11.29.36',
  ));

  void setEnvironment(L2LEnvironment env, BuildContext context) async {
    if (env == L2LEnvironment.prod) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ CONFIRM PRODUCTION ACCESS'),
          content: const Text('You are entering the LIVE production environment. Any data changes or logic commits will affect active users and financial transactions. Proceed with extreme caution.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('BACK TO SAFETY'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('I UNDERSTAND, ENTER PROD'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    state = state.copyWith(environment: env);
  }
}

final environmentProvider = StateNotifierProvider<EnvironmentNotifier, EnvironmentState>((ref) {
  return EnvironmentNotifier();
});