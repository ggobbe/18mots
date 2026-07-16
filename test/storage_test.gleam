import dixhuit_mots/storage
import gleam/option.{None}
import gleeunit/should

pub fn old_results_remain_decodable_test() {
  let serialized =
    "{\"schema_version\":1,\"results\":[{\"date\":\"2026-07-09\",\"score\":18,\"status\":\"terminé\",\"failed_target\":null}]}"

  storage.decode_results(serialized)
  |> should.equal(
    Ok([
      storage.StoredResult(
        date: "2026-07-09",
        score: 18,
        failed_target: None,
        easy_mode: False,
      ),
    ]),
  )
}

pub fn old_active_attempts_receive_shuffle_defaults_test() {
  storage.decode_active_attempt(
    "{\"date\":\"2026-07-09\",\"round_index\":2,\"seconds_left\":19}",
  )
  |> should.equal(
    Ok(storage.ActiveAttempt(
      date: "2026-07-09",
      round_index: 2,
      seconds_left: 19,
      remaining_lives: 6,
      shuffle_count: 0,
      easy_mode: False,
    )),
  )
}

pub fn old_attempts_and_results_default_to_normal_mode_test() {
  storage.decode_active_attempt(
    "{\"date\":\"2026-07-09\",\"round_index\":2,\"seconds_left\":19}",
  )
  |> should.equal(
    Ok(storage.ActiveAttempt(
      date: "2026-07-09",
      round_index: 2,
      seconds_left: 19,
      remaining_lives: 6,
      shuffle_count: 0,
      easy_mode: False,
    )),
  )
}

pub fn easy_mode_results_remain_decodable_test() {
  storage.decode_results(
    "{\"schema_version\":1,\"results\":[{\"date\":\"2026-07-09\",\"score\":18,\"failed_target\":null,\"easy_mode\":true}]}",
  )
  |> should.equal(
    Ok([
      storage.StoredResult(
        date: "2026-07-09",
        score: 18,
        failed_target: None,
        easy_mode: True,
      ),
    ]),
  )
}
