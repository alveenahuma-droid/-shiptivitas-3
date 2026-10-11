-- TYPE YOUR SQL QUERY BELOW
--
-- Notes
--  Timestamps are Unix seconds, so we convert with date(x, 'unixepoch').
--  "Launch date" = the first real status change (a row in card_change_history
--    where oldStatus IS NOT NULL). Rows with oldStatus NULL are card creation,
--    not a status change. This gives 2018-06-28.
--   A calendar table is used so days with ZERO logins count as 0 instead of
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
