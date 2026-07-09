import fs from "node:fs";

const PLAYABLE_SOURCE = "https://www.top10000words.com/french/top-10000-french-words";
const FREQUENCY_WORDS_COMMIT = "525f9b560de45753a5ea01069454e72e9aa541c6";
const AMBIGUITY_SOURCE = `https://raw.githubusercontent.com/hermitdave/FrequencyWords/${FREQUENCY_WORDS_COMMIT}/content/2018/fr/fr_50k.txt`;
const SOURCE_LIMIT = 3500;
const BANK_VERSION = "v6";
const OUTPUT = `assets/word-bank-${BANK_VERSION}.txt`;

const denyList = new Set(
  `that with from this have which these etat most under russie sieur jadis lieues vaisseau vaisseaux marquis clergé prêtres théologie monarchie souverain serment noblesse sûreté vertu vint reçut mourut répondit trouva voulut`
    .split(/\s+/)
    .filter(Boolean),
);

const normalizeWord = (word) => word.toLowerCase().replaceAll("œ", "oe");

const plain = (word) => normalizeWord(word).normalize("NFD").replace(/\p{M}/gu, "");

const signature = (word) => [...plain(word)].sort().join("");

const isCandidate = (word) => {
  const normalized = plain(word);
  return (
    word.length >= 4 && word.length <= 9 && /^\p{L}+$/u.test(word) && !denyList.has(normalized)
  );
};

async function topWords() {
  const html = await fetch(PLAYABLE_SOURCE).then((response) => response.text());
  return [...html.matchAll(/<li>\s*(?:<a[^>]*>)?([^<\n]+)(?:<\/a>)?\s*<\/li>/gi)].map((match) =>
    match[1].trim(),
  );
}

async function subtitleWords() {
  const text = await fetch(AMBIGUITY_SOURCE).then((response) => response.text());
  return text
    .split(/\n/)
    .map((line) => line.trim().split(/\s+/)[0])
    .filter(Boolean);
}

function ambiguitySignatures(words) {
  const signatures = new Map();

  for (const raw of words) {
    const word = normalizeWord(raw);
    if (!isCandidate(word)) continue;

    const key = signature(word);
    const matches = signatures.get(key) || new Set();
    matches.add(plain(word));
    signatures.set(key, matches);
  }

  return signatures;
}

function buildBank(playableWords, subtitleVocabulary, conflictSignatures) {
  const seen = new Set();
  const bank = [];

  for (const raw of playableWords.slice(0, SOURCE_LIMIT)) {
    if (raw !== raw.toLowerCase()) continue;

    const word = normalizeWord(raw);
    if (!isCandidate(word)) continue;
    if (!subtitleVocabulary.has(plain(word))) continue;

    const key = signature(word);
    if ((conflictSignatures.get(key)?.size || 0) > 1) continue;
    if (seen.has(key)) continue;

    seen.add(key);
    bank.push(word);
  }

  return bank;
}

function writeBank(words) {
  const header = [
    `# 18 Mots word bank ${BANK_VERSION}`,
    `# source: ${PLAYABLE_SOURCE}`,
    "# source_note: Google Books frequency list published by Top10000Words.com; no explicit content license found.",
    `# source_limit: first ${SOURCE_LIMIT} ranked entries`,
    `# ambiguity_dictionary: FrequencyWords/OpenSubtitles French 50k list at ${FREQUENCY_WORDS_COMMIT}`,
    "# ambiguity_dictionary_license: CC BY-SA 4.0",
    "# generated_at: 2026-07-10T00:00:00.000Z",
    "# selection: ranked French frequency list also present in the FrequencyWords/OpenSubtitles dictionary; source-capitalized entries excluded; lowercase 4-9 alphabetic words with œ expanded to oe; curated deny-list and all known shared accent-insensitive anagram signatures excluded.",
    "# format: one lowercase French word per line after this header.",
    "",
  ];

  fs.writeFileSync(OUTPUT, `${header.join("\n")}${words.join("\n")}\n`);
}

function printStats(words) {
  const counts = Map.groupBy(words, (word) => word.length);
  console.log(`Wrote ${OUTPUT}`);
  console.log(`word_count=${words.length}`);
  console.log(
    [4, 5, 6, 7, 8, 9].map((length) => `${length}=${counts.get(length)?.length || 0}`).join(" "),
  );
}

const playableWords = await topWords();
const subtitles = await subtitleWords();
const subtitleVocabulary = new Set(subtitles.map(plain));
const conflictSignatures = ambiguitySignatures([...playableWords, ...subtitles]);
const bank = buildBank(playableWords, subtitleVocabulary, conflictSignatures);

writeBank(bank);
printStats(bank);
