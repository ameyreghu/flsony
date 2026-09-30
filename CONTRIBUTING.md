# Contributing

Thanks for helping. A few conventions keep FlSony consistent.

## How the code is split

- **Sony's protocol lives in Dart** (`lib/core`): framing, handshake, commands
  and parsing.
- **Native code is a thin byte pipe** plus small OS integrations. The contract
  is in [docs/platform-bridge.md](docs/platform-bridge.md). A new platform
  only needs that bridge.
- **UI** is in `lib/ui`. Colours come from the theme (`context.colors`), never
  hard-coded, so light/dark and the accent colour keep working.

## Features

- **Matching Sony's app**: features that exist in Sony's Sound Connect go in
  the main screen.
- **Extras**: anything Sound Connect doesn't have goes in **Settings → Extras**,
  **off by default**, with a toggle.

## Talking to the headphones

- Only send **write** commands that have been confirmed on real headphones.
  Read-only queries are fine for exploring; say in the code when a parser is
  unverified.
- Space out bursts of commands (see `applyProfile`).
- Never block the platform thread (see the bridge doc for why).

## Before you commit

```sh
dart format lib test
flutter analyze
flutter test
```

Keep commits small and focused, one change per commit, with a message that
says why.
