class WorshipText {
  const WorshipText(this.en, this.ur, this.ar);
  final String en;
  final String ur;
  final String ar;
  String inLanguage(String code) => code == 'ur'
      ? ur
      : code == 'ar'
      ? ar
      : en;
}

class WorshipReference {
  const WorshipReference(this.label, this.url, {this.note});
  final String label;
  final String url;
  final WorshipText? note;
}

class WorshipDhikr {
  const WorshipDhikr({
    required this.id,
    required this.group,
    required this.title,
    required this.arabic,
    required this.meaning,
    required this.target,
    required this.reference,
    this.surahId,
  });
  final String id;
  final String group;
  final WorshipText title;
  final String arabic;
  final WorshipText meaning;
  final int target;
  final WorshipReference reference;
  final int? surahId;
}

class WorshipLesson {
  const WorshipLesson(
    this.id,
    this.title,
    this.description,
    this.reference, {
    this.letters = const [],
    this.surahId,
  });
  final String id;
  final WorshipText title;
  final WorshipText description;
  final WorshipReference reference;
  final List<String> letters;
  final int? surahId;
}

class WorshipGuideStep {
  const WorshipGuideStep(this.title, this.description, this.reference);
  final WorshipText title;
  final WorshipText description;
  final WorshipReference reference;
}

const worshipAfterPrayerReference = WorshipReference(
  'Sahih Muslim 596a',
  'https://sunnah.com/muslim:596a',
);
const worshipBedtimeReference = WorshipReference(
  'Sahih Muslim 2727a',
  'https://sunnah.com/muslim:2727a',
);
const worshipQulsReference = WorshipReference(
  'Sunan Abi Dawud 5082',
  'https://sunnah.com/abudawud:5082',
  note: WorshipText(
    'Graded Hasan by Al-Albani on the source page.',
    'اصل صفحے پر البانی نے حسن قرار دیا ہے۔',
    'حسّنه الألباني كما في المصدر.',
  ),
);
const worshipWuduReference = WorshipReference(
  'Sahih al-Bukhari 159',
  'https://sunnah.com/bukhari:159',
);
const worshipPrayerReference = WorshipReference(
  'Sahih al-Bukhari 757',
  'https://sunnah.com/bukhari:757',
);
const worshipFiqhReference = WorshipReference(
  'IslamWeb, fatwa 449212 (school comparison)',
  'https://islamweb.net/en/printfatwa.php?id=449212',
);

const _tasbih = WorshipText(
  'Glory belongs to Allah.',
  'اللہ ہر عیب سے پاک ہے۔',
  'تنزيه الله عن كل نقص.',
);
const _tahmid = WorshipText(
  'All praise belongs to Allah.',
  'تمام تعریف اللہ کے لیے ہے۔',
  'الثناء كله لله.',
);
const _takbir = WorshipText(
  'Allah is the Greatest.',
  'اللہ سب سے بڑا ہے۔',
  'الله أعظم من كل شيء.',
);

