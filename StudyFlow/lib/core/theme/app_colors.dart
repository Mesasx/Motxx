import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // === Light theme - warm base with a more present sage/emerald secondary ===
  static const Color background = Color(0xFFFAF9F5); // Crema cálido
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt =
      Color(0xFFF1F5EC); // Verde crema para tarjetas alternas
  static const Color primary = Color(0xFFCC785C); // Terracota/coral Claude
  static const Color primaryDark = Color(0xFFB8654A);
  static const Color accent = Color(0xFFDDEBD2); // Verde pálido
  static const Color secondary =
      Color(0xFF3F8F6B); // Verde salvia más protagonista
  static const Color secondaryDark = Color(0xFF2F6F53);
  static const Color secondarySoft = Color(0xFFE5F1E8);
  static const Color textDark = Color(0xFF1F1E1D); // Casi negro cálido
  static const Color textBody = Color(0xFF3D3D3A);
  static const Color textMuted = Color(0xFF8B8680);
  static const Color border = Color(0xFFE1E7D9);
  static const Color borderSubtle = Color(0xFFEAF0E4);
  static const Color error = Color(0xFFD97B6C);
  static const Color success = Color(0xFF3F8F6B);
  static const Color warning = Color(0xFFE0B070);

  // === Dark theme ===
  static const Color darkBackground = Color(0xFF171A16);
  static const Color darkSurface = Color(0xFF22261F);
  static const Color darkSurfaceAlt = Color(0xFF2A3027);
  static const Color darkBorder = Color(0xFF354033);
  static const Color darkText = Color(0xFFF5F1E8);
  static const Color darkTextMuted = Color(0xFFA2A995);

  // === Subject colors (warm + green-forward palette) ===
  static const List<Color> subjectPalette = [
    Color(0xFFCC785C), // Terracota
    Color(0xFF3F8F6B), // Verde salvia protagonista
    Color(0xFF6FA47A), // Verde hoja
    Color(0xFFE0B070), // Mostaza
    Color(0xFFB494C8), // Lavanda
    Color(0xFF6B9BB5), // Azul polvo
    Color(0xFFE8A87C), // Melocotón
    Color(0xFF8FAF68), // Verde musgo
  ];

  // === Gradient para elementos hero ===
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFCC785C), Color(0xFF3F8F6B)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3F8F6B), Color(0xFF8FAF68)],
  );

  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFAF9F5), Color(0xFFEAF3E6)],
  );
}
