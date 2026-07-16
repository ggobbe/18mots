import dixhuit_mots/archive
import dixhuit_mots/browser
import dixhuit_mots/puzzle
import dixhuit_mots/storage.{
  type ActiveAttempt, type StoredResult, ActiveAttempt, StoredResult,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

const initial_seconds = 30

const normal_lives = 6

const easy_lives_per_word = 3

const correct_feedback_delay = 750

const incorrect_feedback_delay = 400

const github_url = "https://github.com/ggobbe/18mots"

type Screen {
  Loading
  Welcome
  Playing
  Results
  Archive
  LoadError
}

type AnswerFeedback {
  NoAnswerFeedback
  CorrectAnswer(Int)
  IncorrectAnswer(Int)
}

type Model {
  Model(
    screen: Screen,
    today: String,
    date: String,
    word_bank: Option(puzzle.WordBank),
    rounds: List(puzzle.Round),
    round_index: Int,
    selected_ids: List(Int),
    points: Int,
    easy_mode: Bool,
    easy_mode_preference: Bool,
    remaining_lives: Int,
    shuffle_count: Int,
    seconds_left: Int,
    timer_token: Int,
    results: List(StoredResult),
    active_attempt: Option(ActiveAttempt),
    last_result: Option(StoredResult),
    answer_feedback: AnswerFeedback,
    next_countdown: String,
    feedback: String,
    load_error: String,
  )
}

type Message {
  WordBankLoaded(Result(puzzle.WordBank, String))
  StorageLoaded(Result(List(StoredResult), Nil))
  ActiveAttemptLoaded(Result(ActiveAttempt, Nil))
  EasyModeLoaded(Bool)
  TryResumeActiveAttempt
  UserStartedToday
  UserChangedEasyMode(Bool)
  UserOpenedArchive
  UserOpenedWelcome
  UserSelectedArchiveDate(String)
  UserSelectedTile(Int)
  UserTypedAnswer(String)
  UserFocusedAnswerInput
  UserPressedRandomizeButton
  UserRandomizedTiles
  UserClearedSelection
  UserPressedKey(String)
  TimerTicked(Int)
  NextCountdownTicked(String)
  AnswerFeedbackEnded(Int)
  UserSharedResult(StoredResult)
  ShareFinished(Result(String, String))
  RetryLoading
}

pub fn main() {
  let today = browser.today_in_paris()
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", initial_model(today))

  Nil
}

fn initial_model(today: String) -> Model {
  Model(
    screen: Loading,
    today:,
    date: today,
    word_bank: None,
    rounds: [],
    round_index: 0,
    selected_ids: [],
    points: 0,
    easy_mode: False,
    easy_mode_preference: False,
    remaining_lives: normal_lives,
    shuffle_count: 0,
    seconds_left: initial_seconds,
    timer_token: 0,
    results: [],
    active_attempt: None,
    last_result: None,
    answer_feedback: NoAnswerFeedback,
    next_countdown: "--:--:--",
    feedback: "",
    load_error: "",
  )
}

fn init(model: Model) -> #(Model, Effect(Message)) {
  #(
    model,
    effect.batch([
      load_word_bank(),
      load_results(),
      load_active_attempt(),
      load_easy_mode(),
      listen_for_keys(),
      listen_for_next_countdown(),
    ]),
  )
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    WordBankLoaded(Ok(bank)) -> #(
      Model(..model, screen: Welcome, word_bank: Some(bank)),
      resume_active_attempt(),
    )

    WordBankLoaded(Error(reason)) -> #(
      Model(
        ..model,
        screen: LoadError,
        load_error: "Impossible de charger les mots : " <> reason,
      ),
      effect.none(),
    )

    StorageLoaded(Ok(results)) -> #(Model(..model, results:), effect.none())
    StorageLoaded(Error(_)) -> #(model, effect.none())
    ActiveAttemptLoaded(Ok(attempt)) -> #(
      Model(..model, active_attempt: Some(attempt)),
      resume_active_attempt(),
    )
    ActiveAttemptLoaded(Error(_)) -> #(model, effect.none())
    EasyModeLoaded(easy_mode) -> #(Model(..model, easy_mode_preference: easy_mode), effect.none())
    TryResumeActiveAttempt -> try_resume_active_attempt(model)
    UserStartedToday -> start_game(model, model.today)
    UserChangedEasyMode(easy_mode) -> #(
      Model(..model, easy_mode_preference: easy_mode),
      save_easy_mode(easy_mode),
    )
    UserOpenedArchive -> #(
      Model(..model, screen: Archive, feedback: ""),
      effect.none(),
    )
    UserOpenedWelcome -> #(
      Model(..model, screen: Welcome, feedback: ""),
      effect.none(),
    )
    UserSelectedArchiveDate(date) -> start_game(model, date)
    UserSelectedTile(id) -> select_tile(model, id)
    UserTypedAnswer(answer) -> type_answer(model, answer)
    UserFocusedAnswerInput -> #(model, scroll_tiles_into_view())
    UserPressedRandomizeButton -> #(model, effect.none())
    UserRandomizedTiles -> randomize_tiles(model)
    UserClearedSelection -> clear_selection(model)
    UserPressedKey(key) -> handle_key(model, key)
    TimerTicked(token) -> handle_tick(model, token)
    NextCountdownTicked(countdown) -> #(
      Model(..model, next_countdown: countdown),
      effect.none(),
    )
    AnswerFeedbackEnded(token) -> finish_answer_feedback(model, token)
    UserSharedResult(result) -> #(
      Model(..model, feedback: ""),
      share_result(result),
    )
    ShareFinished(Ok(feedback)) -> #(Model(..model, feedback:), effect.none())
    ShareFinished(Error(_)) -> #(
      Model(..model, feedback: "Impossible de partager le résultat."),
      effect.none(),
    )
    RetryLoading -> #(
      Model(..model, screen: Loading, load_error: ""),
      load_word_bank(),
    )
  }
}

