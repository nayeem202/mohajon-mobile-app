import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Builds an [http.Client] that trusts the Haalkhata self-signed CA
/// (bundled as an asset) in addition to the platform root certificates.
///
/// `dart:io` (and therefore `package:http`) does not read Android's network
/// security config, so the CA must be loaded explicitly. The context is
/// created with the platform roots so every other HTTPS endpoint keeps
/// working normally.
Future<http.Client> createSecureHttpClient() async {
  final pem = await rootBundle.loadString('assets/certs/haalkhata_ca.pem');

  // setTrustedCertificatesBytes accepts PEM data on all supported platforms
  // (converting the PEM to DER fails on recent Dart versions with
  // BAD_PKCS12_DATA). Pass the raw PEM bytes.
  final context = SecurityContext(withTrustedRoots: true);
  context.setTrustedCertificatesBytes(utf8.encode(pem));

  return IOClient(HttpClient(context: context));
}

Future<http.Client>? _cachedClient;

/// Lazily-created, cached secure client shared by all API callers.
Future<http.Client> secureHttpClient() =>
    _cachedClient ??= createSecureHttpClient();
