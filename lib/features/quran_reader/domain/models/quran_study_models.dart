class QuranStudyWord {
  const QuranStudyWord({required this.position, required this.arabic,
    required this.partOfSpeech, this.root, this.meaning, this.transliteration});
  final int position;
  final String arabic;
  final String partOfSpeech;
  final String? root;
  final String? meaning;
  final String? transliteration;

  QuranStudyWord withGloss(String? meaning, String? transliteration) =>
      QuranStudyWord(position: position, arabic: arabic, partOfSpeech: partOfSpeech,
        root: root, meaning: meaning, transliteration: transliteration);
}

class QuranStudyVerse {
  const QuranStudyVerse({required this.reference, required this.chapterName,
    required this.english, required this.urdu, required this.words,
    this.onlineMeanings = false});
  final String reference;
  final String chapterName;
  final String english;
  final String urdu;
  final List<QuranStudyWord> words;
  final bool onlineMeanings;
  String get arabic => words.map((word) => word.arabic).join(' ');
}

class QuranStudyCollection {
  const QuranStudyCollection(this.id, this.title, this.references, {this.isDua = false});
  final String id;
  final String title;
  final List<String> references;
  final bool isDua;
}

const quranStudyCollections = <QuranStudyCollection>[
  QuranStudyCollection('goodness', 'Good in this life and the next', ['2:201'], isDua: true),
  QuranStudyCollection('steadfast', 'A steadfast heart', ['3:8'], isDua: true),
  QuranStudyCollection('repentance', 'Repentance and forgiveness', ['7:23', '23:118'], isDua: true),
  QuranStudyCollection('prayer', 'Prayer and parents', ['14:40', '14:41', '17:24'], isDua: true),
  QuranStudyCollection('clarity', 'Ease and clarity', ['20:25', '20:26', '20:27', '20:28'], isDua: true),
  QuranStudyCollection('knowledge', 'Seeking knowledge', ['20:114'], isDua: true),
  QuranStudyCollection('distress', 'Turning to Allah in distress', ['21:87'], isDua: true),
  QuranStudyCollection('family-dua', 'Family and righteousness', ['25:74'], isDua: true),
  QuranStudyCollection('gratitude-dua', 'Gratitude and good deeds', ['27:19'], isDua: true),
  QuranStudyCollection('need', 'Asking for goodness', ['28:24'], isDua: true),
  QuranStudyCollection('believers', 'For fellow believers', ['59:10'], isDua: true),
  QuranStudyCollection('light', 'Light and forgiveness', ['66:8'], isDua: true),
  QuranStudyCollection('patience', 'Patience', ['2:153', '2:155', '2:156', '2:157']),
  QuranStudyCollection('gratitude', 'Gratitude', ['2:152', '14:7', '31:12']),
  QuranStudyCollection('mercy', 'Mercy and hope', ['7:156', '39:53']),
  QuranStudyCollection('trust', 'Trust in Allah', ['3:159', '9:129', '65:3']),
  QuranStudyCollection('justice', 'Justice and kindness', ['4:135', '5:8', '16:90']),
  QuranStudyCollection('family', 'Care for parents', ['17:23', '17:24', '31:14']),
  QuranStudyCollection('charity', 'Giving with care', ['2:261', '2:262', '2:263', '2:264']),
  QuranStudyCollection('learning', 'Learning and reflection', ['96:1', '96:2', '96:3', '96:4', '96:5', '39:9']),
];
