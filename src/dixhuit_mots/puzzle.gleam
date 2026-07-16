import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{Gt, Lt}
import gleam/string

pub const release_date = "2026-07-01"

pub const word_bank_version = "v6"

const four_letter_rounds = 2

const five_letter_rounds = 6

const six_letter_rounds = 6

const seven_letter_rounds = 2

const eight_letter_rounds = 1

const nine_letter_rounds = 1

const random_modulus = 2_147_483_647

const random_multiplier = 48_271

pub type WordBank {
  WordBank(
    four: List(String),
    five: List(String),
    six: List(String),
    seven: List(String),
    eight: List(String),
    nine: List(String),
  )
}

pub type Tile {
  Tile(id: Int, letter: String)
}

pub type Round {
  Round(number: Int, target: String, tiles: List(Tile))
}

type Random {
  Random(seed: Int)
}

pub fn parse_word_bank(contents: String) -> Result(WordBank, String) {
  let bank =
    contents
    |> string.split("\n")
    |> list.fold(empty_word_bank(), fn(bank, line) { add_line(bank, line) })

  case has_minimum_words(bank) {
    True -> Ok(bank)
    False ->
      Error("La liste de mots ne contient pas assez de mots par longueur.")
  }
}

pub fn is_available_date(date: String, today: String) -> Bool {
  string.length(date) == 10
  && is_on_or_after(date, release_date)
  && is_on_or_before(date, today)
}

pub fn generate(
  bank: WordBank,
  date: String,
  today: String,
) -> Result(List(Round), String) {
  case is_available_date(date, today) {
    False -> Error("Cette date ne fait pas partie des archives disponibles.")
    True -> {
      let random =
        Random(seed_from_key("18-mots|" <> word_bank_version <> "|" <> date))
      let #(four, after_four) =
        rounds_from_bucket(bank.four, 1, four_letter_rounds, random)
      let #(five, after_five) =
        rounds_from_bucket(bank.five, 3, five_letter_rounds, after_four)
      let #(six, after_six) =
        rounds_from_bucket(bank.six, 9, six_letter_rounds, after_five)
      let #(seven, after_seven) =
        rounds_from_bucket(bank.seven, 15, seven_letter_rounds, after_six)
      let #(eight, after_eight) =
        rounds_from_bucket(bank.eight, 17, eight_letter_rounds, after_seven)
      let #(nine, after_nine) =
        rounds_from_bucket(bank.nine, 18, nine_letter_rounds, after_eight)

      Ok(sort_then_soften_rounds(
        four,
        five,
        six,
        seven,
        eight,
        nine,
        after_nine,
      ))
    }
  }
}

pub fn round_at(rounds: List(Round), index: Int) -> Option(Round) {
  case rounds {
    [] -> None
    [round, ..rest] ->
      case index == 0 {
        True -> Some(round)
        False -> round_at(rest, index - 1)
      }
  }
}

pub fn tile_count(round: Round) -> Int {
  list.length(round.tiles)
}

pub fn selected_answer(round: Round, selected_ids: List(Int)) -> String {
  selected_letters(round.tiles, selected_ids)
  |> string.concat
}

pub fn is_correct_answer(round: Round, selected_ids: List(Int)) -> Bool {
  normalized_key(selected_answer(round, selected_ids))
  == normalized_key(round.target)
}

pub fn first_matching_unused_tile(
  round: Round,
  selected_ids: List(Int),
  key: String,
) -> Option(Int) {
  find_matching_tile(round.tiles, selected_ids, normalized_key(key))
}

pub fn tile_ids_for_answer(round: Round, answer: String) -> Option(List(Int)) {
  tile_ids_for_letters(round, string.to_graphemes(answer), [])
}

fn empty_word_bank() -> WordBank {
  WordBank(four: [], five: [], six: [], seven: [], eight: [], nine: [])
}

fn add_line(bank: WordBank, line: String) -> WordBank {
  let word = line |> string.trim |> string.lowercase

  case string.is_empty(word) || string.starts_with(word, "#") {
    True -> bank
    False -> add_word(bank, word)
  }
}

fn add_word(bank: WordBank, word: String) -> WordBank {
  case string.length(word) {
    4 -> WordBank(..bank, four: list.append(bank.four, [word]))
    5 -> WordBank(..bank, five: list.append(bank.five, [word]))
    6 -> WordBank(..bank, six: list.append(bank.six, [word]))
    7 -> WordBank(..bank, seven: list.append(bank.seven, [word]))
    8 -> WordBank(..bank, eight: list.append(bank.eight, [word]))
    9 -> WordBank(..bank, nine: list.append(bank.nine, [word]))
    _ -> bank
  }
}

