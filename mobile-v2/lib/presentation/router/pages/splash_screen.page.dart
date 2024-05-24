import 'dart:math' show pi;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:immich_mobile/immich_constants.dart';
import 'package:immich_mobile/presentation/router/router.dart';
import 'package:immich_mobile/utils/mixins/log_context.mixin.dart';
import 'package:watch_it/watch_it.dart';

@RoutePage()
class SplashScreenPage extends StatefulWidget {
  const SplashScreenPage({super.key});

  @override
  State createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreenPage>
    with SingleTickerProviderStateMixin, LogContext {
  late final _animationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: di.allReady(),
        builder: (_, snap) {
          if (snap.hasData) {
            context.router.replaceAll([const TabControllerRoute()]);
          } else if (snap.hasError) {
            log.severe(
              "Error while initializing the app",
              snap.error,
              snap.stackTrace,
            );
          }

          return Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (_, child) => Transform.rotate(
                angle: _animationController.value * pi * 2,
                child: child,
              ),
              child: const Image(
                width: 100,
                filterQuality: FilterQuality.high,
                semanticLabel: 'Immich Logo',
                image: AssetImage(kImmichLogoPngPath),
              ),
            ),
          );
        },
      ),
    );
  }
}
