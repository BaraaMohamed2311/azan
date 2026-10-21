import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_ui.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/quran.dart';
import '../services/audio_service.dart';
import '../state/app_settings.dart';

/// Ported from app/quran/[surah].tsx — mushaf reader with Qalun recitation.
class SurahScreen extends StatefulWidget {
  final int surahNumber;
  const SurahScreen({super.key, required this.surahNumber});

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  final RecitationPlayer _player = RecitationPlayer();

  List<QalunReciter> _reciters = [];
  int _reciterIndex = 0;
  String? _audioUri; // idb:// or file path of downloaded audio
  bool _isDownloaded = false;
  bool _isDownloading = false;
  String? _loadError;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _loadReciters();
    _markLastRead();
    // Keep the play/pause button in sync with the actual player state.
    _player.raw.playerStateStream.listen((state) {
      if (mounted) setState(() => _playing = state.playing);
    });
  }

  @override
  void dispose() {
    _player.pause();
    _player.dispose();
    super.dispose();
  }

  QalunReciter? get _reciter =>
      _reciters.isEmpty ? null : _reciters[_reciterIndex];

  Future<void> _loadReciters() async {
    List<QalunReciter>? available;
    try {
      available = await fetchQalunReciters();
    } catch (_) {
      available = null;
    }
    if (!mounted) return;
    if (available != null) {
      setState(() => _reciters = available!);
    }
    final reciterId = available != null && available.isNotEmpty
        ? available.first.id
        : null;
    final local = reciterId != null
        ? await getDownloadedSurahAudio(widget.surahNumber, reciterId)
        : await getDownloadedSurahAudio(widget.surahNumber);
    if (!mounted) return;
    if (local != null) {
      setState(() {
        _audioUri = local;
        _isDownloaded = true;
      });
    } else if (available == null) {
      setState(() => _loadError = 'تعذّر تحميل معلومات التلاوة.');
    }
  }

  Future<void> _markLastRead() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      'athan-libya:last-read',
      '{"surahNumber":${widget.surahNumber},"at":"${DateTime.now().toIso8601String()}"}',
    );
  }

  Future<void> _chooseReciter() async {
    if (_reciters.length < 2) return;
    final colors = AppColors.of(context);
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Text(
                      'اختر القارئ',
                      style: appText(sheetContext,
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _reciters.length,
                      itemBuilder: (_, i) {
                        final selected = i == _reciterIndex;
                        return ListTile(
                          title: Text(
                            _reciters[i].name,
                            style: appText(
                              sheetContext,
                              fontSize: 15,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w400,
                              color: selected ? colors.primary : null,
                            ),
                          ),
                          trailing: selected
                              ? Icon(Icons.check_circle, color: colors.primary)
                              : null,
                          onTap: () => Navigator.of(sheetContext).pop(i),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked == null || picked == _reciterIndex || !mounted) return;
    await _player.pause();
    setState(() {
      _reciterIndex = picked;
      _isDownloaded = false;
      _audioUri = null;
      _loadError = null;
    });
    final localAudio =
        await getDownloadedSurahAudio(widget.surahNumber, _reciters[picked].id);
    if (localAudio != null && mounted && _reciterIndex == picked) {
      setState(() {
        _audioUri = localAudio;
        _isDownloaded = true;
      });
    }
  }

  Future<void> _startPlayback() async {
    final uri = _audioUri ??
        (_reciter != null
            ? getRecitationUrl(_reciter!, widget.surahNumber)
            : null);
    if (uri == null) {
      setState(
          () => _loadError = 'لا يوجد تسجيل محفوظ، وقائمة القرّاء غير متاحة دون اتصال.');
      return;
    }
    try {
      await _player.setUrlAndPlay(uri);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _loadError = 'تعذّر تشغيل التسجيل. جرّب الاتصال بالإنترنت أو أعد تنزيله.');
      }
    }
  }

  Future<void> _downloadAudio() async {
    final reciter = _reciter;
    if (reciter == null) {
      setState(() =>
          _loadError = 'قائمة القرّاء غير متاحة الآن. اتصل بالإنترنت وحاول مجددًا.');
      return;
    }
    setState(() {
      _isDownloading = true;
      _loadError = null;
    });
    try {
      final uri = await downloadSurahAudio(
        widget.surahNumber,
        getRecitationUrl(reciter, widget.surahNumber),
        reciter.id,
      );
      if (!mounted) return;
      setState(() {
        _audioUri = uri;
        _isDownloaded = true;
      });
      final content = QuranData.getSurah(widget.surahNumber);
      if (mounted && context.mounted && content != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('اكتمل التنزيل: حُفظ تسجيل سورة ${content.surah.nameAr} للاستماع دون إنترنت.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _loadError = error is Exception && '$error'.contains('متصفح')
                ? 'التخزين دون إنترنت غير متاح في هذا المتصفح.'
                : 'تعذّر تنزيل التسجيل.');
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prefs = context.watch<AppSettings>().preferences;
    final content = QuranData.getSurah(widget.surahNumber);

    if (content == null) {
      return const Screen(children: [PageTitle(title: 'السورة غير موجودة')]);
    }

    final fontScale = prefs.quranFontScale;
    final basmalahSize = 24.0 + fontScale * 2;
    final ayahSize = 23.0 + fontScale * 2;

    return Screen(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_forward),
              color: colors.foreground,
            ),
            Expanded(
              child: PageTitle(
                title: content.surah.nameAr,
                subtitle:
                    '${toArabicDigits(content.surah.ayahCount)} آية · رواية قالون',
              ),
            ),
          ],
        ),

        // Audio card
        CardX(
          child: Column(
            spacing: 13,
            children: [
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 4,
                      children: [
                        Text(
                          _reciter?.name ?? 'تلاوة قالون',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.foreground,
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                        Text(
                          _isDownloaded
                              ? 'محفوظ على هذا الجهاز'
                              : 'يلزم الاتصال لتنزيل التلاوة',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.mutedForeground,
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['NotoSansArabic'],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (_playing) {
                          _player.pause();
                          setState(() => _playing = false);
                        } else {
                          _startPlayback();
                        }
                      },
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(
                          _playing ? Icons.pause : Icons.play_arrow,
                          size: 21,
                          color: colors.primaryForeground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                spacing: 9,
                children: [
                  Expanded(
                    child: ActionButton(
                      label: _isDownloaded
                          ? 'محفوظ دون إنترنت'
                          : (_isDownloading ? 'جارٍ التنزيل' : 'تنزيل السورة'),
                      secondary: true,
                      disabled: _isDownloaded || _isDownloading,
                      busy: _isDownloading,
                      icon: _isDownloaded
                          ? Icons.check_circle_outline
                          : Icons.download_outlined,
                      onPress: _downloadAudio,
                    ),
                  ),
                  if (_reciters.length > 1)
                    Expanded(
                      child: ActionButton(
                        label: 'تغيير القارئ',
                        secondary: true,
                        icon: Icons.person_outline,
                        onPress: _chooseReciter,
                      ),
                    ),
                ],
              ),
              if (_loadError != null)
                Text(
                  _loadError!,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    height: 20 / 13,
                    color: colors.destructive,
                    fontFamily: 'Inter',
                    fontFamilyFallback: const ['NotoSansArabic'],
                  ),
                ),
              if (_reciter == null && _loadError == null)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: colors.primary,
                  ),
                ),
            ],
          ),
        ),

        if (content.basmalah != null)
          Text(
            content.basmalah!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: basmalahSize,
              height: 2.0,
              color: colors.primary,
              fontFamily: 'UthmanicQaloun',
            ),
          ),

        CardX(
          padding: const EdgeInsets.all(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: colors.primary, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  for (final ayah in content.ayahs) ...[
                    TextSpan(text: '${ayah.text} '),
                    TextSpan(
                      text: '\u06DD${toArabicDigits(ayah.number)} ',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                        fontFamily: 'UthmanicQaloun',
                      ),
                    ),
                  ],
                ],
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.justify,
              style: TextStyle(
                fontSize: ayahSize,
                height: 2.1,
                color: colors.foreground,
                fontFamily: 'UthmanicQaloun',
              ),
            ),
          ),
        ),
        Text(
          'نص قالون عن نافع من بيانات المصحف الموثقة من مجمع الملك فهد، والتلاوات من MP3Quran.',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 11,
            height: 18 / 11,
            color: colors.mutedForeground,
            fontFamily: 'Inter',
            fontFamilyFallback: const ['NotoSansArabic'],
          ),
        ),
      ],
    );
  }
}