final worshipAzkar = <WorshipDhikr>[
  for (final group in ['after_prayer', 'bedtime']) ...[
    WorshipDhikr(
      id: '${group}_tasbih',
      group: group,
      title: const WorshipText('Tasbih', 'تسبیح', 'التسبيح'),
      arabic: 'سُبْحَانَ اللَّهِ',
      meaning: _tasbih,
      target: 33,
      reference: group == 'after_prayer'
          ? worshipAfterPrayerReference
          : worshipBedtimeReference,
    ),
    WorshipDhikr(
      id: '${group}_tahmid',
      group: group,
      title: const WorshipText('Tahmid', 'تحمید', 'التحميد'),
      arabic: 'الْحَمْدُ لِلَّهِ',
      meaning: _tahmid,
      target: 33,
      reference: group == 'after_prayer'
          ? worshipAfterPrayerReference
          : worshipBedtimeReference,
    ),
    WorshipDhikr(
      id: '${group}_takbir',
      group: group,
      title: const WorshipText('Takbir', 'تکبیر', 'التكبير'),
      arabic: 'اللَّهُ أَكْبَرُ',
      meaning: _takbir,
      target: 34,
      reference: group == 'after_prayer'
          ? worshipAfterPrayerReference
          : worshipBedtimeReference,
    ),
  ],
  for (final group in ['morning', 'evening']) ...[
    WorshipDhikr(
      id: '${group}_ikhlas',
      group: group,
      title: const WorshipText('Al-Ikhlas', 'الاخلاص', 'الإخلاص'),
      arabic: 'سورة الإخلاص',
      meaning: const WorshipText(
        'Recite the complete Surah three times.',
        'پوری سورت تین بار پڑھیں۔',
        'اقرأ السورة كاملة ثلاث مرات.',
      ),
      target: 3,
      reference: worshipQulsReference,
      surahId: 112,
    ),
    WorshipDhikr(
      id: '${group}_falaq',
      group: group,
      title: const WorshipText('Al-Falaq', 'الفلق', 'الفلق'),
      arabic: 'سورة الفلق',
      meaning: const WorshipText(
        'Recite the complete Surah three times.',
        'پوری سورت تین بار پڑھیں۔',
        'اقرأ السورة كاملة ثلاث مرات.',
      ),
      target: 3,
      reference: worshipQulsReference,
      surahId: 113,
    ),
    WorshipDhikr(
      id: '${group}_nas',
      group: group,
      title: const WorshipText('An-Nas', 'الناس', 'الناس'),
      arabic: 'سورة الناس',
      meaning: const WorshipText(
        'Recite the complete Surah three times.',
        'پوری سورت تین بار پڑھیں۔',
        'اقرأ السورة كاملة ثلاث مرات.',
      ),
      target: 3,
      reference: worshipQulsReference,
      surahId: 114,
    ),
  ],
];

const worshipDhikrGroups = <String, WorshipText>{
  'morning': WorshipText('Morning', 'صبح', 'الصباح'),
  'evening': WorshipText('Evening', 'شام', 'المساء'),
  'after_prayer': WorshipText('After prayer', 'نماز کے بعد', 'بعد الصلاة'),
  'bedtime': WorshipText('Before sleep', 'سونے سے پہلے', 'قبل النوم'),
};

const worshipLetters = [
  'ا',
  'ب',
  'ت',
  'ث',
  'ج',
  'ح',
  'خ',
  'د',
  'ذ',
  'ر',
  'ز',
  'س',
  'ش',
  'ص',
  'ض',
  'ط',
  'ظ',
  'ع',
  'غ',
  'ف',
  'ق',
  'ك',
  'ل',
  'م',
  'ن',
  'ه',
  'و',
  'ي',
];

const worshipLetterNames = <String, String>{
  'ا': 'أَلِف',
  'ب': 'بَاء',
  'ت': 'تَاء',
  'ث': 'ثَاء',
  'ج': 'جِيم',
  'ح': 'حَاء',
  'خ': 'خَاء',
  'د': 'دَال',
  'ذ': 'ذَال',
  'ر': 'رَاء',
  'ز': 'زَاي',
  'س': 'سِين',
  'ش': 'شِين',
  'ص': 'صَاد',
  'ض': 'ضَاد',
  'ط': 'طَاء',
  'ظ': 'ظَاء',
  'ع': 'عَيْن',
  'غ': 'غَيْن',
  'ف': 'فَاء',
  'ق': 'قَاف',
  'ك': 'كَاف',
  'ل': 'لَام',
  'م': 'مِيم',
  'ن': 'نُون',
  'ه': 'هَاء',
  'و': 'وَاو',
  'ي': 'يَاء',
};

