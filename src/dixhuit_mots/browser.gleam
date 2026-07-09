import dixhuit_mots/puzzle

@external(javascript, "../dixhuit_mots.ffi.mjs", "today_in_paris")
pub fn today_in_paris() -> String {
  puzzle.release_date
}

@external(javascript, "../dixhuit_mots.ffi.mjs", "load_word_bank")
pub fn load_word_bank(_callback: fn(Result(String, String)) -> Nil) -> Nil {
  Nil
}

@external(javascript, "../dixhuit_mots.ffi.mjs", "load_results")
pub fn load_results(_callback: fn(Result(String, String)) -> Nil) -> Nil {
  Nil
}

@external(javascript, "../dixhuit_mots.ffi.mjs", "load_active_attempt")
pub fn load_active_attempt(
  _callback: fn(Result(String, String)) -> Nil,
) -> Nil {
  Nil
}

@external(javascript, "../dixhuit_mots.ffi.mjs", "save_results")
pub fn save_results(_serialized: String) -> Nil {
  Nil
}

@external(javascript, "../dixhuit_mots.ffi.mjs", "save_active_attempt")
pub fn save_active_attempt(_serialized: String) -> Nil {
  Nil
}

@external(javascript, "../dixhuit_mots.ffi.mjs", "clear_active_attempt")
pub fn clear_active_attempt() -> Nil {
  Nil
}

@external(javascript, "../dixhuit_mots.ffi.mjs", "blur_active_element")
pub fn blur_active_element() -> Nil {
  Nil
}

@external(javascript, "../dixhuit_mots.ffi.mjs", "share")
pub fn share(
  _text: String,
  _url: String,
  _callback: fn(Result(String, String)) -> Nil,
) -> Nil {
  Nil
}

@external(javascript, "../dixhuit_mots.ffi.mjs", "set_timeout")
pub fn set_timeout(_delay: Int, _callback: fn() -> Nil) -> Nil {
  Nil
}

@external(javascript, "../dixhuit_mots.ffi.mjs", "listen_for_keys")
pub fn listen_for_keys(_callback: fn(String) -> Nil) -> Nil {
  Nil
}

@external(javascript, "../dixhuit_mots.ffi.mjs", "listen_for_next_countdown")
pub fn listen_for_next_countdown(_callback: fn(String) -> Nil) -> Nil {
  Nil
}
