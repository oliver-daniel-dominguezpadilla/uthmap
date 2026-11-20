import 'package:flutter/material.dart';

import 'theme.dart';

class PhotoCredit {
  const PhotoCredit({
    required this.building,
    required this.author,
    required this.license,
  });

  final String building;
  final String author;
  final String license;
}

const List<PhotoCredit> photoCredits = [
  PhotoCredit(
    building: 'Edificio K',
    author: 'Fons Heijnsbroek',
    license: 'CC0 · Wikimedia Commons',
  ),
  PhotoCredit(
    building: 'Edificio L',
    author: 'PCHS-NJROTC',
    license: 'CC BY-SA 4.0 · Wikimedia Commons',
  ),
  PhotoCredit(
    building: 'Edificio M',
    author: 'Afrank4436',
    license: 'CC BY-SA 4.0 · Wikimedia Commons',
  ),
  PhotoCredit(
    building: 'Cafetería Central',
    author: 'Tomwsulcer',
    license: 'CC0 · Wikimedia Commons',
  ),
  PhotoCredit(
    building: 'Rectoría',
    author: 'Eminence190',
    license: 'CC0 · Wikimedia Commons',
  ),
];

Future<void> showCredits(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.page,
      surfaceTintColor: AppColors.page,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.lineSoft),
      ),
      title: const Text(
        'Créditos',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Fotografías de referencia',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.4,
                color: AppColors.dim,
              ),
            ),
            const SizedBox(height: 10),
            for (final credit in photoCredits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credit.building,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '${credit.author} · ${credit.license}',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AppColors.dim,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 20, color: AppColors.lineSoft),
            const Text(
              'Tipografías: Space Grotesk y Space Mono (SIL Open Font License). '
              'Mapa alternativo: © OpenStreetMap contributors (ODbL).',
              style: TextStyle(fontSize: 11, height: 1.5, color: AppColors.dim),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cerrar',
            style: TextStyle(fontSize: 12, color: AppColors.accent),
          ),
        ),
      ],
    ),
  );
}