final worshipKidsLessons = <WorshipLesson>[
  for (var group = 0; group < 7; group++)
    WorshipLesson(
      'letters_${group + 1}',
      WorshipText(
        'Letter group ${group + 1}',
        'حروف کا گروپ ${group + 1}',
        'مجموعة الحروف ${group + 1}',
      ),
      const WorshipText(
        'Look at each letter. Ask a teacher to model its sound, then repeat. Letter recognition is not a Tajweed assessment.',
        'ہر حرف پہچانیں۔ استاد سے اس کی آواز سن کر دہرائیں۔ حروف کی پہچان تجوید کا امتحان نہیں ہے۔',
        'تعرّف إلى الحروف، واستمع لنطق معلّم ثم كرّر. معرفة الحروف ليست تقييمًا للتجويد.',
      ),
      const WorshipReference(
        'Arabic script practice · Quran 20:114',
        'https://quran.com/20/114',
      ),
      letters: worshipLetters.sublist(group * 4, group * 4 + 4),
    ),
  const WorshipLesson(
    'short_vowels',
    WorshipText('Short vowels', 'مختصر حرکات', 'الحركات القصيرة'),
    WorshipText(
      'Practise ba with fathah, kasrah and dammah: بَ بِ بُ. Listen to a teacher and repeat slowly.',
      'با پر زبر، زیر اور پیش کی مشق کریں: بَ بِ بُ۔ استاد سے سن کر آہستہ دہرائیں۔',
      'تدرّب على الباء مع الفتحة والكسرة والضمة: بَ بِ بُ. استمع لمعلّم وكرّر ببطء.',
    ),
    WorshipReference(
      'Arabic reading practice · Quran 20:114',
      'https://quran.com/20/114',
    ),
    letters: ['بَ', 'بِ', 'بُ'],
  ),
  for (final entry in const <int, WorshipText>{
    1: WorshipText('Al-Fatihah', 'الفاتحہ', 'الفاتحة'),
    112: WorshipText('Al-Ikhlas', 'الاخلاص', 'الإخلاص'),
    113: WorshipText('Al-Falaq', 'الفلق', 'الفلق'),
    114: WorshipText('An-Nas', 'الناس', 'الناس'),
  }.entries)
    WorshipLesson(
      'surah_${entry.key}',
      entry.value,
      const WorshipText(
        'Read the original Quran text, listen to the qari, and repeat a small part with a parent or teacher. Mark this lesson when you have practised.',
        'قرآن کا اصل متن پڑھیں، قاری کو سنیں اور والدین یا استاد کے ساتھ تھوڑا تھوڑا دہرائیں۔ مشق کے بعد سبق پر نشان لگائیں۔',
        'اقرأ النص القرآني واستمع للقارئ، ثم كرّر جزءًا صغيرًا مع وليّك أو معلّمك. علّم الدرس بعد التدرّب.',
      ),
      WorshipReference('Quran ${entry.key}', 'https://quran.com/${entry.key}'),
      surahId: entry.key,
    ),
  const WorshipLesson(
    'gentleness',
    WorshipText('Learn with kindness', 'نرمی سے سیکھیں', 'تعلّم برفق'),
    WorshipText(
      'Practise patiently. Encourage each other and ask for help when a sound is difficult.',
      'صبر سے مشق کریں، ایک دوسرے کی حوصلہ افزائی کریں اور مشکل آواز پر مدد مانگیں۔',
      'تدرّب بصبر، وشجّع غيرك، واطلب المساعدة عند صعوبة النطق.',
    ),
    WorshipReference('Sahih Muslim 2593', 'https://sunnah.com/muslim:2593'),
  ),
];

