# Contributing

Thanks for looking. Tangelo is a small personal project, so keep changes small too.

1. Run `scripts/test.sh` before and after your change.
2. A new format is a new `Converter` in `Sources/TangeloCore`, plus a test that converts a real file in `Tests/Fixtures`.
3. Do not add a dependency or a downloaded tool without a pinned SHA-256 in `scripts/fetch-tools.sh`.
4. Open a pull request and say how you checked it.