fn try_resume_active_attempt(model: Model) -> #(Model, Effect(Message)) {
  case model.screen, model.word_bank, model.active_attempt {
    Welcome, Some(_), Some(attempt) -> start_game(model, attempt.date)
    _, _, _ -> #(model, effect.none())
  }
}

fn start_game(model: Model, date: String) -> #(Model, Effect(Message)) {
  case puzzle.is_available_date(date, model.today) {
    False -> #(
      Model(
        ..model,
        feedback: "Choisissez une date entre le "
          <> puzzle.release_date
          <> " et aujourd'hui.",
      ),
      effect.none(),
    )
    True ->
      case find_result(model.results, date) {
        Some(result) -> #(
          Model(
            ..model,
            screen: Results,
            date:,
            last_result: Some(result),
            feedback: "",
          ),
          effect.none(),
        )
        None ->
          case model.word_bank {
            None -> #(Model(..model, screen: Loading), load_word_bank())
            Some(bank) ->
              case puzzle.generate(bank, date, model.today) {
                Error(reason) -> #(
                  Model(..model, screen: LoadError, load_error: reason),
                  effect.none(),
                )
                Ok(rounds) -> {
                  let token = model.timer_token + 1
                  let attempt = resume_attempt(model, date)
                  let next =
                    Model(
                      ..model,
                      screen: Playing,
                      date: date,
                      rounds:,
                      round_index: attempt.round_index,
                      selected_ids: [],
                      points: attempt.points,
                      easy_mode: attempt.easy_mode,
                      remaining_lives: attempt.remaining_lives,
                      shuffle_count: attempt.shuffle_count,
                      seconds_left: attempt.seconds_left,
                      timer_token: token,
                      last_result: None,
                      answer_feedback: NoAnswerFeedback,
                      feedback: "",
                    )
                  #(
                    next,
                    effect.batch([
                      schedule_tick(token),
                      save_active_attempt(next),
                    ]),
                  )
                }
              }
          }
      }
  }
}

fn resume_attempt(model: Model, date: String) -> ActiveAttempt {
  case model.active_attempt {
    Some(attempt) if attempt.date == date ->
      ActiveAttempt(
        ..attempt,
        seconds_left: int.max(0, attempt.seconds_left - 1),
      )
    _ ->
      ActiveAttempt(
        date:,
        round_index: 0,
        seconds_left: initial_seconds,
        points: 0,
        remaining_lives: lives_for_round(model.easy_mode_preference),
        shuffle_count: 0,
        easy_mode: model.easy_mode_preference,
      )
  }
}

fn select_tile(model: Model, id: Int) -> #(Model, Effect(Message)) {
  case model.screen, model.answer_feedback, current_round(model) {
    Playing, NoAnswerFeedback, Some(round) ->
      case list.contains(model.selected_ids, id) {
        True ->
          case last_selected_id(model.selected_ids) == Some(id) {
            True -> #(
              Model(
                ..model,
                selected_ids: remove_last(model.selected_ids),
                feedback: "",
              ),
              effect.none(),
            )
            False -> #(
              Model(..model, selected_ids: [], feedback: ""),
              effect.none(),
            )
          }
        False -> {
          let selected_ids = list.append(model.selected_ids, [id])
          let selected = Model(..model, selected_ids:, feedback: "")

          case list.length(selected_ids) == puzzle.tile_count(round) {
            True -> submit_answer(selected, round)
            False -> #(selected, effect.none())
          }
        }
      }
    _, _, _ -> #(model, effect.none())
  }
}