const worshipWuduSteps = <WorshipGuideStep>[
  WorshipGuideStep(
    WorshipText('1 · Hands', '۱ · ہاتھ', '١ · اليدان'),
    WorshipText(
      'Begin the narrated washing sequence by washing the hands three times.',
      'روایت میں بیان کردہ طریقے کے مطابق پہلے ہاتھ تین بار دھوئیں۔',
      'ابدأ الطريقة المروية بغسل اليدين ثلاث مرات.',
    ),
    worshipWuduReference,
  ),
  WorshipGuideStep(
    WorshipText('2 · Mouth and nose', '۲ · منہ اور ناک', '٢ · الفم والأنف'),
    WorshipText(
      'Rinse the mouth, then gently draw water into the nose and expel it.',
      'کلی کریں، پھر ناک میں نرمی سے پانی ڈال کر صاف کریں۔',
      'تمضمض، ثم استنشق الماء بلطف واستنثر.',
    ),
    worshipWuduReference,
  ),
  WorshipGuideStep(
    WorshipText('3 · Face', '۳ · چہرہ', '٣ · الوجه'),
    WorshipText(
      'Wash the face three times in this narrated example.',
      'اس روایت کے طریقے میں چہرہ تین بار دھوئیں۔',
      'اغسل الوجه ثلاث مرات في هذه الصفة المروية.',
    ),
    worshipWuduReference,
  ),
  WorshipGuideStep(
    WorshipText('4 · Arms', '۴ · بازو', '٤ · الذراعان'),
    WorshipText(
      'Wash the arms including the elbows three times.',
      'دونوں بازو کہنیوں سمیت تین بار دھوئیں۔',
      'اغسل الذراعين مع المرفقين ثلاث مرات.',
    ),
    worshipWuduReference,
  ),
  WorshipGuideStep(
    WorshipText('5 · Head', '۵ · سر', '٥ · الرأس'),
    WorshipText(
      'Wipe the head with wet hands. The selected-school note below explains the minimum area; learn the complete practice with a teacher.',
      'گیلے ہاتھوں سے سر کا مسح کریں۔ منتخب فقہ کے کم از کم حصے کی وضاحت نیچے ہے؛ مکمل طریقہ استاد سے سیکھیں۔',
      'امسح الرأس بيدين مبتلّتين. توضح ملاحظة المذهب أدناه الحد الأدنى، وتعلّم الصفة الكاملة مع معلّم.',
    ),
    worshipWuduReference,
  ),
  WorshipGuideStep(
    WorshipText('6 · Feet', '۶ · پاؤں', '٦ · القدمان'),
    WorshipText(
      'Wash both feet including the ankles three times. This is a narrated practice sequence, not a list grading every act as obligatory.',
      'دونوں پاؤں ٹخنوں سمیت تین بار دھوئیں۔ یہ روایت کا طریقہ ہے، ہر عمل کے فرض ہونے کی فہرست نہیں۔',
      'اغسل القدمين مع الكعبين ثلاث مرات. هذه صفة مروية وليست تصنيفًا لكل فعل على أنه فرض.',
    ),
    worshipWuduReference,
  ),
];

