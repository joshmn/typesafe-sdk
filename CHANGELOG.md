## [Unreleased]

- `Score` and raw-hash score questions now require at least two levels, matching the API and the official SDKs

## [0.1.0] - 2026-09-16

- Initial release, mirroring the TypeSafe Python SDK 0.6.0
- `Client#system_one` for Noul, Choice, and Score questions, with typed answers
- `Client#models.list` for the models available to your account
- Retry policy with exponential backoff, jitter, `Retry-After` support, and a total retry budget
- Typed errors for every documented status, plus connection, timeout, and response validation errors
- Thread-safe, fork-aware keep-alive connection pool on `Net::HTTP`
- Standard library HTTP and JSON, with Zeitwerk as the only runtime dependency
