# 18 Mots

18 Mots is a French daily word puzzle. Each day gives the same sequence of 18 shuffled words to every player. You have 30 seconds per word, and your result is stored locally in the browser.

The game is inspired by the original English game [18 Words](https://18words.com/). This project is independent and is not affiliated with 18 Words.

## Development

```sh
gleam test
gleam run -m lustre/dev start
gleam run -m lustre/dev build
node scripts/generate-word-bank.js
```

## Architecture

- `src/dixhuit_mots.gleam`: Lustre application, screens, updates, and views.
- `src/dixhuit_mots/puzzle.gleam`: deterministic daily puzzle generation.
- `src/dixhuit_mots/storage.gleam`: local result encoding and decoding.
- `src/dixhuit_mots.ffi.mjs`: browser APIs for fetching, dates, sharing, and localStorage.
- `assets/`: static files copied into `dist/` by the Lustre build.

## Deployment

Build the static site with `gleam run -m lustre/dev build`, then deploy `dist/`. The word bank is versioned by filename. Released bank files are immutable; corrections use a new `word-bank-vN.txt` name.

## Licenses

Project code and original assets are MIT licensed. See `LICENSE`.

`assets/word-bank-v6.txt` is generated from a Top10000Words ranking with a FrequencyWords/OpenSubtitles ambiguity dictionary. See `DATA_LICENSE.md` for source and license notes.
