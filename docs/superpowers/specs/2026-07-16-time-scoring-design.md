# Time-Based Scoring

## Goal

Reward faster solutions while making Easy Mode scores visibly lower when hints are available.

## Design

Each result stores both words found and total points. Normal-mode solutions earn their seconds remaining, from 1 to 30 points. Easy-mode solutions earn `floor(seconds * 2 / 3)` before the 18-second first hint, `floor(seconds / 2)` after it, and `floor(seconds / 3)` after the 9-second second hint. Every solved word earns at least one point.

Result screens display words found and points. Archive rows display both values. Grand stats show total words found and total points. Shared text includes points. Existing stored results receive points equal to their prior word score.

## Scope

- Track in-progress points and persist final points.
- Apply the scoring rule at correct-answer submission.
- Display points in results, archives, aggregate stats, and sharing.
- Add tests for Normal and Easy scoring thresholds plus old-result defaults.

## Verification

- Run `gleam test` and production build.
- Confirm score displays and archive labels match recorded word and point totals.