fn has_minimum_words(bank: WordBank) -> Bool {
  list.length(bank.four) >= four_letter_rounds
  && list.length(bank.five) >= five_letter_rounds
  && list.length(bank.six) >= six_letter_rounds
  && list.length(bank.seven) >= seven_letter_rounds
  && list.length(bank.eight) >= eight_letter_rounds
  && list.length(bank.nine) >= nine_letter_rounds
}

fn rounds_from_bucket(
  words: List(String),
  first_number: Int,
  count: Int,
  random: Random,
) -> #(List(Round), Random) {
  pick_rounds(words, first_number, count, [], random, [])
}

fn sort_then_soften_rounds(
  four: List(Round),
  five: List(Round),
  six: List(Round),
  seven: List(Round),
  eight: List(Round),
  nine: List(Round),
  random: Random,
) -> List(Round) {
  let assert [four_a, four_b] = four
  let assert [five_a, five_b, five_c, five_d, five_e, five_f] = five
  let assert [six_a, six_b, six_c, six_d, six_e, six_f] = six
  let assert [seven_a, seven_b] = seven
  let assert [eight_a] = eight
  let assert [nine_a] = nine

  list.append(
    [four_a, four_b],
    list.append(
      soften_middle(
        [
          five_a,
          five_b,
          five_c,
          five_d,
          five_e,
          five_f,
          six_a,
          six_b,
          six_c,
          six_d,
          six_e,
          six_f,
        ],
        random,
      ),
      [seven_a, seven_b, eight_a, nine_a],
    ),
  )
  |> renumber_rounds(1)
}

fn soften_middle(rounds: List(Round), random: Random) -> List(Round) {
  let #(value, after_count) = next(random)
  do_invert_rounds(rounds, 2 + value % 3, after_count)
}

fn do_invert_rounds(
  rounds: List(Round),
  remaining: Int,
  random: Random,
) -> List(Round) {
  case remaining {
    0 -> rounds
    _ -> {
      let #(value, next_random) = next(random)
      let index = value % 11
      do_invert_rounds(swap_adjacent(rounds, index), remaining - 1, next_random)
    }
  }
}

fn swap_adjacent(rounds: List(Round), index: Int) -> List(Round) {
  case rounds, index {
    [left, right, ..rest], 0 -> [right, left, ..rest]
    [round, ..rest], _ -> [round, ..swap_adjacent(rest, index - 1)]
    [], _ -> []
  }
}

fn renumber_rounds(rounds: List(Round), number: Int) -> List(Round) {
  case rounds {
    [] -> []
    [round, ..rest] -> [
      Round(..round, number:),
      ..renumber_rounds(rest, number + 1)
    ]
  }
}

fn pick_rounds(
  words: List(String),
  number: Int,
  remaining: Int,
  picked_indexes: List(Int),
  random: Random,
  rounds: List(Round),
) -> #(List(Round), Random) {
  case remaining == 0 {
    True -> #(list.reverse(rounds), random)
    False -> {
      let #(value, next_random) = next(random)
      let index = value % list.length(words)

      case list.contains(picked_indexes, index) {
        True ->
          pick_rounds(
            words,
            number,
            remaining,
            picked_indexes,
            next_random,
            rounds,
          )
        False -> {
          let assert Some(word) = word_at(words, index)
          let #(round, after_round) = make_round(number, word, next_random)
          pick_rounds(
            words,
            number + 1,
            remaining - 1,
            [index, ..picked_indexes],
            after_round,
            [round, ..rounds],
          )
        }
      }
    }
  }
}

fn make_round(number: Int, target: String, random: Random) -> #(Round, Random) {
  let letters = string.to_graphemes(target)
  let #(shuffled, after_shuffle) = shuffle_until_changed(letters, random, 0)

  #(
    Round(number:, target:, tiles: tiles_from_letters(shuffled, 0)),
    after_shuffle,
  )
}

fn shuffle_until_changed(
  letters: List(String),
  random: Random,
  attempts: Int,
) -> #(List(String), Random) {
  let #(candidate, after_shuffle) = shuffle(letters, random)

  case candidate == letters && attempts < 3 {
    True -> shuffle_until_changed(letters, after_shuffle, attempts + 1)
    False -> #(candidate, after_shuffle)
  }
}