fn last_selected_id(ids: List(Int)) -> Option(Int) {
  case list.reverse(ids) {
    [] -> None
    [id, ..] -> Some(id)
  }
}

fn clear_selection(model: Model) -> #(Model, Effect(Message)) {
  case model.screen, model.answer_feedback {
    Playing, NoAnswerFeedback -> #(
      Model(..model, selected_ids: [], feedback: ""),
      effect.none(),
    )
    _, _ -> #(model, effect.none())
  }
}

fn randomize_tiles(model: Model) -> #(Model, Effect(Message)) {
  case model.screen, model.answer_feedback, model.remaining_lives {
    Playing, NoAnswerFeedback, lives if lives > 0 -> {
      let next =
        Model(
          ..model,
          selected_ids: [],
          remaining_lives: lives - 1,
          shuffle_count: model.shuffle_count + 1,
          feedback: "",
        )
      #(next, save_active_attempt(next))
    }
    _, _, _ -> #(model, effect.none())
  }
}

fn type_answer(model: Model, answer: String) -> #(Model, Effect(Message)) {
  case model.screen, model.answer_feedback, current_round(model) {
    Playing, NoAnswerFeedback, Some(round) ->
      case puzzle.tile_ids_for_answer(round, answer) {
        None -> #(model, effect.none())
        Some(selected_ids) -> {
          let selected = Model(..model, selected_ids:, feedback: "")
          case list.length(selected_ids) == puzzle.tile_count(round) {
            True -> submit_answer(selected, round)
            False -> #(selected, effect.none())
          }
        }
      }
    _, _, _ -> #(model, effect.none())
  }
}

fn handle_key(model: Model, key: String) -> #(Model, Effect(Message)) {
  case model.screen, model.answer_feedback {
    Playing, NoAnswerFeedback ->
      case key {
        "Space" -> randomize_tiles(model)
        "Backspace" -> #(
          Model(
            ..model,
            selected_ids: remove_last(model.selected_ids),
            feedback: "",
          ),
          effect.none(),
        )
        _ ->
          case current_round(model) {
            None -> #(model, effect.none())
            Some(round) ->
              case
                puzzle.first_matching_unused_tile(
                  round,
                  model.selected_ids,
                  key,
                )
              {
                None -> #(model, effect.none())
                Some(id) -> select_tile(model, id)
              }
          }
      }
    _, _ -> #(model, effect.none())
  }
}

fn submit_answer(
  model: Model,
  round: puzzle.Round,
) -> #(Model, Effect(Message)) {
  case puzzle.is_correct_answer(round, model.selected_ids) {
    False -> show_answer_feedback(model, IncorrectAnswer)
    True ->
      show_answer_feedback(
        Model(
          ..model,
          points: model.points + puzzle.points_for_answer(model.easy_mode, model.seconds_left),
        ),
        CorrectAnswer,
      )
  }
}

fn show_answer_feedback(
  model: Model,
  feedback: fn(Int) -> AnswerFeedback,
) -> #(Model, Effect(Message)) {
  let token = model.timer_token + 1
  let answer_feedback = feedback(token)
  let delay = case answer_feedback {
    CorrectAnswer(_) -> correct_feedback_delay
    IncorrectAnswer(_) -> incorrect_feedback_delay
    NoAnswerFeedback -> 0
  }

  #(
    Model(..model, timer_token: token, answer_feedback:),
    schedule_answer_feedback_end(token, delay),
  )
}

fn finish_answer_feedback(
  model: Model,
  token: Int,
) -> #(Model, Effect(Message)) {
  case model.screen, model.answer_feedback {
    Playing, CorrectAnswer(active_token) if token == active_token ->
      case model.round_index + 1 == list.length(model.rounds) {
        True ->
          finish_game(
            Model(..model, answer_feedback: NoAnswerFeedback),
            18,
            model.points,
            None,
          )
        False -> {
          let next_token = model.timer_token + 1
          let next =
            Model(
              ..model,
              round_index: model.round_index + 1,
              selected_ids: [],
              shuffle_count: 0,
              remaining_lives: next_round_lives(model),
              seconds_left: initial_seconds,
              timer_token: next_token,
              answer_feedback: NoAnswerFeedback,
              feedback: "Bien joué.",
            )
          #(
            next,
            effect.batch([schedule_tick(next_token), save_active_attempt(next)]),
          )
        }
      }
    Playing, IncorrectAnswer(active_token) if token == active_token -> #(
        Model(
          ..model,
          selected_ids: [],
          answer_feedback: NoAnswerFeedback,
          feedback: "",
        ),
      schedule_tick(model.timer_token),
    )
    _, _ -> #(model, effect.none())
  }
}

