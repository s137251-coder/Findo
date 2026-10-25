import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../managers/localization_manager.dart';

/// Findo's store page, the link every shared result carries.
const storeUrl = 'https://play.google.com/store/apps/details?id=com.findo.game';

/// Hands [text] and the store link to the phone's share sheet.
///
/// The share sheet, not a button per network: the player already has the
/// apps they talk to their friends in, and the sheet lists exactly those.
Future<void> shareText(BuildContext context, String text) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: '$text\n$storeUrl',
        subject: context.l10n.t('app.title'),
        // iPads anchor the sheet to the button that opened it.
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (error) {
    debugPrint('[share] $error');
  }
}
