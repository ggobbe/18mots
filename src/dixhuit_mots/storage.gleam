import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}

pub type StoredResult {
  StoredResult(date: String, score: Int, failed_target: Option(String))
}

pub type ActiveAttempt {
  ActiveAttempt(
    date: String,
    round_index: Int,
    seconds_left: Int,
    remaining_lives: Int,
    shuffle_count: Int,
  )
}

pub fn decode_results(serialized: String) -> Result(List(StoredResult), Nil) {
  case json.parse(serialized, results_decoder()) {
    Ok(results) -> Ok(results)
    Error(_) -> Error(Nil)
  }
}

pub fn decode_active_attempt(serialized: String) -> Result(ActiveAttempt, Nil) {
  case json.parse(serialized, active_attempt_decoder()) {
    Ok(attempt) -> Ok(attempt)
    Error(_) -> Error(Nil)
  }
}

fn results_decoder() -> decode.Decoder(List(StoredResult)) {
  use results <- decode.field("results", decode.list(stored_result_decoder()))
  decode.success(results)
}

fn active_attempt_decoder() -> decode.Decoder(ActiveAttempt) {
  use date <- decode.field("date", decode.string)
  use round_index <- decode.field("round_index", decode.int)
  use seconds_left <- decode.field("seconds_left", decode.int)
  use remaining_lives <- decode.optional_field("remaining_lives", 6, decode.int)
  use shuffle_count <- decode.optional_field("shuffle_count", 0, decode.int)
  decode.success(ActiveAttempt(
    date:,
    round_index:,
    seconds_left:,
    remaining_lives:,
    shuffle_count:,
  ))
}

pub fn encode_results(results: List(StoredResult)) -> String {
  json.object([
    #("schema_version", json.int(1)),
    #("results", json.array(results, encode_result)),
  ])
  |> json.to_string
}

pub fn encode_active_attempt(attempt: ActiveAttempt) -> String {
  json.object([
    #("date", json.string(attempt.date)),
    #("round_index", json.int(attempt.round_index)),
    #("seconds_left", json.int(attempt.seconds_left)),
    #("remaining_lives", json.int(attempt.remaining_lives)),
    #("shuffle_count", json.int(attempt.shuffle_count)),
  ])
  |> json.to_string
}

fn stored_result_decoder() -> decode.Decoder(StoredResult) {
  use date <- decode.field("date", decode.string)
  use score <- decode.field("score", decode.int)
  use failed_target <- decode.optional_field(
    "failed_target",
    None,
    decode.optional(decode.string),
  )
  decode.success(StoredResult(date:, score:, failed_target:))
}

fn encode_result(result: StoredResult) -> json.Json {
  json.object([
    #("date", json.string(result.date)),
    #("score", json.int(result.score)),
    #("failed_target", encode_optional_string(result.failed_target)),
  ])
}

fn encode_optional_string(value: Option(String)) -> json.Json {
  case value {
    None -> json.null()
    Some(string) -> json.string(string)
  }
}
