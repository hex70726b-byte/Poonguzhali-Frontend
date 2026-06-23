import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

class AppConfig {
  static const String baseUrl = 'https://poonguzhali-backend.onrender.com';
  // static const String baseUrl = 'http://192.168.1.34:5000';

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

void showTopSnackBar(BuildContext context, SnackBar snackBar) {
  final overlayState = Overlay.of(context);
  
  final contentWidget = snackBar.content;
  final bgColor = snackBar.backgroundColor ?? AppColors.blueAccent;
  final duration = snackBar.duration;
  
  late OverlayEntry overlayEntry;
  
  overlayEntry = OverlayEntry(
    builder: (context) {
      return _TopSnackBarOverlay(
        content: contentWidget,
        backgroundColor: bgColor,
        duration: duration,
        onDismiss: () {
          overlayEntry.remove();
        },
      );
    },
  );
  
  overlayState.insert(overlayEntry);
}

class _TopSnackBarOverlay extends StatefulWidget {
  final Widget content;
  final Color backgroundColor;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopSnackBarOverlay({
    required this.content,
    required this.backgroundColor,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopSnackBarOverlay> createState() => _TopSnackBarOverlayState();
}

class _TopSnackBarOverlayState extends State<_TopSnackBarOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    _timer = Timer(widget.duration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (_controller.isAnimating) return;
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    
    return Positioned(
      top: topPadding + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: GestureDetector(
          onTap: _dismiss,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
              _dismiss();
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                child: Row(
                  children: [
                    Expanded(child: widget.content),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
