import 'dart:convert';
import 'package:flutter/material.dart';

class AppConfig {
  static const String baseUrl = 'https://poonguzhali-backend.onrender.com';

  static ImageProvider? getImageProvider(String photoStr) {
    final cleanStr = photoStr.trim();
    if (cleanStr.isEmpty) return null;
    
    // Check if it is a base64 data URI
    if (cleanStr.startsWith('data:image/')) {
      final commaIndex = cleanStr.indexOf(',');
      if (commaIndex != -1) {
        try {
          final base64Str = cleanStr.substring(commaIndex + 1);
          final bytes = base64Decode(base64Str);
          return MemoryImage(bytes);
        } catch (_) {
          return null;
        }
      }
    }
    
    // Check if it is a raw base64 string
    if (!cleanStr.startsWith('http') && cleanStr.length > 50) {
      try {
        final bytes = base64Decode(cleanStr);
        return MemoryImage(bytes);
      } catch (_) {
        // Fallback or ignore
      }
    }
    
    // Default to NetworkImage if it starts with http
    if (cleanStr.startsWith('http')) {
      return NetworkImage(cleanStr);
    }
    
    return null;
  }
}

class AppColors {
  // Centralized Branding Theme Colors (Modern Sky Blue & Royal Blue / Indigo Accents)
  static const Color primary = Colors.blue;
  static const Color royalBlue = Color(0xFF1A237E);
  static const Color skyBlue = Color(0xFF00B0FF);
  static const Color indigoAccent = Colors.indigoAccent;
  static const Color lightBlueAccent = Colors.lightBlueAccent;
  static const Color blueAccent = Colors.blueAccent;

  // Global Premium Dark Theme Backgrounds & Surfaces
  static const Color scaffoldBackground = Color(0xFF121212);
  static const Color surfaceCard = Color(0xFF1E1E1E);
  static const Color surfaceSecondary = Color(0xFF151515);
  static const Color surfaceTertiary = Color(0xFF1C1C1C);
  static const Color darkDivider = Color(0xFF0B0F12);

  // Chat Module & WhatsApp Themed UI
  static const Color chatBg = Color(0xFF0B141A);
  static const Color chatSurface = Color(0xFF1F2C34);
  static const Color chatAccent = Color(0xFF1EAC61);
}
