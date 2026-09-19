# Contributing

Thanks for contributing to get_it!

get_it is part of the [flutter_it](https://flutter-it.dev) construction set. Each package (`get_it`, `watch_it`, `command_it`, `listen_it`) lives in its own repository, so please open issues and pull requests in the repository of the package they concern.

## Setup

1. Fork and clone this repository.
2. Install dependencies with `flutter pub get`.
3. Make sure everything passes before opening a pull request (CI runs the same checks):

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Pull requests

- Open pull requests against the `main` branch.
- Keep changes focused and clearly described.
- Link related issues (for example `Fixes #123`).
- Add or update tests for behavior changes.
- Add an entry to `CHANGELOG.md` for user-facing changes.
- Update `README.md` or the docs at https://flutter-it.dev if the public API changes.
- Match the existing code style; run `dart format .` before committing.

## Questions

If you are unsure about an idea before investing time in it, open an issue first or ask in the flutter_it Discord: https://discord.gg/ZHYHYCM38h

## Conduct

Be respectful and constructive in reviews and discussions.
