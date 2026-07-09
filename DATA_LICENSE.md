# Data License

`assets/word-bank-v6.txt` is generated from these inputs:

- Playable ranking source: https://www.top10000words.com/french/top-10000-french-words
- Playable source note: Google Books frequency list published by Top10000Words.com; no explicit content license was found.
- Ambiguity dictionary: FrequencyWords/OpenSubtitles French corpus, `content/2018/fr/fr_50k.txt`
- Ambiguity dictionary commit: `525f9b560de45753a5ea01069454e72e9aa541c6`
- Ambiguity dictionary URL: https://raw.githubusercontent.com/hermitdave/FrequencyWords/525f9b560de45753a5ea01069454e72e9aa541c6/content/2018/fr/fr_50k.txt

The FrequencyWords code is MIT licensed. Its generated word-frequency content is licensed under Creative Commons Attribution-ShareAlike 4.0 International.

- CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/

## Attribution

Top10000Words.com publishes the playable French ranking. FrequencyWords by Hermit Dave and contributors provides the OpenSubtitles-derived ambiguity dictionary.

## Modifications

The 18 Mots word bank keeps the Top10000Words ranking order, then applies these transformations:

- lowercases entries and expands `œ` to `oe`
- keeps alphabetic French words from 4 to 9 letters
- keeps only entries also present in the FrequencyWords/OpenSubtitles dictionary
- removes a small deny-list of unsuitable words and names
- removes entries whose accent-insensitive sorted-letter signature is shared by another known candidate
- writes one playable word per line with metadata comments
