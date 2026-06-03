import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

/// An [http.Client] decorator that retries transient Google API failures
/// (HTTP 429 / 5xx) with truncated exponential backoff + jitter, honoring a
/// `Retry-After` header when present. Keeps us resilient against the per-user
/// Sheets quota (60 req/min) without hammering the API.
class BackoffClient extends http.BaseClient {
  BackoffClient(
    this._inner, {
    this.maxRetries = 4,
    this.baseDelay = const Duration(milliseconds: 500),
  });

  final http.Client _inner;
  final int maxRetries;
  final Duration baseDelay;

  static const Set<int> _retryable = {429, 500, 502, 503, 504};

  final _rand = Random();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // A streamed body can only be sent once; buffer it so retries can resend.
    final bodyBytes = await request.finalize().toBytes();

    var attempt = 0;
    while (true) {
      final response = await _inner.send(_clone(request, bodyBytes));
      if (!_retryable.contains(response.statusCode) || attempt >= maxRetries) {
        return response;
      }
      // Drain the failed response so the connection can be reused.
      await response.stream.drain<void>();
      await Future<void>.delayed(_delayFor(attempt, response));
      attempt++;
    }
  }

  http.BaseRequest _clone(http.BaseRequest original, List<int> bodyBytes) {
    final req = http.Request(original.method, original.url)
      ..headers.addAll(original.headers)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection
      ..bodyBytes = bodyBytes;
    return req;
  }

  Duration _delayFor(int attempt, http.StreamedResponse response) {
    final retryAfter = response.headers['retry-after'];
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter.trim());
      if (seconds != null) return Duration(seconds: seconds);
    }
    final expo = baseDelay * pow(2, attempt).toDouble();
    final jitter = Duration(milliseconds: _rand.nextInt(250));
    return expo + jitter;
  }

  @override
  void close() => _inner.close();
}
