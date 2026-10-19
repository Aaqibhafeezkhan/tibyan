# Contributing to Tibyan · المساهمة في تبيان

شكرا لاهتمامك. Thank you for helping.

## Ways to help without code · طرق للمساعدة بلا برمجة

- **Recitation timings:** fix a word that lights up early or late in the [timing editor](https://helalrules7.github.io/tibyan/) ([guide](docs/TIMING_GUIDE.md)).
- **Qiraat audio:** mark the differing word in a verse clip ([guide, Arabic](docs/QIRAAT_AUDIO.md)).
- **Voice data:** record your recitation at [train.altibyan.app](https://train.altibyan.app) (published under CC BY 4.0).
- **Bugs and ideas:** open an [issue](https://github.com/helalrules7/tibyan/issues/new/choose).

## Rules for content · قواعد المحتوى

These are not negotiable:

1. **No AI-written religious content.** Do not generate, paraphrase or "fix" Quran, tafsir, qiraat or any scholarly text, by hand or with a tool. Every such text comes verbatim from a source listed in [`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md).
2. **No data without permission.** A new source needs its license or permission saved in [`docs/licenses/`](docs/licenses/) before it is used.
3. **Scholarly content needs a qualified reviewer** before it appears in the app.
4. **Never commit** secrets, `.env`, keystores (`*.jks`, `key.properties`), raw datasets or voice recordings.

## Code · الكود

1. Set up the project: [Build from source](README.md#build-from-source).
2. Branch from `main`. Keep one change per pull request.
3. Before pushing: `dart format .`, `flutter analyze` and `flutter test` must pass (CI runs the same).
4. Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) in English, e.g. `fix(mushaf): keep the page when the reciter changes`.
5. Every user-visible string goes in `lib/l10n/` (Arabic is the template; add the English too).
6. Every feature works in both the 1441 and 1405 Madina editions.
7. Add a line under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md) for user-visible changes.

## License

By contributing code you agree it is released under [GPL-3.0](LICENSE). Timing corrections are released under CC BY 4.0.
