import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/reader_audio_sheet.dart';

class AyahAudioFollowScreen extends StatefulWidget {
  const AyahAudioFollowScreen({super.key, required this.controller});

  final QuranReaderController controller;

  @override
  State<AyahAudioFollowScreen> createState() => _AyahAudioFollowScreenState();
}

class _AyahAudioFollowScreenState extends State<AyahAudioFollowScreen> {
  bool _saving = false;

  String _t(String source) {
    final translation = _translations[source];
    return switch (ReaderLocalizationScope.of(context).language) {
      ReaderLanguage.urdu => translation?.$1 ?? source,
      ReaderLanguage.arabic => translation?.$2 ?? source,
      _ => source,
    };
  }

  Future<void> _setFollow(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.controller.setRecitationSyncEnabled(enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t('The setting could not be saved. Please try again.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller.settingsListenable,
        controller.experienceListenable,
      ]),
      builder: (context, _) {
        final experience = controller.experienceSettings;
        return Theme(
          data: controller.settings.nightMode
              ? AppTheme.dark(
                  highContrast: experience.highContrastMode,
                  largerText: experience.largerTextMode,
                )
              : AppTheme.light(
                  highContrast: experience.highContrastMode,
                  largerText: experience.largerTextMode,
                ),
          child: Scaffold(
            appBar: AppBar(title: Text(_t('Ayah audio follow'))),
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Card(
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        leading: const Icon(Icons.hearing_rounded),
                        title: Text(_t('Follow the recitation')),
                        subtitle: Text(
                          _t(
                            experience.recitationSyncEnabled
                                ? 'Timed Ayah reference and translations are on'
                                : 'Ayah follow is off',
                          ),
                        ),
                        children: [
                          SwitchListTile.adaptive(
                            title: Text(_t('Enable Ayah follow')),
                            value: experience.recitationSyncEnabled,
                            onChanged: _saving || !controller.isAudioEnabled
                                ? null
                                : _setFollow,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              _t(
                                'During playback, the Ayah reference and its translations follow the recording timestamps. Your selected original Mushaf scan stays unchanged. Exact Ayah or line highlighting on scanned pages is not available.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ReaderAudioContent(
                      controller: controller,
                      showHandle: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

const _translations = <String, (String, String)>{
  'Ayah audio follow': ('تلاوت کے ساتھ آیت', 'متابعة الآية مع التلاوة'),
  'Follow the recitation': ('تلاوت کے ساتھ ساتھ دیکھیں', 'تابع التلاوة'),
  'Timed Ayah reference and translations are on': (
    'آیت کا حوالہ اور ترجمہ تلاوت کے ساتھ دکھائی دیں گے',
    'مرجع الآية وترجماتها متزامنان مع التلاوة',
  ),
  'Ayah follow is off': ('آیت کی پیروی بند ہے', 'متابعة الآية متوقفة'),
  'Enable Ayah follow': ('تلاوت کے ساتھ آیت دکھائیں', 'تفعيل متابعة الآية'),
  'During playback, the Ayah reference and its translations follow the recording timestamps. Your selected original Mushaf scan stays unchanged. Exact Ayah or line highlighting on scanned pages is not available.': (
    'تلاوت کے دوران آیت کا حوالہ اور ترجمہ ریکارڈنگ کے اوقات کے مطابق دکھائی دیتے ہیں۔ آپ کا منتخب اصل مصحف اسکین نہیں بدلتا۔ اسکین پر آیت یا سطر کی عین نشاندہی دستیاب نہیں۔',
    'أثناء التشغيل، يتبع مرجع الآية وترجماتها التوقيت المسجل للتلاوة. تبقى صورة المصحف الأصلي المختار دون تغيير. لا يتوفر تحديد موضع الآية أو السطر بدقة على الصفحات المصوّرة.',
  ),
  'The setting could not be saved. Please try again.': (
    'ترتیب محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
    'تعذّر حفظ الإعداد. يرجى المحاولة مجددًا.',
  ),
};
