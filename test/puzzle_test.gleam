import dixhuit_mots/puzzle
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleeunit/should

pub fn puzzle_test() {
  let assert Ok(bank) = puzzle.parse_word_bank(test_word_bank())
  let assert Ok(first) = puzzle.generate(bank, "2026-07-09", "2026-07-09")
  let assert Ok(second) = puzzle.generate(bank, "2026-07-09", "2026-07-09")

  should.equal(first, second)
  should.equal(18, list.length(first))
  should.equal(
    [4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 7, 7, 8, 9],
    round_lengths(first) |> list.sort(int.compare),
  )
  should.equal([4, 4], round_lengths(first) |> list.take(2))
  should.equal([7, 7, 8, 9], last_lengths(first, 4))
  should.equal(9, last_length(first))
}

pub fn available_date_test() {
  should.equal(True, puzzle.is_available_date("2026-07-01", "2026-07-09"))
  should.equal(False, puzzle.is_available_date("2026-06-30", "2026-07-09"))
  should.equal(False, puzzle.is_available_date("2026-07-10", "2026-07-09"))
}

pub fn generator_rejects_future_date_test() {
  let assert Ok(bank) = puzzle.parse_word_bank(test_word_bank())
  let result = puzzle.generate(bank, "2026-07-10", "2026-07-09")

  should.equal(True, case result {
    Error(_) -> True
    Ok(_) -> False
  })
}

pub fn keyboard_letters_match_accents_test() {
  let round =
    puzzle.Round(number: 1, target: "allées", tiles: [
      puzzle.Tile(id: 0, letter: "a"),
      puzzle.Tile(id: 1, letter: "l"),
      puzzle.Tile(id: 2, letter: "é"),
      puzzle.Tile(id: 3, letter: "e"),
      puzzle.Tile(id: 4, letter: "ç"),
    ])

  should.equal(Some(2), puzzle.first_matching_unused_tile(round, [], "e"))
  should.equal(Some(3), puzzle.first_matching_unused_tile(round, [2], "e"))
  should.equal(Some(4), puzzle.first_matching_unused_tile(round, [], "c"))
}

pub fn answers_ignore_accents_test() {
  let round =
    puzzle.Round(number: 1, target: "allées", tiles: [
      puzzle.Tile(id: 0, letter: "a"),
      puzzle.Tile(id: 1, letter: "l"),
      puzzle.Tile(id: 2, letter: "l"),
      puzzle.Tile(id: 3, letter: "e"),
      puzzle.Tile(id: 4, letter: "é"),
      puzzle.Tile(id: 5, letter: "s"),
    ])

  should.equal(True, puzzle.is_correct_answer(round, [0, 1, 2, 3, 4, 5]))
  should.equal(True, puzzle.is_correct_answer(round, [0, 1, 2, 4, 3, 5]))
}

fn round_lengths(rounds: List(puzzle.Round)) -> List(Int) {
  case rounds {
    [] -> []
    [round, ..rest] -> [puzzle.tile_count(round), ..round_lengths(rest)]
  }
}

fn last_length(rounds: List(puzzle.Round)) -> Int {
  case rounds {
    [] -> 0
    [round] -> puzzle.tile_count(round)
    [_, ..rest] -> last_length(rest)
  }
}

fn last_lengths(rounds: List(puzzle.Round), count: Int) -> List(Int) {
  rounds
  |> list.drop(list.length(rounds) - count)
  |> round_lengths
}

fn test_word_bank() -> String {
  "pour\nnous\nelle\ntout\nplus\nquoi\nêtre\nveux\npeux\navait\ncomme\ncette\nquand\nalors\nchose\naussi\njamais\naccord\nparler\ndepuis\ndésolé\nchoses\ncomment\nquelque\nbonjour\nvoulais\nregarde\nattends\nfamille\npourquoi\nvraiment\ntoujours\npersonne\nbeaucoup\nmonsieur\ncomprends\nseulement\nlongtemps\ntellement\nconfiance\ntéléphone\n"
}
