import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../type.dart';

/// One-line notification preview (Lock). A Flare dot means unread, a hollow
/// ash ring means read.
class HaloNotificationPreview extends StatelessWidget {
  const HaloNotificationPreview({
    super.key,
    required this.sender,
    required this.body,
    required this.age,
    required this.unread,
  });

  final String sender;
  final String body;

  /// Mono age (`2M`, `1H`).
  final String age;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Semantics(
      container: true,
      label: '${unread ? 'Unread. ' : ''}$sender: $body, $age ago',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: halo.divider)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                _Dot(unread: unread),
                const SizedBox(width: 12),
                Text(
                  HaloType.upper(sender),
                  style: HaloType.status.copyWith(color: halo.text),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.preview.copyWith(color: halo.textDim),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  HaloType.upper(age),
                  style: HaloType.meta.copyWith(color: halo.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.unread});

  final bool unread;

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unread ? halo.flare : null,
        border: unread ? null : Border.all(color: halo.muted, width: 1.5),
      ),
    );
  }
}
