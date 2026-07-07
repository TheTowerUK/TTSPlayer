import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/remote_fetch_errors.dart';
import 'package:ttsplayer/services/media_access/remote_url_security.dart';

void main() {
  group('RemoteUrlSecurity', () {
    test('accepts HTTPS catalogue URL', () {
      const url = 'https://nas.example:8443/catalog.json';
      final result = RemoteUrlSecurity.validateRemoteUrl(
        url,
        fieldPrefix: 'test',
        mode: MediaAccessMode.localPreferred,
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(RemoteUrlSecurity.isHttpsUrl(url), isTrue);
    });

    test('accepts HTTPS media base URL in httpRequired mode', () {
      const url = 'https://nas.example:8443/media/';
      final result = RemoteUrlSecurity.validateRemoteUrl(
        url,
        fieldPrefix: 'mediaAccess.httpMediaBaseUrl',
        mode: MediaAccessMode.httpRequired,
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('warns on plain HTTP in localPreferred mode', () {
      const url = 'http://192.168.178.130:8443/catalog.json';
      final result = RemoteUrlSecurity.validateRemoteUrl(
        url,
        fieldPrefix: 'catalogueProviders[1]',
        mode: MediaAccessMode.localPreferred,
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.first,
        contains(RemoteUrlSecurity.insecureHttpWarning),
      );
      expect(RemoteUrlSecurity.isPlainHttpUrl(url), isTrue);
    });

    test('rejects plain HTTP in httpRequired mode', () {
      const url = 'http://192.168.178.130:8443/media/';
      final result = RemoteUrlSecurity.validateRemoteUrl(
        url,
        fieldPrefix: 'mediaAccess.httpMediaBaseUrl',
        mode: MediaAccessMode.httpRequired,
      );

      expect(result.errors, isNotEmpty);
      expect(
        result.errors.first,
        contains(RemoteUrlSecurity.httpRequiredRejection),
      );
      expect(result.warnings, isEmpty);
    });

    test('rejects invalid scheme', () {
      final result = RemoteUrlSecurity.validateRemoteUrl(
        'ftp://bad.example/catalog.json',
        fieldPrefix: 'test',
        mode: MediaAccessMode.localPreferred,
      );

      expect(result.errors, isNotEmpty);
      expect(result.errors.first, contains('http or https'));
    });
  });

  group('RemoteFetchErrors', () {
    test('maps handshake failure to readable message', () {
      final message = RemoteFetchErrors.catalogueLoadMessage(
        HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        'https://nas.example:8443/catalog.json',
      );

      expect(message.toLowerCase(), contains('secure connection failed'));
      expect(message, contains('certificate'));
      expect(message, contains('https://nas.example:8443/catalog.json'));
    });

    test('maps timeout to readable message', () {
      final message = RemoteFetchErrors.catalogueLoadMessage(
        TimeoutException('timed out'),
        'https://nas.example/catalog.json',
      );

      expect(message.toLowerCase(), contains('timed out'));
    });
  });
}
