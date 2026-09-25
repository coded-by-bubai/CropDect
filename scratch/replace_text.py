import re

file_path = r"c:\Users\Bubai Das\Desktop\programming\Project\CropDect_AI\cropdect\lib\screens\profile_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace all exact Text( with TranslatedText(
# Make sure we don't replace RichText or TextField etc.
# We want exactly "Text(" but could have spaces.
new_content = re.sub(r'\bText\(', 'TranslatedText(', content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Replaced all Text() with TranslatedText() in profile_screen.dart")
