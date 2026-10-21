# Gym Management System database

MySQL 8.0.16+ implementation for the gym management API and frontend. It uses InnoDB, `utf8mb4`, and `utf8mb4_unicode_ci`. The schema is normalized to the supplied ER model; all IDs are unsigned integers and money uses `DECIMAL(10,2)` in INR.

## Install

Run these files in order against the intended MySQL server:

1. `00_reset.sql` is optional and destructive. It drops this database's tables, views, routines, and event.
2. `01_schema.sql`
3. `02_triggers.sql`
4. `03_views.sql`
5. `04_procedures.sql`
6. `05_seed.sql`
7. `06_api_queries.sql` contains examples; do not execute as a batch because it contains `?` placeholders.
8. `07_tests.sql` runs the test procedure and prints results.
9. `08_users.sql` creates the least-privilege application account.

`01_schema.sql` uses `IF NOT EXISTS`, and routine/event/view creation is repeatable. Use `00_reset.sql` before rebuilding from scratch. The seed file is intended for a fresh schema; run reset first if you need to reseed.

`02_triggers.sql`, `04_procedures.sql`, and `07_tests.sql` use `DELIMITER`, which is a MySQL command-line client feature. From a shell, load a file with `mysql -u root -p < db/01_schema.sql` (repeat in order). For a combined install, concatenate in order or use a client that supports delimiter directives. Application drivers such as mysql2, PyMySQL, and JDBC do not understand `DELIMITER`; load each `CREATE TRIGGER`, `CREATE PROCEDURE`, and `CREATE EVENT` statement as its own server request, preserving the full compound statement and omitting the client-only `DELIMITER` lines.

The test script is designed to run after the seed. It creates two test members and additional workflow records, so reset/reseed before repeating it if clean results are desired. Inspect the final test result table; a `FAIL` indicates an assertion or expected error code mismatch.

## Calling workflows from an API

Call each workflow with all arguments; MySQL procedures do not support default arguments. Procedures return one result set containing the created or updated row (payment also includes subscription status, total paid, and balance due). With mysql2, `CALL` results are returned as nested result sets; read the first row from the procedure's rowset and ignore the trailing procedure metadata result. OUT-parameter maintenance procedures return no rowset; read the session variable after the call, or use the driver's OUT parameter support.

```js
const [resultSets] = await connection.execute(
  'CALL sp_create_subscription(?, ?, ?)',
  [memberId, planId, '2026-10-18']
);
const createdSubscription = resultSets[0][0];
```

Map MySQL `MYSQL_ERRNO` values in `DATA_DICTIONARY.md` to API responses. Never parse `MESSAGE_TEXT`. The routines use transaction handlers to roll back and resignal errors. Any maintenance event can be run manually as:

```sql
CALL sp_expire_subscriptions(@expired_rows);
CALL sp_cancel_stale_pending(7,@cancelled_rows);
CALL sp_close_stale_visits(@closed_visit_rows);
SELECT @expired_rows,@cancelled_rows,@closed_visit_rows;
```

The event scheduler must be enabled (`event_scheduler=ON`) for `ev_daily_maintenance` to run shortly after midnight. It calls the maintenance procedures using session variables and does not rely on a result set. The event start time is calculated from the server's local date/time.

Set the server or connection time zone to the gym's local time. For example, IST is `+05:30`; a privileged administrator can set `SET GLOBAL time_zone = '+05:30'`, and clients can set their own session time zone. Otherwise `CURRENT_DATE` and `CURRENT_TIMESTAMP` can use UTC near midnight and give the wrong gym date. `TIMESTAMP` audit fields follow the connection time zone.

## Pagination and prepared statements

Some drivers (including mysql2 `execute()`) require integer values for `LIMIT` and `OFFSET` placeholders. Validate and convert page inputs to integers before binding; do not interpolate raw user text into SQL.

```js
const page = Math.max(1, Number.parseInt(req.query.page ?? '1', 10));
const pageSize = Math.min(100, Math.max(1, Number.parseInt(req.query.pageSize ?? '20', 10)));
const offset = (page - 1) * pageSize;
const [rows] = await connection.execute(
  'SELECT member_id,name FROM member ORDER BY name LIMIT ? OFFSET ?',
  [pageSize, offset]
);
```

## Assumptions and boundaries

- The business rule constants are minimum member age **14 years** and stale pending age **7 days**. The age is checked against `join_date`; the stale age is passed as `7` by the daily event. Change the trigger rule and event argument together when policy changes.
- Attendance `check_out` is a time on the same calendar date as `visit_date`; the schema has no checkout date. Stale open visits are closed at the assumed time `23:59:59` on their visit date.
- Subscription date ranges are inclusive. End date is calculated as start plus plan duration in months minus one day by `sp_create_subscription`.
- Route business writes through the stored procedures. The app account has the requested table DML grants, so direct table writes can bypass workflow rules beyond the trigger safety checks.
- Plans allow a zero fee, while payment amounts must be positive. A zero-fee plan therefore needs a separate complimentary activation policy if the gym intends to offer one.
- Stored `Active` status can be stale if the scheduled event does not run. Views and API examples expose `effective_status`, computed as `Expired` for a stored-Active row whose end date has passed.
- Booking status uniqueness is one row per member/session. A cancelled or no-show booking is reactivated in place and receives a new `booked_at` value.
- Session capacity and session duration are not in the ER model and are not enforced. Consider adding them if the business defines those rules.
- The ER model has no user authentication table. Add authentication, credential storage, and authorization as a separate design before exposing account login.
- The test procedure assumes the seeded trainer, plan, and equipment rows, and uses sample member ID 15 for the no-active-subscription check.

## Suggestions

Consider defining session capacity and duration, plus an authentication table with password hashes and role/permission mapping. These are suggestions only and are not part of this schema.
