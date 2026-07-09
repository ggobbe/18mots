import dixhuit_mots/puzzle
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string

type DateParts {
  DateParts(year: Int, month: Int, day: Int)
}

pub fn dates(today: String, limit: Int) -> List(String) {
  case limit <= 0 || !puzzle.is_available_date(today, today) {
    True -> []
    False -> [today, ..previous_dates(today, limit - 1)]
  }
}

fn previous_dates(date: String, remaining: Int) -> List(String) {
  case remaining <= 0 {
    True -> []
    False ->
      case previous_date(date) {
        None -> []
        Some(previous) ->
          case puzzle.is_available_date(previous, date) {
            False -> []
            True -> [previous, ..previous_dates(previous, remaining - 1)]
          }
      }
  }
}

fn previous_date(date: String) -> Option(String) {
  case parse_date(date) {
    None -> None
    Some(DateParts(year, month, day)) ->
      case day > 1 {
        True -> Some(format_date(year, month, day - 1))
        False ->
          case month > 1 {
            True ->
              Some(format_date(year, month - 1, days_in_month(year, month - 1)))
            False -> Some(format_date(year - 1, 12, 31))
          }
      }
  }
}

fn parse_date(date: String) -> Option(DateParts) {
  case string.split(date, "-") {
    [year, month, day] ->
      case int.parse(year), int.parse(month), int.parse(day) {
        Ok(year), Ok(month), Ok(day) -> Some(DateParts(year:, month:, day:))
        _, _, _ -> None
      }
    _ -> None
  }
}

fn format_date(year: Int, month: Int, day: Int) -> String {
  int.to_string(year) <> "-" <> pad2(month) <> "-" <> pad2(day)
}

fn pad2(value: Int) -> String {
  case value < 10 {
    True -> "0" <> int.to_string(value)
    False -> int.to_string(value)
  }
}

fn days_in_month(year: Int, month: Int) -> Int {
  case month {
    2 ->
      case is_leap_year(year) {
        True -> 29
        False -> 28
      }
    4 | 6 | 9 | 11 -> 30
    _ -> 31
  }
}

fn is_leap_year(year: Int) -> Bool {
  year % 400 == 0 || year % 4 == 0 && year % 100 != 0
}
