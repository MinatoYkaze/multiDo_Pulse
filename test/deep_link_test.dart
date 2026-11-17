import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/router/app_router.dart';
import 'package:obsidian_todo/core/services/deep_link_service.dart';

void main() {
  group('parseInvitationToken', () {
    test('extracts token from standard multido://groups/invitations/<token>', () {
      final uri = Uri.parse('multido://groups/invitations/abc123xyz');
      expect(parseInvitationToken(uri), 'abc123xyz');
    });

    test('extracts token with URL-safe characters and base64url padding', () {
      final uri = Uri.parse(
          'multido://groups/invitations/aB3-_dEf0123456789012345678901234');
      expect(parseInvitationToken(uri),
          'aB3-_dEf0123456789012345678901234');
    });

    test('handles trailing slash cleanly', () {
      final uri = Uri.parse('multido://groups/invitations/abc123xyz/');
      expect(parseInvitationToken(uri), 'abc123xyz');
    });

    test('handles URI with query parameters and fragments', () {
      final uri = Uri.parse(
          'multido://groups/invitations/abc123xyz?source=email#target');
      expect(parseInvitationToken(uri), 'abc123xyz');
    });

    test('handles URI without host authority (multido:///groups/invitations/<token>)', () {
      final uri = Uri.parse('multido:///groups/invitations/abc123xyz');
      expect(parseInvitationToken(uri), 'abc123xyz');
    });

    test('parses backwards-compatible legacy obsidiantodo://invite/<token>', () {
      final uri = Uri.parse('obsidiantodo://invite/legacy-token-456');
      expect(parseInvitationToken(uri), 'legacy-token-456');
    });

    test('parses legacy obsidiantodo://invite/<token>/ with trailing slash', () {
      final uri = Uri.parse('obsidiantodo://invite/legacy-token-456/');
      expect(parseInvitationToken(uri), 'legacy-token-456');
    });

    test('returns null for unrelated HTTP/HTTPS scheme', () {
      final uri = Uri.parse('https://example.com/groups/invitations/token');
      expect(parseInvitationToken(uri), isNull);
    });

    test('returns null for missing token segment in multido', () {
      final uri = Uri.parse('multido://groups/invitations');
      expect(parseInvitationToken(uri), isNull);
    });

    test('returns null for empty token segment in multido', () {
      final uri = Uri.parse('multido://groups/invitations/');
      expect(parseInvitationToken(uri), isNull);
    });

    test('returns null for wrong path in multido', () {
      final uri = Uri.parse('multido://settings/theme');
      expect(parseInvitationToken(uri), isNull);
    });

    test('returns null for bare multido scheme', () {
      final uri = Uri.parse('multido://');
      expect(parseInvitationToken(uri), isNull);
    });

    test('returns null for missing token in legacy obsidiantodo', () {
      final uri = Uri.parse('obsidiantodo://invite');
      expect(parseInvitationToken(uri), isNull);
    });

    test('returns null for empty token in legacy obsidiantodo', () {
      final uri = Uri.parse('obsidiantodo://invite/');
      expect(parseInvitationToken(uri), isNull);
    });
  });

  group('Web Route Tests', () {
    test('Routes.invite returns canonical web route /groups/invitations/:token', () {
      expect(Routes.invite('xyz789'), '/groups/invitations/xyz789');
    });

    test('Routes.legacyInvite preserves backward compatibility', () {
      expect(Routes.legacyInvite('xyz789'), '/invite/xyz789');
    });
  });
}
