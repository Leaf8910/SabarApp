// models/quran_verse.dart
class QuranVerse {
  final int number;
  final int numberInSurah;
  final String arabicText;
  final String englishTranslation;
  final String audioUrl;
  final String surahName;
  final String surahNameArabic;
  final int surahNumber;

  QuranVerse({
    required this.number,
    required this.numberInSurah,
    required this.arabicText,
    required this.englishTranslation,
    required this.audioUrl,
    required this.surahName,
    required this.surahNameArabic,
    required this.surahNumber,
  });

  factory QuranVerse.fromApiResponse(Map<String, dynamic> ayahData, Map<String, dynamic> surahData) {
    return QuranVerse(
      number: ayahData['number'] ?? 0,
      numberInSurah: ayahData['numberInSurah'] ?? 0,
      arabicText: ayahData['text'] ?? '',
      englishTranslation: '', // Will be set separately from translation data
      audioUrl: ayahData['audioUrl'] ?? '',
      surahName: surahData['englishName'] ?? '',
      surahNameArabic: surahData['name'] ?? '',
      surahNumber: surahData['number'] ?? 1,
    );
  }

  QuranVerse copyWith({
    int? number,
    int? numberInSurah,
    String? arabicText,
    String? englishTranslation,
    String? audioUrl,
    String? surahName,
    String? surahNameArabic,
    int? surahNumber,
  }) {
    return QuranVerse(
      number: number ?? this.number,
      numberInSurah: numberInSurah ?? this.numberInSurah,
      arabicText: arabicText ?? this.arabicText,
      englishTranslation: englishTranslation ?? this.englishTranslation,
      audioUrl: audioUrl ?? this.audioUrl,
      surahName: surahName ?? this.surahName,
      surahNameArabic: surahNameArabic ?? this.surahNameArabic,
      surahNumber: surahNumber ?? this.surahNumber,
    );
  }

  @override
  String toString() {
    return 'QuranVerse(number: $number, numberInSurah: $numberInSurah, surahName: $surahName, arabicText: $arabicText)';
  }
}