import os
import re

screens_dir = r"c:\Users\Bubai Das\Desktop\programming\Project\CropDect_AI\cropdect\lib\screens"

# Regex to match Text(
text_regex = re.compile(r'\bText\(')
# Regex to check if we already imported TranslatedText
import_regex = re.compile(r"import '([^']*)translated_text\.dart';")

for filename in os.listdir(screens_dir):
    if filename.endswith(".dart"):
        file_path = os.path.join(screens_dir, filename)
        
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        if 'TranslatedText(' not in content and 'Text(' not in content:
            continue
            
        new_content = text_regex.sub('TranslatedText(', content)
        
        # Add import if missing and we actually use TranslatedText
        if 'TranslatedText(' in new_content and not import_regex.search(new_content):
            # Find the last import statement
            last_import_idx = new_content.rfind("import '")
            if last_import_idx != -1:
                end_of_line = new_content.find('\n', last_import_idx)
                if end_of_line != -1:
                    import_str = "\nimport '../widgets/translated_text.dart';"
                    new_content = new_content[:end_of_line] + import_str + new_content[end_of_line:]
            else:
                new_content = "import '../widgets/translated_text.dart';\n" + new_content

        if content != new_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated {filename}")

print("Done updating all screens!")