fn handle_tick(model: Model, token: Int) -> #(Model, Effect(Message)) {
  case model.screen == Playing && token == model.timer_token {
    False -> #(model, effect.none())
    True ->
      case model.seconds_left <= 1 {
        True -> finish_game(model, model.round_index, model.points, failed_target(model))
        False -> {
          let seconds_left = model.seconds_left - 1
          let feedback = case model.easy_mode && seconds_left <= 16 {
            True -> ""
            False -> model.feedback
          }
          let next = Model(..model, seconds_left:, feedback:)
          #(
            next,
            effect.batch([
              schedule_tick(token),
              save_active_attempt(next),
            ]),
          )
        }
      }
  }
}

fn lives_for_round(easy_mode: Bool) -> Int {
  case easy_mode {
    True -> easy_lives_per_word
    False -> normal_lives
  }
}

fn next_round_lives(model: Model) -> Int {
  case model.easy_mode {
    True -> easy_lives_per_word
    False -> model.remaining_lives
  }
}

fn finish_game(
  model: Model,
  score: Int,
  points: Int,
  failed_target: Option(String),
) -> #(Model, Effect(Message)) {
  let result = StoredResult(date: model.date, score:, points:, failed_target:, easy_mode: model.easy_mode)
  let results = upsert_result(model.results, result)
  let next =
    Model(
      ..model,
      screen: Results,
      selected_ids: [],
      timer_token: model.timer_token + 1,
      results:,
      last_result: Some(result),
      answer_feedback: NoAnswerFeedback,
      feedback: "",
    )

  #(next, effect.batch([save_results(results), clear_active_attempt()]))
}

fn failed_target(model: Model) -> Option(String) {
  case current_round(model) {
    Some(round) -> Some(round.target)
    None -> None
  }
}

fn current_round(model: Model) -> Option(puzzle.Round) {
  case puzzle.round_at(model.rounds, model.round_index) {
    None -> None
    Some(round) -> Some(puzzle.shuffled_round(round, model.date, model.shuffle_count))
  }
}

fn find_result(
  results: List(StoredResult),
  date: String,
) -> Option(StoredResult) {
  case results {
    [] -> None
    [result, ..rest] ->
      case result.date == date {
        True -> Some(result)
        False -> find_result(rest, date)
      }
  }
}

fn upsert_result(
  results: List(StoredResult),
  replacement: StoredResult,
) -> List(StoredResult) {
  case results {
    [] -> [replacement]
    [result, ..rest] ->
      case result.date == replacement.date {
        True -> [replacement, ..rest]
        False -> [result, ..upsert_result(rest, replacement)]
      }
  }
}

fn remove_last(ids: List(Int)) -> List(Int) {
  case list.reverse(ids) {
    [] -> []
    [_, ..rest] -> list.reverse(rest)
  }
}

fn view(model: Model) -> Element(Message) {
  html.main(
    [
      attribute.class("app-shell"),
      attribute.aria_label("18 Mots"),
    ],
    [
      html.header([attribute.class("app-header")], [
        html.button(
          [
            attribute.class("wordmark"),
            attribute.type_("button"),
            event.on_click(UserOpenedWelcome),
          ],
          [html.text("18 Mots")],
        ),
        html.p([attribute.class("header-date")], [html.text(header_date(model))]),
      ]),
      view_screen(model),
    ],
  )
}

fn header_date(model: Model) -> String {
  case model.screen {
    Playing | Results -> model.date
    _ -> model.today
  }
}

fn view_screen(model: Model) -> Element(Message) {
  case model.screen {
    Loading -> view_loading()
    Welcome -> view_welcome(model)
    Playing -> view_game(model)
    Results -> view_results(model)
    Archive -> view_archive(model)
    LoadError -> view_load_error(model)
  }
}

fn view_loading() -> Element(Message) {
  html.section([attribute.class("centered-screen")], [
    html.div([attribute.class("loading-mark")], [html.text("18")]),
    html.p([attribute.class("muted")], [html.text("Préparation des mots…")]),
  ])
}

