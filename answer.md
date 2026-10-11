# Shiptivitas: DAU and status change analysis

Launch date used: 2018-06-28 (first real status change).

## Results

| Period | Days | Avg daily active users |
|---|---|---|
| Before launch (all) | 145 | 4.97 |
| After launch (all) | 219 | 11.73 |
| 28 days before | 28 | 12.04 |
| 28 days after | 28 | 12.57 |

Most DAU growth happened before launch; like-for-like it is roughly flat (+4%). Status changes: 286 total; cards by number of changes: 0:38, 1:53, 2:100, 3:4, 4:4, 5:1.

## Three ideas

### Idea 1: Stale-shipment daily digest

**Hypothesis:** Users have no reason to come back on a given day. 46 of the 58 cards currently In Progress (79%) have not been touched for 14+ days, and a card takes a median of ~19 days to get from In Progress to Complete. If we tell people each day which shipments are stuck, we give them a specific reason to log in, and DAU/MAU (today ~15%) will rise.

**Expected impact:** Planning estimate: if 1 in 5 of the ~75 monthly users logs in one extra day a week because of the digest, that is 75 x 0.2 / 7 = about +2 daily active users (+18% on the current ~11.7). It should also lift tasks completed, which supports the original 15% goal. To be validated with an A/B test (digest on vs off).

**What the feature is:** A short email/push each morning: 'You have 3 shipments In Progress for 7+ days', with each card linking straight to the board with that card highlighted. Users can set the threshold (7 / 14 days) or mute it.

### Idea 2: 'Today' focus list (daily planning habit)

**Hypothesis:** Usage is spread evenly across every weekday and every hour of the day (Sunday is the busiest day), so there is no routine that brings users back. Priority already exists (card order) but is never used as a daily plan. If users pick a short 'Today' list each morning, opening the app becomes a daily habit and DAU rises.

**Expected impact:** Planning estimate: if 10 monthly users adopt the habit and add 2 active days a week each, that is 10 x 2 / 7 = about +2.9 DAU (+24%). Secondary effect: more cards moved per session. Measure with a feature-flag rollout to 50% of users and compare DAU/MAU after 4 weeks.

**What the feature is:** A fourth panel at the top of the board called 'Today' where users drag up to 5 cards to work on. Unfinished cards carry over to tomorrow, and a small streak counter ('4 days in a row') shows consistent use.

### Idea 3: Assignees and activity notifications

**Hypothesis:** Status changes keep growing (47 in December to 149 in January, and ~9 a day by the end of the data) while DAU stays flat, so each move is currently seen only by the person who made it. If a card move notifies the people connected to that card, every move gives someone else a reason to open the app.

**Expected impact:** Planning estimate: at ~9 moves a day, with 1 person notified per move and 20% opening the app, that is about 1.8 extra visits a day, or roughly +1 to +2 DAU (+10-15%), and it grows as moves per day grow. Prerequisite: add a user_id column to card_change_history (today we cannot tell who moved a card), which also gives better analytics.

**What the feature is:** Each card can have an assignee and watchers. When a card changes lane or priority, they get an in-app notification and an optional email ('Dana moved Wiza LLC to Complete'). A simple activity feed on the board shows the latest moves.

## SQL

