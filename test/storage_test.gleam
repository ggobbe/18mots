import dixhuit_mots/storage
import gleam/option.{None}
import gleeunit/should

pub fn old_results_remain_decodable_test() {
  let serialized =
    "{\"schema_version\":1,\"results\":[{\"date\":\"2026-07-09\",\"score\":18,\"status\":\"terminé\",\"failed_target\":null}]}"

  storage.decode_results(serialized)
  |> should.equal(
    Ok([
      storage.StoredResult(date: "2026-07-09", score: 18, failed_target: None),
    ]),
  )
}
