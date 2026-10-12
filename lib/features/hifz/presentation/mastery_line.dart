import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;
import '../data/recitation_service.dart';

/// «حُفظت النتيجة · أُتقنت آيات جديدة: ٣ · تحتاج مراجعة: ١», after a
/// session goes into the recitation record.
String masteryLine(BuildContext context, MasteryChange c) {
  final l = AppLocalizations.of(context);
  final digits = NumberFormatter(Localizations.localeOf(context));
  return [
    l.progressSaved,
    if (c.newlyMastered > 0)
      l.progressNewlyMastered(digits(c.newlyMastered))
    else if (c.mastered > 0)
      l.progressStillMastered(digits(c.mastered)),
    if (c.needReview > 0) l.progressToReview(digits(c.needReview)),
  ].join(' · ');
}
