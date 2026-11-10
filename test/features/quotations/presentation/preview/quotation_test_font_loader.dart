import 'package:flutter/services.dart';

Future<void> loadQuotationTestFonts() async {
  final loader = FontLoader('IBM Plex Sans Condensed')
    ..addFont(
      rootBundle.load(
        'assets/fonts/ibm_plex_sans_condensed/IBMPlexSansCondensed-Regular.ttf',
      ),
    )
    ..addFont(
      rootBundle.load(
        'assets/fonts/ibm_plex_sans_condensed/IBMPlexSansCondensed-Medium.ttf',
      ),
    );
  await loader.load();
}
