import re

file_path = r"c:\Users\Bubai Das\Desktop\programming\Project\CropDect_AI\cropdect\lib\screens\detection_result_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace all exact Text( with TranslatedText(..., languageOverride: _selectedLanguage)
# Wait, Text('something', style: ...) -> TranslatedText('something', style: ..., languageOverride: _selectedLanguage)
# This is tricky with regex because Text() can span multiple lines.
# Instead of complex regex, let's just do a simpler replacement:
# Find "Text(" and replace with "TranslatedText(". 
# Then, since we know we want language override, we can just replace "TranslatedText(" with something? No.

# Actually, the easiest way to give detection_result_screen its own language is to just wrap the whole body in a local LanguageState Provider!
# BUT LanguageState is global. We could override it using Provider.value, but MultiProvider in main provides it.

# Another approach:
# Let's replace "TranslatedText(" with "TranslatedText(" in detection_result_screen.
# Then, we can find instances of "TranslatedText(" and change them to pass languageOverride?
# A better way is to do `new_content = re.sub(r'\bText\((.*?)\)', r'TranslatedText(\1, languageOverride: _selectedLanguage)', content, flags=re.DOTALL)`
# BUT that will fail if there are nested parentheses.

# Let's just do it with a simple regex for single-line Text() calls, or just manually modify the widget.
pass