fn shuffle(letters: List(String), random: Random) -> #(List(String), Random) {
  case letters {
    [] -> #([], random)
    _ -> {
      let #(value, next_random) = next(random)
      let index = value % list.length(letters)
      let #(letter, remaining) = take_at(letters, index)
      let #(tail, after_tail) = shuffle(remaining, next_random)
      #([letter, ..tail], after_tail)
    }
  }
}

fn take_at(letters: List(String), index: Int) -> #(String, List(String)) {
  case letters {
    [] -> #("", [])
    [letter, ..rest] ->
      case index == 0 {
        True -> #(letter, rest)
        False -> {
          let #(chosen, remaining) = take_at(rest, index - 1)
          #(chosen, [letter, ..remaining])
        }
      }
  }
}

fn tiles_from_letters(letters: List(String), id: Int) -> List(Tile) {
  case letters {
    [] -> []
    [letter, ..rest] -> [Tile(id:, letter:), ..tiles_from_letters(rest, id + 1)]
  }
}

fn selected_letters(
  tiles: List(Tile),
  selected_ids: List(Int),
) -> List(String) {
  case selected_ids {
    [] -> []
    [id, ..rest] -> [letter_for_id(tiles, id), ..selected_letters(tiles, rest)]
  }
}

fn letter_for_id(tiles: List(Tile), id: Int) -> String {
  case tiles {
    [] -> ""
    [tile, ..rest] ->
      case tile.id == id {
        True -> tile.letter
        False -> letter_for_id(rest, id)
      }
  }
}

fn find_matching_tile(
  tiles: List(Tile),
  selected_ids: List(Int),
  key: String,
) -> Option(Int) {
  case tiles {
    [] -> None
    [tile, ..rest] ->
      case
        normalized_key(tile.letter) == key
        && !list.contains(selected_ids, tile.id)
      {
        True -> Some(tile.id)
        False -> find_matching_tile(rest, selected_ids, key)
      }
  }
}

fn tile_ids_for_letters(
  round: Round,
  letters: List(String),
  selected_ids: List(Int),
) -> Option(List(Int)) {
  case letters {
    [] -> Some(selected_ids)
    [letter, ..rest] ->
      case first_matching_unused_tile(round, selected_ids, letter) {
        None -> None
        Some(id) -> tile_ids_for_letters(round, rest, list.append(selected_ids, [id]))
      }
  }
}

fn normalized_key(key: String) -> String {
  key
  |> string.to_graphemes
  |> list.map(normalized_grapheme)
  |> string.concat
}

fn normalized_grapheme(key: String) -> String {
  case string.uppercase(key) {
    "À" | "Â" | "Ä" -> "A"
    "Ç" -> "C"
    "É" | "È" | "Ê" | "Ë" -> "E"
    "Î" | "Ï" -> "I"
    "Ô" | "Ö" -> "O"
    "Ù" | "Û" | "Ü" -> "U"
    other -> other
  }
}

fn word_at(words: List(String), index: Int) -> Option(String) {
  case words {
    [] -> None
    [word, ..rest] ->
      case index == 0 {
        True -> Some(word)
        False -> word_at(rest, index - 1)
      }
  }
}

fn next(random: Random) -> #(Int, Random) {
  let Random(seed) = random
  let candidate = seed * random_multiplier % random_modulus
  let value = case candidate == 0 {
    True -> 1
    False -> candidate
  }
  #(value, Random(value))
}

fn seed_from_key(key: String) -> Int {
  key
  |> string.to_utf_codepoints
  |> list.map(string.utf_codepoint_to_int)
  |> hash_codepoints(17)
}

fn hash_codepoints(codepoints: List(Int), acc: Int) -> Int {
  case codepoints {
    [] ->
      case acc == 0 {
        True -> 1
        False -> acc
      }
    [value, ..rest] -> {
      let product = acc * 31
      let combined = product + value
      hash_codepoints(rest, combined % random_modulus)
    }
  }
}

fn is_on_or_after(left: String, right: String) -> Bool {
  case string.compare(left, right) {
    Lt -> False
    _ -> True
  }
}

fn is_on_or_before(left: String, right: String) -> Bool {
  case string.compare(left, right) {
    Gt -> False
    _ -> True
  }
}
