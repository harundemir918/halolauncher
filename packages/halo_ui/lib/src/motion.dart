import 'package:flutter/widgets.dart';

/// [duration], or none at all when the user has asked Android to remove
/// animations (Settings > Accessibility). Every animation that is only for
/// looks goes through this, so the arc turns and the slats slide in one frame.
/// Gestures that need time to be a gesture (the Lock screen's hold) don't.
Duration haloMotion(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
