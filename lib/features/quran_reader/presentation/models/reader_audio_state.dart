import '../../domain/models/quran_reciter.dart';

class ReaderAudioState {
  const ReaderAudioState({
    required this.isLoading,
    required this.isPlaying,
    required this.isBuffering,
    required this.isDownloading,
    required this.positionMillis,
    required this.durationMillis,
    required this.currentChapterId,
    required this.currentSurahName,
    required this.selectedReciter,
    required this.repeatEnabled,
    required this.errorMessage,
  });

  const ReaderAudioState.idle()
      : isLoading = false,
        isPlaying = false,
        isBuffering = false,
        isDownloading = false,
        positionMillis = 0,
        durationMillis = 0,
        currentChapterId = null,
        currentSurahName = null,
        selectedReciter = null,
        repeatEnabled = false,
        errorMessage = null;

  final bool isLoading;
  final bool isPlaying;
  final bool isBuffering;
  final bool isDownloading;
  final int positionMillis;
  final int durationMillis;
  final int? currentChapterId;
  final String? currentSurahName;
  final QuranReciter? selectedReciter;
  final bool repeatEnabled;
  final String? errorMessage;

  ReaderAudioState copyWith({
    bool? isLoading,
    bool? isPlaying,
    bool? isBuffering,
    bool? isDownloading,
    int? positionMillis,
    int? durationMillis,
    int? currentChapterId,
    String? currentSurahName,
    QuranReciter? selectedReciter,
    bool? repeatEnabled,
    String? errorMessage,
    bool clearCurrentChapter = false,
    bool clearReciter = false,
    bool clearError = false,
  }) {
    return ReaderAudioState(
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isDownloading: isDownloading ?? this.isDownloading,
      positionMillis: positionMillis ?? this.positionMillis,
      durationMillis: durationMillis ?? this.durationMillis,
      currentChapterId: clearCurrentChapter
          ? null
          : currentChapterId ?? this.currentChapterId,
      currentSurahName: clearCurrentChapter
          ? null
          : currentSurahName ?? this.currentSurahName,
      selectedReciter:
          clearReciter ? null : selectedReciter ?? this.selectedReciter,
      repeatEnabled: repeatEnabled ?? this.repeatEnabled,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  double get progress {
    if (durationMillis <= 0) {
      return 0;
    }
    return (positionMillis / durationMillis).clamp(0, 1);
  }
}
