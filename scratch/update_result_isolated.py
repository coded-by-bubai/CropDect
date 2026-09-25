import re

file_path = r"c:\Users\Bubai Das\Desktop\programming\Project\CropDect_AI\cropdect\lib\screens\detection_result_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace Text( with TranslatedText(
content = re.sub(r'\bText\(', 'TranslatedText(', content)

# 2. Add import for TranslatedText if not present
if "import '../widgets/translated_text.dart';" not in content:
    content = content.replace("import '../main.dart';", "import '../main.dart';\nimport '../widgets/translated_text.dart';")

# 3. Add local _localLangState variable
state_var_decl = r"  late AnimationController _pulseController;"
state_var_new = r"  late LanguageState _localLangState;\n  late AnimationController _pulseController;"
content = content.replace(state_var_decl, state_var_new)

# 4. Initialize _localLangState in initState
init_state_old = r"""  @override
  void initState() {
    super.initState();
    
    // Inherit the global language preference for this screen by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedLanguage = context.read<LanguageState>().currentLanguage;
        });
      }
    });"""

init_state_new = r"""  @override
  void initState() {
    super.initState();
    
    // Initialize local language state for this screen ONLY, based on global setting
    _localLangState = LanguageState('en'); // Will be updated in post frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final globalLang = context.read<LanguageState>().currentLanguage;
        _localLangState = LanguageState(globalLang);
        setState(() {
          _selectedLanguage = globalLang;
        });
        _fetchIPMPlan(); // Re-fetch or translate based on new language
      }
    });"""
content = content.replace(init_state_old, init_state_new)

# 5. Remove _fetchIPMPlan() from bottom of initState since we call it in post frame now
fetch_ipm_old = r"""    _entranceController.forward();
    _initTts();
    _fetchIPMPlan();
  }"""
fetch_ipm_new = r"""    _entranceController.forward();
    _initTts();
  }"""
content = content.replace(fetch_ipm_old, fetch_ipm_new)

# 6. Wrap Scaffold in ChangeNotifierProvider
scaffold_old = r"    return Scaffold("
scaffold_new = r"""    return ChangeNotifierProvider<LanguageState>.value(
      value: _localLangState,
      child: Scaffold("""
content = content.replace(scaffold_old, scaffold_new)

# 7. Close the Scaffold wrap properly.
# The Scaffold ends at the end of _buildDesktopLayout and _buildMobileLayout.
# Since it's easier to just wrap the body or just wrap the entire build method.
# Wait, _buildDesktopLayout returns Scaffold, and _buildMobileLayout returns Scaffold.
# It's better to wrap it in the main `build` method!

build_method_old = r"""  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;
        return isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context);
      },
    );
  }"""

build_method_new = r"""  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LanguageState>.value(
      value: _localLangState,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          return isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context);
        },
      ),
    );
  }"""
content = content.replace(build_method_old, build_method_new)
content = content.replace(scaffold_new, scaffold_old) # Revert the Scaffold wrap if it applied

# 8. Update Dropdown on-change to update local state instead of global
dropdown_change_desktop = r"""                                setState(() => _selectedLanguage = val);
                                _translateContent();"""
dropdown_change_desktop_new = r"""                                setState(() => _selectedLanguage = val);
                                _localLangState.changeLanguage(val); // This won't affect global because it's local instance!
                                _translateContent();"""
content = content.replace(dropdown_change_desktop, dropdown_change_desktop_new)

# Make sure we replace both instances (mobile and desktop)
dropdown_change_mobile = r"""                                  setState(() => _selectedLanguage = val);
                                  _translateContent();"""
dropdown_change_mobile_new = r"""                                  setState(() => _selectedLanguage = val);
                                  _localLangState.changeLanguage(val);
                                  _translateContent();"""
content = content.replace(dropdown_change_mobile, dropdown_change_mobile_new)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated detection_result_screen.dart to use isolated local LanguageState")