fn view_welcome(model: Model) -> Element(Message) {
  let played_today = find_result(model.results, model.today)

  html.section([attribute.class("welcome-screen")], [
    html.div([attribute.class("welcome-number")], [html.text("18")]),
    case played_today {
      None ->
        html.div([attribute.class("welcome-unplayed")], [
          html.p([attribute.class("eyebrow")], [html.text("Défi quotidien")]),
          html.h1([], [html.text("Remettez les lettres dans l'ordre.")]),
          html.p([attribute.class("welcome-copy")], [
            html.text("Dix-huit mots à retrouver."),
            html.br([]),
            html.text("Trente secondes par mot."),
          ]),
          html.button(
            [
              attribute.class("primary-action"),
              attribute.type_("button"),
              event.on_click(UserStartedToday),
            ],
            [html.text("Jouer aujourd'hui")],
          ),
          view_easy_mode_control(model.easy_mode_preference),
        ])
      Some(result) ->
        html.div([attribute.class("played-today")], [
          html.p([attribute.class("played-today-label")], [
            html.text("Défi du jour terminé"),
          ]),
          html.p([attribute.class("played-today-copy")], [
            html.text(
              "Vous avez survécu à "
              <> int.to_string(result.score)
              <> " mots sur 18 pour "
              <> int.to_string(result.points)
              <> " points.",
            ),
          ]),
          view_home_failed_target(result),
          html.p([attribute.class("played-today-next")], [
            html.text("Le prochain défi dans " <> model.next_countdown),
          ]),
          view_completed_actions(result),
          html.p([attribute.class("feedback"), attribute.aria_live("polite")], [
            html.text(model.feedback),
          ]),
        ])
    },
    view_stats(model.results),
    html.div([attribute.class("home-links")], [
      html.a(
        [
          attribute.class("home-link"),
          attribute.href("https://18words.com/"),
          attribute.hreflang("en"),
        ],
        [html.text("Version originale")],
      ),
      html.a(
        [attribute.class("home-link"), attribute.href(github_url)],
        [html.text("GitHub")],
      ),
    ]),
  ])
}

fn view_home_failed_target(result: StoredResult) -> Element(Message) {
  case result.failed_target {
    None -> html.text("")
    Some(target) ->
      html.p([attribute.class("played-today-target")], [
        html.text("Mot manqué : "),
        html.span([], [html.text(string.uppercase(target))]),
      ])
  }
}

fn view_game(model: Model) -> Element(Message) {
  case current_round(model) {
    None ->
      view_load_error(Model(..model, load_error: "Le défi est incomplet."))
    Some(round) ->
      html.section([attribute.class("game-screen")], [
        html.div([attribute.class("game-meta")], [
          html.p([attribute.class("round-count")], [
            html.text("Mot " <> int.to_string(round.number) <> " / 18"),
          ]),
          html.p(
            [
              attribute.classes([
                #("timer", True),
                #("timer--urgent", model.seconds_left <= 8),
              ]),
            ],
            [html.text(int.to_string(model.seconds_left) <> " s")],
          ),
        ]),
        view_answer_input(round, model.selected_ids, model.answer_feedback),
        view_easy_hints(model, round),
        view_tile_grid(
          round,
          model.selected_ids,
          model.answer_feedback,
          model.shuffle_count,
        ),
        view_randomize_control(model),
      ])
  }
}

fn view_answer_input(
  round: puzzle.Round,
  selected_ids: List(Int),
  feedback: AnswerFeedback,
) -> Element(Message) {
  html.input(
    [
      attribute.class("answer-input"),
      attribute.classes([
        #("answer-input--correct", is_correct_feedback(feedback)),
        #("answer-input--incorrect", is_incorrect_feedback(feedback)),
      ]),
      attribute.type_("text"),
      attribute.value(displayed_answer(round, selected_ids, feedback)),
      attribute.maxlength(puzzle.tile_count(round)),
      attribute.inputmode("text"),
      attribute.autocapitalize("characters"),
      attribute.autocorrect(False),
      attribute.autocomplete("off"),
      attribute.spellcheck(False),
      attribute.aria_label("Votre réponse"),
      event.on_input(UserTypedAnswer),
      event.on_focus(UserFocusedAnswerInput),
    ],
  )
}

fn view_easy_hints(model: Model, round: puzzle.Round) -> Element(Message) {
  html.p([attribute.class("feedback easy-hint"), attribute.aria_live("polite")], [
    html.text(case model.feedback {
      "" -> case model.easy_mode {
        True -> easy_hint(round.target, model.seconds_left)
        False -> ""
      }
      feedback -> feedback
    }),
  ])
}

fn easy_hint(target: String, seconds_left: Int) -> String {
  let letters = string.to_graphemes(target)
  case seconds_left <= 9 {
    True -> "Indice : " <> first_letter(letters) <> "…" <> last_letter(letters)
    False ->
      case seconds_left <= 18 {
        True -> "Indice : " <> first_letter(letters) <> "…"
        False -> ""
      }
  }
}

