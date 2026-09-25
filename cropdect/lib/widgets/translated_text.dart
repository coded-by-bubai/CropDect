import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translator/translator.dart';
import '../main.dart'; // To access LanguageState

class TranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? languageOverride;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.languageOverride,
  });

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  String _translated = '';
  String _lastLang = '';
  String _lastRawText = '';
  bool _isTranslating = false;

  final GoogleTranslator _translator = GoogleTranslator();

  @override
  void initState() {
    super.initState();
    _translated = widget.text;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _triggerTranslationIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.languageOverride != widget.languageOverride) {
      _triggerTranslationIfNeeded();
    }
  }

  static final Map<String, String> _cache = {};

  Future<void> _triggerTranslationIfNeeded() async {
    // Watch is handled in build, read state here
    final langState = context.read<LanguageState>();
    final currentLang = widget.languageOverride ?? langState.currentLanguage;

    String replaceDigits(String input, String langCode) {
      if (langCode == 'en') return input;
      const hindiDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
      const bengaliDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
      const teluguDigits = ['౦', '౧', '౨', '౩', '౪', '౫', '౬', '౭', '౮', '౯'];
      
      List<String> targetDigits;
      if (langCode == 'hi' || langCode == 'mr') targetDigits = hindiDigits;
      else if (langCode == 'bn') targetDigits = bengaliDigits;
      else if (langCode == 'te') targetDigits = teluguDigits;
      else return input;

      String output = input;
      for (int i = 0; i < 10; i++) output = output.replaceAll(i.toString(), targetDigits[i]);
      return output;
    }

    if (currentLang == 'en') {
      if (mounted) {
        setState(() {
          _translated = widget.text;
          _lastLang = 'en';
          _lastRawText = widget.text;
          _isTranslating = false;
        });
      }
      return;
    }

    if (_lastLang == currentLang && _lastRawText == widget.text) return;

    final cacheKey = '$currentLang|${widget.text}';
    if (_cache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _translated = replaceDigits(_cache[cacheKey]!, currentLang);
          _lastLang = currentLang;
          _lastRawText = widget.text;
          _isTranslating = false;
        });
      }
      return;
    }

    setState(() {
      _isTranslating = true;
      _lastLang = currentLang;
      _lastRawText = widget.text;
    });

    try {
      final tResult = await _translator.translate(widget.text, to: currentLang);
      _cache[cacheKey] = tResult.text;
      
      if (mounted) {
        setState(() {
          _translated = replaceDigits(tResult.text, currentLang);
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translated = replaceDigits(widget.text, currentLang);
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for language changes
    context.watch<LanguageState>();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _translated,
        key: ValueKey<String>('$_lastLang-$_translated'),
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      ),
    );
  }
}
