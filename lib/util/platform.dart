import 'package:flutter/foundation.dart';

/// True only when running as a *native* Android app — false on web,
/// iOS, desktop, and anywhere else. Use this instead of
/// `dart:io`'s `Platform.isAndroid`, which throws `UnsupportedError`
/// on web.
bool get isNativeAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// True only when running as a native iOS app.
bool get isNativeIOS =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// True only when running as a native macOS app.
bool get isNativeMacOS =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// True only when running as a native Windows app.
bool get isNativeWindows =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// True only when running as a native Linux app.
bool get isNativeLinux =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;