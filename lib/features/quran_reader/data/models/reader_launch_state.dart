import '../../domain/models/reader_settings.dart';

class ReaderLaunchState {
  const ReaderLaunchState({
    required this.initialPageNumber,
    required this.settings,
  });

  final int initialPageNumber;
  final ReaderSettings settings;
}
