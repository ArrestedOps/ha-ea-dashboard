# v4.7.2 — Maximum Debug Logging

## 🐛 Debugging
- **Pre-parse logging**: Captures raw request BEFORE any JSON parsing
- **Complete data dump**: First 2000 chars of raw webhook data
- **Full traceback**: Complete error stack trace
- **All headers**: Logs all HTTP headers

This will show EXACTLY what MT4 is sending, even if it's malformed.
