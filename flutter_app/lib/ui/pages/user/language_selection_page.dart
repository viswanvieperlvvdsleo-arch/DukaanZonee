import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ink),
        title: const Text(
          'Select Language',
          style: TextStyle(color: ink, fontWeight: FontWeight.w900),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: supportedLanguages.length,
        itemBuilder: (context, index) {
          final lang = supportedLanguages[index];
          return ValueListenableBuilder<AppLanguage>(
            valueListenable: localizationService.currentLanguage,
            builder: (context, current, _) {
              final isSelected = current.code == lang.code;
              return InkWell(
                onTap: () {
                  localizationService.setLanguage(lang);
                  settingsPreferencesService.savePatch({
                    'appLanguage': lang.code,
                  });
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary.withOpacity(0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? primary : Colors.white,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? shadowSm
                        : shadowSm.map((e) => e.scale(0.5)).toList(),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(lang.flag, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      Text(
                        lang.nativeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        lang.name,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