```sql
-- TYPE YOUR SQL QUERY BELOW
--
-- Notes
--  * Timestamps are Unix seconds, so we convert with date(x, 'unixepoch').
--  * "Launch date" = the first real status change (a row in card_change_history
--    where oldStatus IS NOT NULL). Rows with oldStatus NULL are card creation,
--    not a status change. This gives 2018-06-28.
--  * A calendar table is used so days with ZERO logins count as 0 instead of
--    silently disappearing from the average (there are 9 such days).

-- PART 1: Create a SQL query that maps out the daily average users before and after the feature change

-- 1a. Average daily active users, before vs after launch
WITH RECURSIVE
launch AS (
  SELECT date(MIN(timestamp), 'unixepoch') AS launch_date
  FROM card_change_history
  WHERE oldStatus IS NOT NULL
),
calendar(day) AS (
  SELECT date(MIN(login_timestamp), 'unixepoch') FROM login_history
  UNION ALL
  SELECT date(day, '+1 day') FROM calendar
  WHERE day < (SELECT date(MAX(login_timestamp), 'unixepoch') FROM login_history)
),
dau AS (
  SELECT calendar.day AS day, COUNT(DISTINCT l.user_id) AS active_users
  FROM calendar
  LEFT JOIN login_history l ON date(l.login_timestamp, 'unixepoch') = calendar.day
  GROUP BY calendar.day
)
SELECT CASE WHEN dau.day < launch.launch_date THEN 'before' ELSE 'after' END AS period,
       COUNT(*)                          AS days,
       ROUND(AVG(dau.active_users), 2)   AS avg_daily_active_users
FROM dau CROSS JOIN launch
GROUP BY period
ORDER BY MIN(dau.day);

-- 1b. Like-for-like check: the 28 days before launch vs the 28 days after
WITH RECURSIVE
launch AS (
  SELECT date(MIN(timestamp), 'unixepoch') AS launch_date
  FROM card_change_history
  WHERE oldStatus IS NOT NULL
),
calendar(day) AS (
  SELECT date(MIN(login_timestamp), 'unixepoch') FROM login_history
  UNION ALL
  SELECT date(day, '+1 day') FROM calendar
  WHERE day < (SELECT date(MAX(login_timestamp), 'unixepoch') FROM login_history)
),
dau AS (
  SELECT calendar.day AS day, COUNT(DISTINCT l.user_id) AS active_users
  FROM calendar
  LEFT JOIN login_history l ON date(l.login_timestamp, 'unixepoch') = calendar.day
  GROUP BY calendar.day
)
SELECT CASE WHEN dau.day < launch.launch_date THEN '28 days before' ELSE '28 days after' END AS period,
       COUNT(*)                          AS days,
       ROUND(AVG(dau.active_users), 2)   AS avg_daily_active_users
FROM dau CROSS JOIN launch
WHERE dau.day >= date(launch.launch_date, '-28 days')
  AND dau.day <  date(launch.launch_date, '+28 days')
GROUP BY period
ORDER BY MIN(dau.day);

-- 1c. Daily series used to draw the graph (one row per calendar day)
WITH RECURSIVE
launch AS (
  SELECT date(MIN(timestamp), 'unixepoch') AS launch_date
  FROM card_change_history
  WHERE oldStatus IS NOT NULL
),
calendar(day) AS (
  SELECT date(MIN(login_timestamp), 'unixepoch') FROM login_history
  UNION ALL
  SELECT date(day, '+1 day') FROM calendar
  WHERE day < (SELECT date(MAX(login_timestamp), 'unixepoch') FROM login_history)
)
SELECT calendar.day,
       COUNT(DISTINCT l.user_id) AS active_users,
       CASE WHEN calendar.day < launch.launch_date THEN 'before' ELSE 'after' END AS period
FROM calendar
CROSS JOIN launch
LEFT JOIN login_history l ON date(l.login_timestamp, 'unixepoch') = calendar.day
GROUP BY calendar.day
ORDER BY calendar.day;


-- PART 2: Create a SQL query that indicates the number of status changes by card

-- 2a. Total status changes per card (cards that never moved show 0)
SELECT c.id   AS card_id,
       c.name AS card_name,
       COUNT(h.id) AS status_changes
FROM card c
LEFT JOIN card_change_history h
       ON h.cardID = c.id
      AND h.oldStatus IS NOT NULL
      AND h.oldStatus <> h.newStatus
GROUP BY c.id, c.name
ORDER BY status_changes DESC, c.id;

-- 2b. Daily status changes by card
SELECT date(h.timestamp, 'unixepoch') AS day,
       h.cardID                       AS card_id,
       c.name                         AS card_name,
       COUNT(*)                       AS status_changes
FROM card_change_history h
JOIN card c ON c.id = h.cardID
WHERE h.oldStatus IS NOT NULL
  AND h.oldStatus <> h.newStatus
GROUP BY day, h.cardID, c.name
ORDER BY day, status_changes DESC, h.cardID;

-- 2c. How many cards had 0, 1, 2, ... status changes (used for the histogram)
SELECT status_changes, COUNT(*) AS cards
FROM (
  SELECT c.id, COUNT(h.id) AS status_changes
  FROM card c
  LEFT JOIN card_change_history h
         ON h.cardID = c.id
        AND h.oldStatus IS NOT NULL
        AND h.oldStatus <> h.newStatus
  GROUP BY c.id
)
GROUP BY status_changes
ORDER BY status_changes;

```
