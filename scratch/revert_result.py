import re

file_path = r"c:\Users\Bubai Das\Desktop\programming\Project\CropDect_AI\cropdect\lib\screens\detection_result_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Revert TranslatedText( back to Text( in detection_result_screen.dart
new_content = re.sub(r'\bTranslatedText\(', 'Text(', content)

# Remove the import for translated_text.dart if it exists
new_content = re.sub(r"import '\.\./widgets/translated_text\.dart';\n?", "", new_content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Reverted TranslatedText back to Text in detection_result_screen.dart")
