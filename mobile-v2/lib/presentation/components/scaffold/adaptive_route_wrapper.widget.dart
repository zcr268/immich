import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:immich_mobile/utils/extensions/build_context.extension.dart';

class ImAdaptiveRouteWrapper extends StatelessWidget {
  const ImAdaptiveRouteWrapper({
    super.key,
    required this.primaryRoute,
    required this.primaryBody,
    this.bodyRatio,
  });

  /// Builder to build the primary body
  final Widget Function(BuildContext?) primaryBody;

  /// Primary route name to not render it twice in landscape
  final String primaryRoute;

  /// Ratio of primaryBody:secondaryBody
  final double? bodyRatio;

  @override
  Widget build(BuildContext context) {
    return AutoRouter(builder: (ctx, child) {
      if (ctx.isTablet) {
        return _ImAdaptiveScaffold(
          primaryBody: primaryBody,
          secondaryBody:
              ctx.topRoute.name != primaryRoute ? (_) => child : null,
          bodyRatio: bodyRatio,
        );
      }
      return _ImAdaptiveScaffold(primaryBody: (_) => child);
    });
  }
}

class _ImAdaptiveScaffold extends StatelessWidget {
  const _ImAdaptiveScaffold({
    required this.primaryBody,
    this.secondaryBody,
    this.bodyRatio,
  });

  /// Builder to build the primary body
  final Widget Function(BuildContext?) primaryBody;

  /// Builder to build the secondary body
  final Widget Function(BuildContext?)? secondaryBody;

  /// Ratio of primaryBody:secondaryBody
  final double? bodyRatio;

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      internalAnimations: false,
      transitionDuration: const Duration(milliseconds: 300),
      bodyRatio: bodyRatio,
      body: SlotLayout(
        config: {
          Breakpoints.standard: SlotLayout.from(
            key: const Key('ImAdaptiveScaffold Body Standard'),
            builder: primaryBody,
          ),
        },
      ),
      secondaryBody: SlotLayout(
        config: {
          /// No secondary body in mobile layouts
          Breakpoints.small: SlotLayoutConfig.empty(),
          Breakpoints.mediumAndUp: SlotLayout.from(
            key: const Key('ImAdaptiveScaffold Secondary Body Medium'),
            builder: secondaryBody,
          ),
        },
      ),
    );
  }
}