fn first_letter(letters: List(String)) -> String {
  case letters {
    [letter, ..] -> string.uppercase(letter)
    [] -> ""
  }
}

fn last_letter(letters: List(String)) -> String {
  case list.reverse(letters) {
    [letter, ..] -> string.uppercase(letter)
    [] -> ""
  }
}

fn view_easy_mode_control(easy_mode: Bool) -> Element(Message) {
  html.div([attribute.class("easy-mode")], [
    html.label([attribute.class("easy-mode-control")], [
      html.input([
        attribute.type_("checkbox"),
        attribute.checked(easy_mode),
        event.on_check(UserChangedEasyMode),
      ]),
      html.text(" Mode facile"),
    ]),
    html.p([attribute.class("easy-mode-copy")], [
      html.text("Trois mélanges par mot et des indices à 18 puis 9 secondes."),
    ]),
  ])
}

fn view_randomize_control(model: Model) -> Element(Message) {
  html.div([attribute.class("randomize-control")], [
    html.div([attribute.class("randomize-button")], [
      html.button(
        [
          attribute.class("secondary-action"),
          attribute.type_("button"),
          attribute.disabled(
            model.remaining_lives == 0 || model.answer_feedback != NoAnswerFeedback,
          ),
          event.prevent_default(event.on_mouse_down(UserPressedRandomizeButton)),
          event.on_click(UserRandomizedTiles),
        ],
        [html.text("Mélanger")],
      ),
      html.p([attribute.class("randomize-shortcut")], [html.text("Touche Espace")]),
    ]),
    html.span([attribute.class("randomize-lives")], [
      html.text(
        int.to_string(model.remaining_lives)
        <> case model.easy_mode {
          True -> " restants pour ce mot"
          False -> " restants aujourd'hui"
        },
      ),
    ]),
  ])
}

fn displayed_answer(
  round: puzzle.Round,
  selected_ids: List(Int),
  feedback: AnswerFeedback,
) -> String {
  case feedback {
    CorrectAnswer(_) -> round.target
    _ -> puzzle.selected_answer(round, selected_ids)
  }
}

fn is_correct_feedback(feedback: AnswerFeedback) -> Bool {
  case feedback {
    CorrectAnswer(_) -> True
    _ -> False
  }
}

fn is_incorrect_feedback(feedback: AnswerFeedback) -> Bool {
  case feedback {
    IncorrectAnswer(_) -> True
    _ -> False
  }
}

