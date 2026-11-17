import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extracts an invitation token from an incoming deep link URI.
///
/// Primary format:
/// `multido://groups/invitations/{token}`
///
/// Backwards-compatible legacy format:
/// `obsidiantodo://invite/{token}`
String? parseInvitationToken(Uri uri) {
  final scheme = uri.scheme.toLowerCase();

  if (scheme == 'multido') {
    // Standard format: multido://groups/invitations/<token>
    // uri.host = 'groups', uri.pathSegments = ['invitations', '<token>']
    if (uri.host.toLowerCase() == 'groups') {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2 &&
          segments[0].toLowerCase() == 'invitations' &&
          segments[1].trim().isNotEmpty) {
        return segments[1].trim();
      }
    }

    // Direct path format: multido:///groups/invitations/<token> (empty host)
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 3 &&
        segments[0].toLowerCase() == 'groups' &&
        segments[1].toLowerCase() == 'invitations' &&
        segments[2].trim().isNotEmpty) {
      return segments[2].trim();
    }
  } else if (scheme == 'obsidiantodo') {
    // Legacy fallback: obsidiantodo://invite/<token>
    if (uri.host.toLowerCase() == 'invite') {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty && segments[0].trim().isNotEmpty) {
        return segments[0].trim();
      }
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 &&
        segments[0].toLowerCase() == 'invite' &&
        segments[1].trim().isNotEmpty) {
      return segments[1].trim();
    }
  }

  return null;
}

/// Provides a stream of incoming deep-link URIs via [AppLinks].
/// Each emission is a validated invitation token string.
///
/// The provider is `autoDispose: false` so it survives across the entire app
/// lifecycle without re-subscribing.
final deepLinkTokenProvider = StreamProvider<String>((ref) {
  final appLinks = AppLinks();
  final controller = StreamController<String>();

  // Cold start: check if the app was launched from a deep link.
  appLinks.getInitialLink().then((uri) {
    if (uri != null) {
      final token = parseInvitationToken(uri);
      if (token != null) controller.add(token);
    }
  });

  // Warm resume: listen for links while the app is running.
  final sub = appLinks.uriLinkStream.listen((uri) {
    final token = parseInvitationToken(uri);
    if (token != null) controller.add(token);
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});
