import re

file_path = r"c:\Users\Bubai Das\Desktop\programming\Project\CropDect_AI\cropdect\lib\screens\onboarding_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = """                // Skip Button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _completeOnboarding();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      child: TranslatedText(
                        'SKIP',
                        style: GoogleFonts.manrope(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),"""

replacement = """                // Top Bar: Language Selector & Skip Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Language Selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: context.watch<LanguageState>().currentLanguage,
                            icon: const Icon(Icons.language, color: Colors.white70, size: 18),
                            dropdownColor: const Color(0xFF04160F),
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                            items: const [
                              DropdownMenuItem(value: 'en', child: Text(' English')),
                              DropdownMenuItem(value: 'hi', child: Text(' हिंदी')),
                              DropdownMenuItem(value: 'bn', child: Text(' বাংলা')),
                              DropdownMenuItem(value: 'mr', child: Text(' मराठी')),
                              DropdownMenuItem(value: 'te', child: Text(' తెలుగు')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                context.read<LanguageState>().changeLanguage(val);
                              }
                            },
                          ),
                        ),
                      ),
                      // Skip Button
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _completeOnboarding();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                        ),
                        child: TranslatedText(
                          'SKIP',
                          style: GoogleFonts.manrope(
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),"""

content = content.replace(target, replacement)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated Onboarding")