fn view_tile_grid(
  round: puzzle.Round,
  selected_ids: List(Int),
  feedback: AnswerFeedback,
  shuffle_count: Int,
) -> Element(Message) {
  html.div(
    [
      attribute.class("tile-grid"),
      attribute.classes([
        #("tile-grid--correct", is_correct_feedback(feedback)),
        #("tile-grid--incorrect", is_incorrect_feedback(feedback)),
        #("tile-grid--shuffled-a", shuffle_count % 2 == 1),
        #("tile-grid--shuffled-b", shuffle_count > 0 && shuffle_count % 2 == 0),
      ]),
      attribute.style("--columns", int.to_string(puzzle.tile_count(round))),
      attribute.role("group"),
      attribute.aria_label("Lettres disponibles"),
    ],
    list.map(round.tiles, fn(tile) {
      let selected = list.contains(selected_ids, tile.id)
      html.button(
        [
          attribute.class("letter-tile"),
          attribute.style("--tile-index", int.to_string(tile.id)),
          attribute.classes([#("letter-tile--selected", selected)]),
          attribute.type_("button"),
          attribute.tabindex(-1),
          attribute.aria_pressed(case selected {
            True -> "true"
            False -> "false"
          }),
          attribute.aria_label("Lettre " <> string.uppercase(tile.letter)),
          event.on_click(UserSelectedTile(tile.id)),
        ],
        [html.text(string.uppercase(tile.letter))],
      )
    }),
  )
}

fn view_results(model: Model) -> Element(Message) {
  case model.last_result {
    None -> view_welcome(Model(..model, screen: Welcome))
    Some(result) ->
      html.section([attribute.class("result-screen")], [
        html.p([attribute.class("eyebrow")], [html.text(result.date)]),
        html.div([attribute.class("result-score")], [
          html.strong([], [html.text(int.to_string(result.score))]),
          html.span([], [html.text(" mots · " <> int.to_string(result.points) <> " pts")]),
        ]),
        html.h1([], [html.text(result_heading(result))]),
        html.p([attribute.class("result-copy")], [
          html.text(result_copy(result)),
        ]),
        view_easy_mode_label(result.easy_mode),
        view_failed_target(result),
        view_completed_actions(result),
        html.p([attribute.class("feedback"), attribute.aria_live("polite")], [
          html.text(model.feedback),
        ]),
        view_stats(model.results),
      ])
  }
}

fn view_completed_actions(result: StoredResult) -> Element(Message) {
  html.div([attribute.class("result-actions")], [
    html.button(
      [
        attribute.class("primary-action"),
        attribute.type_("button"),
        event.on_click(UserSharedResult(result)),
      ],
      [html.text("Partager")],
    ),
    html.button(
      [
        attribute.class("secondary-action"),
        attribute.type_("button"),
        event.on_click(UserOpenedArchive),
      ],
      [html.text("Jouer aux archives")],
    ),
  ])
}

fn view_failed_target(result: StoredResult) -> Element(Message) {
  case result.failed_target {
    None -> html.text("")
    Some(target) ->
      html.p([attribute.class("result-target")], [
        html.text("Le mot était : "),
        html.span([attribute.class("result-target-word")], [
          html.text(string.uppercase(target)),
        ]),
      ])
  }
}

fn view_archive(model: Model) -> Element(Message) {
  html.section([attribute.class("archive-screen")], [
    html.p([attribute.class("eyebrow")], [html.text("Archives")]),
    html.h1([], [html.text("Rejouer un défi passé")]),
    html.p([attribute.class("archive-copy")], [
      html.text("Les 30 derniers défis disponibles, avec vos scores locaux."),
    ]),
    view_easy_mode_control(model.easy_mode_preference),
    html.div([attribute.class("archive-list")], archive_rows(model)),
    html.p([attribute.class("feedback"), attribute.aria_live("polite")], [
      html.text(model.feedback),
    ]),
    html.button(
      [
        attribute.class("text-action"),
        attribute.type_("button"),
        event.on_click(UserOpenedWelcome),
      ],
      [html.text("Retour")],
    ),
  ])
}

fn archive_rows(model: Model) -> List(Element(Message)) {
  let recent_dates = archive.dates(model.today, 30)
  let played_dates = older_played_dates(model.results, recent_dates)

  list.append(recent_dates, played_dates)
  |> list.map(fn(date) { archive_row(date, find_result(model.results, date)) })
}

fn older_played_dates(
  results: List(StoredResult),
  recent_dates: List(String),
) -> List(String) {
  results
  |> list.filter(fn(result) { !list.contains(recent_dates, result.date) })
  |> list.map(fn(result) { result.date })
  |> list.sort(order.reverse(string.compare))
}

fn archive_row(date: String, result: Option(StoredResult)) -> Element(Message) {
  let played = option.is_some(result)

  html.button(
    [
      attribute.classes([
        #("archive-row", True),
        #("archive-row--played", played),
      ]),
      attribute.type_("button"),
      attribute.disabled(played),
      event.on_click(UserSelectedArchiveDate(date)),
    ],
    [
      html.span([attribute.class("archive-row-date")], [html.text(date)]),
      html.span(
        [
          attribute.classes([
            #("archive-row-score", True),
            #("archive-row-score--played", played),
          ]),
        ],
        [html.text(archive_row_label(result))],
      ),
    ],
  )
}

fn archive_row_label(result: Option(StoredResult)) -> String {
  case result {
    Some(result) ->
      int.to_string(result.score)
      <> "/18 · "
      <> int.to_string(result.points)
      <> " pts"
      <> case result.easy_mode {
        True -> " · facile"
        False -> ""
      }
    None -> "À jouer"
  }
}

fn view_easy_mode_label(easy_mode: Bool) -> Element(Message) {
  case easy_mode {
    True -> html.p([attribute.class("easy-mode-label")], [html.text("Mode facile")])
    False -> html.text("")
  }
}

fn view_load_error(model: Model) -> Element(Message) {
  html.section([attribute.class("centered-screen")], [
    html.p([attribute.class("eyebrow")], [html.text("Chargement")]),
    html.h1([], [html.text("Les mots ne sont pas disponibles.")]),
    html.p([attribute.class("muted")], [html.text(model.load_error)]),
    html.button(
      [
        attribute.class("primary-action"),
        attribute.type_("button"),
        event.on_click(RetryLoading),
      ],
      [html.text("Réessayer")],
    ),
  ])
}

fn view_stats(results: List(StoredResult)) -> Element(Message) {
  let total = list.length(results)
  let solved = list.fold(results, 0, fn(total, result) { total + result.score })
  let points = list.fold(results, 0, fn(total, result) { total + result.points })

  html.div([attribute.class("stats-line")], [
    html.span([], [html.text(int.to_string(total) <> " défi(s) joué(s)")]),
    html.span([], [html.text(int.to_string(solved) <> " mots trouvés")]),
    html.span([], [html.text(points_label(points))]),
  ])
}

fn points_label(points: Int) -> String {
  case points == 1 {
    True -> "1 point"
    False -> int.to_string(points) <> " points"
  }
}

fn result_heading(result: StoredResult) -> String {
  case result.score == 18 {
    True -> "Défi terminé."
    False -> "Temps écoulé."
  }
}

fn result_copy(result: StoredResult) -> String {
  case result.score == 18 {
    True -> "Vous avez survécu aux dix-huit mots."
    False ->
      "Vous avez résolu "
      <> int.to_string(result.score)
      <> " mot(s) avant la fin du temps."
  }
}

fn share_result(result: StoredResult) -> Effect(Message) {
  use dispatch <- effect.from
  let text =
    "J’ai trouvé "
    <> int.to_string(result.score)
    <> " mots sur 18"
    <> " pour "
    <> int.to_string(result.points)
    <> " points"
    <> case result.easy_mode {
      True -> " en mode facile"
      False -> ""
    }
    <> ". Joue à 18 Mots !"

  browser.share(text, "https://18mots.com/", fn(result) {
    dispatch(ShareFinished(result))
  })
}

fn load_word_bank() -> Effect(Message) {
  use dispatch <- effect.from
  browser.load_word_bank(fn(result) {
    dispatch(
      WordBankLoaded(case result {
        Ok(contents) -> puzzle.parse_word_bank(contents)
        Error(reason) -> Error(reason)
      }),
    )
  })
}

fn load_results() -> Effect(Message) {
  use dispatch <- effect.from
  browser.load_results(fn(result) {
    dispatch(
      StorageLoaded(case result {
        Ok(serialized) -> storage.decode_results(serialized)
        Error(_) -> Error(Nil)
      }),
    )
  })
}

fn load_active_attempt() -> Effect(Message) {
  use dispatch <- effect.from
  browser.load_active_attempt(fn(result) {
    dispatch(
      ActiveAttemptLoaded(case result {
        Ok(serialized) -> storage.decode_active_attempt(serialized)
        Error(_) -> Error(Nil)
      }),
    )
  })
}

fn save_results(results: List(StoredResult)) -> Effect(message) {
  use _ <- effect.from
  browser.save_results(storage.encode_results(results))
}

fn save_active_attempt(model: Model) -> Effect(message) {
  use _ <- effect.from

  case model.screen == Playing {
    True ->
      browser.save_active_attempt(
        storage.encode_active_attempt(ActiveAttempt(
          date: model.date,
          round_index: model.round_index,
          seconds_left: model.seconds_left,
          points: model.points,
          remaining_lives: model.remaining_lives,
          shuffle_count: model.shuffle_count,
          easy_mode: model.easy_mode,
        )),
      )
    False -> Nil
  }
}

fn clear_active_attempt() -> Effect(message) {
  use _ <- effect.from
  browser.clear_active_attempt()
}

fn resume_active_attempt() -> Effect(Message) {
  use dispatch <- effect.from
  dispatch(TryResumeActiveAttempt)
}

fn load_easy_mode() -> Effect(Message) {
  use dispatch <- effect.from
  browser.load_easy_mode(fn(easy_mode) { dispatch(EasyModeLoaded(easy_mode)) })
}

fn save_easy_mode(easy_mode: Bool) -> Effect(message) {
  use _ <- effect.from
  browser.save_easy_mode(easy_mode)
}

fn schedule_tick(token: Int) -> Effect(Message) {
  use dispatch <- effect.from
  browser.set_timeout(1000, fn() { dispatch(TimerTicked(token)) })
}

fn scroll_tiles_into_view() -> Effect(message) {
  use _ <- effect.from
  browser.scroll_tiles_into_view()
}

fn schedule_answer_feedback_end(token: Int, delay: Int) -> Effect(Message) {
  use dispatch <- effect.from
  browser.set_timeout(delay, fn() { dispatch(AnswerFeedbackEnded(token)) })
}

fn listen_for_keys() -> Effect(Message) {
  use dispatch <- effect.from
  browser.listen_for_keys(fn(key) { dispatch(UserPressedKey(key)) })
}

fn listen_for_next_countdown() -> Effect(Message) {
  use dispatch <- effect.from
  browser.listen_for_next_countdown(fn(countdown) {
    dispatch(NextCountdownTicked(countdown))
  })
}
