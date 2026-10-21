/// Ported from src/data/adhkar.ts.
library;

enum DhikrGroup { morning, evening, afterPrayer }

class DhikrItem {
  final String id;
  final String text;
  final int count;
  final String source;
  final List<DhikrGroup> group;

  const DhikrItem(this.id, this.text, this.count, this.source, this.group);
}

const adhkarItems = <DhikrItem>[
  DhikrItem(
    'morning-evening-1',
    'أصبحنا وأصبح الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير. رب أسألك خير ما في هذا اليوم وخير ما بعده، وأعوذ بك من شر ما في هذا اليوم وشر ما بعده.',
    1,
    'صحيح مسلم',
    [DhikrGroup.morning],
  ),
  DhikrItem(
    'evening-1',
    'أمسينا وأمسى الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير. رب أسألك خير ما في هذه الليلة وخير ما بعدها، وأعوذ بك من شر ما في هذه الليلة وشر ما بعدها.',
    1,
    'صحيح مسلم',
    [DhikrGroup.evening],
  ),
  DhikrItem(
    'morning-2',
    'اللهم بك أصبحنا وبك أمسينا، وبك نحيا وبك نموت وإليك النشور.',
    1,
    'سنن أبي داود والترمذي',
    [DhikrGroup.morning],
  ),
  DhikrItem(
    'evening-2',
    'اللهم بك أمسينا وبك أصبحنا، وبك نحيا وبك نموت وإليك المصير.',
    1,
    'سنن أبي داود والترمذي',
    [DhikrGroup.evening],
  ),
  DhikrItem(
    'رضيت',
    'رضيت بالله ربًا، وبالإسلام دينًا، وبمحمد ﷺ نبيًا.',
    3,
    'سنن أبي داود والترمذي',
    [DhikrGroup.morning, DhikrGroup.evening],
  ),
  DhikrItem(
    'بسم-الله',
    'بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم.',
    3,
    'سنن أبي داود والترمذي',
    [DhikrGroup.morning, DhikrGroup.evening],
  ),
  DhikrItem(
    'سبحان-الله-100',
    'سبحان الله وبحمده.',
    100,
    'صحيح مسلم',
    [DhikrGroup.morning, DhikrGroup.evening],
  ),
  DhikrItem(
    'استغفار-بعد',
    'أستغفر الله.',
    3,
    'صحيح مسلم — بعد الصلاة',
    [DhikrGroup.afterPrayer],
  ),
  DhikrItem(
    'السلام-بعد',
    'اللهم أنت السلام ومنك السلام، تباركت يا ذا الجلال والإكرام.',
    1,
    'صحيح مسلم — بعد الصلاة',
    [DhikrGroup.afterPrayer],
  ),
  DhikrItem(
    'تسبيح-بعد',
    'سبحان الله، والحمد لله، والله أكبر.',
    33,
    'صحيح مسلم — بعد الصلاة',
    [DhikrGroup.afterPrayer],
  ),
];
