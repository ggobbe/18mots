import { Error as GleamError, Ok } from "./gleam.mjs";

const resultsKey = "18mots:results:v1";
const activeAttemptKey = "18mots:active-attempt:v1";
const easyModeKey = "18mots:easy-mode:v1";
const emptyResults = JSON.stringify({ schema_version: 1, results: [] });
let keyListener = undefined;
let countdownInterval = undefined;

export function today_in_paris() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Paris",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const part = (type) => parts.find((item) => item.type === type)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

export function load_word_bank(callback) {
  fetch("word-bank-v6.txt")
    .then((response) => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return response.text();
    })
    .then((text) => callback(new Ok(text)))
    .catch((error) => callback(new GleamError(String(error?.message ?? error))));
}

export function load_results(callback) {
  try {
    callback(new Ok(window.localStorage.getItem(resultsKey) ?? emptyResults));
  } catch (error) {
    callback(new GleamError(String(error?.message ?? error)));
  }
}

export function load_active_attempt(callback) {
  try {
    const serialized = window.localStorage.getItem(activeAttemptKey);
    if (serialized === null) throw new Error("No active attempt");
    callback(new Ok(serialized));
  } catch (error) {
    callback(new GleamError(String(error?.message ?? error)));
  }
}

export function load_easy_mode(callback) {
  try {
    callback(window.localStorage.getItem(easyModeKey) === "true");
  } catch {
    callback(false);
  }
}

export function save_easy_mode(easyMode) {
  try {
    window.localStorage.setItem(easyModeKey, String(easyMode));
  } catch {
  }
}

export function save_results(serialized) {
  try {
    window.localStorage.setItem(resultsKey, serialized);
  } catch {
    // Local persistence is optional; a storage failure must not stop play.
  }
}

export function save_active_attempt(serialized) {
  try {
    window.localStorage.setItem(activeAttemptKey, serialized);
  } catch {
  }
}

export function clear_active_attempt() {
  try {
    window.localStorage.removeItem(activeAttemptKey);
  } catch {
  }
}

export async function share(text, url, callback) {
  try {
    if (navigator.share) {
      await navigator.share({ title: "18 Mots", text, url });
      callback(new Ok(""));
    } else {
      await navigator.clipboard.writeText(`${text}\n${url}`);
      callback(new Ok("Lien copié."));
    }
  } catch (error) {
    if (error?.name === "AbortError") callback(new Ok(""));
    else callback(new GleamError(String(error?.message ?? error)));
  }
}

export function set_timeout(delay, callback) {
  window.setTimeout(callback, delay);
}

export function scroll_tiles_into_view() {
  if (!window.matchMedia("(pointer: coarse)").matches) return;

  const grid = document.querySelector(".tile-grid");
  const viewport = window.visualViewport;
  if (!grid || !viewport) return;

  const reveal = () => {
    grid.scrollIntoView({ block: "center", behavior: "smooth" });
  };

  viewport.addEventListener("resize", reveal, { once: true });
  window.setTimeout(reveal, 350);
}

export function listen_for_keys(callback) {
  if (keyListener) return;

  keyListener = (event) => {
    if (event.target instanceof HTMLInputElement) return;
    callback(event.key);
  };
  window.addEventListener("keydown", keyListener);
}

export function listen_for_next_countdown(callback) {
  if (countdownInterval) return;

  const tick = () => callback(next_countdown());
  tick();
  countdownInterval = window.setInterval(tick, 1000);
}

function next_countdown() {
  const now = new Date();
  const today = paris_day(now);
  let low = now.getTime();
  let high = low + 26 * 60 * 60 * 1000;

  while (high - low > 1000) {
    const middle = Math.floor((low + high) / 2);
    if (paris_day(new Date(middle)) === today) low = middle;
    else high = middle;
  }

  const remaining = Math.max(0, Math.floor((high - now.getTime()) / 1000));
  const hours = Math.floor(remaining / 3600);
  const minutes = Math.floor((remaining % 3600) / 60);
  const seconds = remaining % 60;

  return [hours, minutes, seconds]
    .map((value) => String(value).padStart(2, "0"))
    .join(":");
}

function paris_day(date) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Paris",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const part = (type) => parts.find((item) => item.type === type)?.value ?? "";

  return `${part("year")}-${part("month")}-${part("day")}`;
}