const worshipPrayerSteps = <WorshipGuideStep>[
  WorshipGuideStep(
    WorshipText('Prepare', 'تیاری', 'الاستعداد'),
    WorshipText(
      'Prepare for purification before prayer. Quran 5:6 is the foundation for washing the face, arms and feet, and wiping the head.',
      'نماز سے پہلے پاکی کا اہتمام کریں۔ قرآن ۵:۶ میں چہرہ، بازو اور پاؤں دھونے اور سر کے مسح کا اصل حکم ہے۔',
      'استعد للطهارة قبل الصلاة. أصل غسل الوجه والذراعين والقدمين ومسح الرأس في القرآن ٥:٦.',
    ),
    WorshipReference('Quran 5:6', 'https://quran.com/5/6'),
  ),
  WorshipGuideStep(
    WorshipText('Stand and begin', 'قیام اور ابتدا', 'القيام والافتتاح'),
    WorshipText(
      'Begin with takbir, then recite Quran. Learn the recitation and its school-specific details with a teacher.',
      'تکبیر سے ابتدا کریں، پھر قرآن پڑھیں۔ قراءت اور اپنی فقہ کی تفصیل استاد سے سیکھیں۔',
      'ابدأ بالتكبير ثم اقرأ القرآن. تعلّم القراءة وتفاصيل مذهبك مع معلّم.',
    ),
    worshipPrayerReference,
  ),
  WorshipGuideStep(
    WorshipText('Bow calmly', 'اطمینان سے رکوع', 'الركوع بطمأنينة'),
    WorshipText(
      'Bow without rushing and settle in the posture.',
      'جلدی کیے بغیر رکوع کریں اور اطمینان اختیار کریں۔',
      'اركع دون استعجال واستقر في الركوع.',
    ),
    worshipPrayerReference,
  ),
  WorshipGuideStep(
    WorshipText('Stand upright', 'سیدھے کھڑے ہوں', 'الاعتدال قائمًا'),
    WorshipText(
      'Rise from bowing and become upright before moving on.',
      'رکوع سے اٹھ کر اگلے عمل سے پہلے سیدھے کھڑے ہوں۔',
      'ارفع من الركوع واعتدل قائمًا قبل الانتقال.',
    ),
    worshipPrayerReference,
  ),
  WorshipGuideStep(
    WorshipText(
      'Prostrate and sit calmly',
      'اطمینان سے سجدہ اور بیٹھنا',
      'السجود والجلوس بطمأنينة',
    ),
    WorshipText(
      'Prostrate, then sit calmly. Practise the full sequence and repetitions with your teacher.',
      'سجدہ کریں، پھر اطمینان سے بیٹھیں۔ مکمل ترتیب اور تکرار استاد کے ساتھ سیکھیں۔',
      'اسجد ثم اجلس بطمأنينة. تدرّب على الترتيب الكامل والتكرار مع معلّمك.',
    ),
    worshipPrayerReference,
  ),
  WorshipGuideStep(
    WorshipText(
      'Learn the complete prayer',
      'مکمل نماز سیکھیں',
      'تعلّم الصلاة كاملة',
    ),
    WorshipText(
      'This beginner overview does not replace a complete school-specific prayer manual. Learn the second prostration, rak‘ahs, tashahhud, blessings and ending, and adaptations for illness, with a qualified teacher.',
      'یہ ابتدائی خاکہ مکمل فقہی کتاب کا بدل نہیں۔ دوسرا سجدہ، رکعتیں، تشہد، درود، سلام اور بیماری کی رعایتیں مستند استاد سے سیکھیں۔',
      'هذا مدخل للمبتدئ وليس بديلًا لدليل مذهبي كامل. تعلّم السجدة الثانية والركعات والتشهد والصلاة على النبي والسلام وأحكام المرض مع معلّم مؤهل.',
    ),
    WorshipReference(
      'Sahih al-Bukhari 631; Muslim 403a',
      'https://sunnah.com/bukhari:631',
    ),
  ),
];

const worshipFiqhHeadNotes = <String, WorshipText>{
  'hanafi': WorshipText(
    'Hanafi: the cited comparison states a minimum of one quarter of the head.',
    'حنفی: مذکورہ تقابل کے مطابق کم از کم سر کے چوتھائی حصے کا مسح ہے۔',
    'الحنفي: يذكر المصدر المقارن أن الحد الأدنى ربع الرأس.',
  ),
  'shafii': WorshipText(
    'Shafi‘i: the cited comparison states wiping a part of the head.',
    'شافعی: مذکورہ تقابل کے مطابق سر کے کچھ حصے کا مسح ہے۔',
    'الشافعي: يذكر المصدر المقارن مسح جزء من الرأس.',
  ),
  'maliki': WorshipText(
    'Maliki: the cited comparison states wiping the whole head.',
    'مالکی: مذکورہ تقابل کے مطابق پورے سر کا مسح ہے۔',
    'المالكي: يذكر المصدر المقارن مسح الرأس كله.',
  ),
  'hanbali': WorshipText(
    'Hanbali: the cited comparison states wiping the whole head.',
    'حنبلی: مذکورہ تقابل کے مطابق پورے سر کا مسح ہے۔',
    'الحنبلي: يذكر المصدر المقارن مسح الرأس كله.',
  ),
};
