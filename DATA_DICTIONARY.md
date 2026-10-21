# Data dictionary

All tables use InnoDB, `utf8mb4_unicode_ci`, and `created_at`/`updated_at` timestamps. All primary and foreign keys are `INT UNSIGNED`; monetary values are `DECIMAL(10,2)` in INR.

## Tables

### `member`

| Column | Type | Constraints | Meaning |
|---|---|---|---|
| `member_id` | INT UNSIGNED | PK, auto increment | Member identifier |
| `name` | VARCHAR(100) | NOT NULL | Full name |
| `dob` | DATE | NOT NULL; trigger age validation | Date of birth; at least 14 as of join date |
| `gender` | ENUM | NOT NULL | Gender selection |
| `phone` | VARCHAR(15) | NOT NULL, UNIQUE | Contact number |
| `email` | VARCHAR(120) | NOT NULL, UNIQUE | Email address |
| `join_date` | DATE | NOT NULL, default current date | Gym enrollment date |
| `created_at`, `updated_at` | TIMESTAMP | Defaults/current update | Audit timestamps |

### `membership_plan`

| Column | Type | Constraints | Meaning |
|---|---|---|---|
| `plan_id` | INT UNSIGNED | PK, auto increment | Plan identifier |
| `plan_name` | VARCHAR(60) | NOT NULL, UNIQUE | Display name |
| `duration_months` | TINYINT UNSIGNED | NOT NULL, CHECK > 0 | Plan length |
| `fee` | DECIMAL(10,2) | NOT NULL, CHECK >= 0 | Full plan price |
| `created_at`, `updated_at` | TIMESTAMP | Audit defaults | Audit timestamps |

### `subscription`

| Column | Type | Constraints | Meaning |
|---|---|---|---|
| `sub_id` | INT UNSIGNED | PK, auto increment | Subscription identifier |
| `member_id` | INT UNSIGNED | FK to `member`, RESTRICT delete | Subscriber |
| `plan_id` | INT UNSIGNED | FK to `membership_plan`, RESTRICT delete | Selected plan |
| `start_date`, `end_date` | DATE | NOT NULL; end > start | Inclusive coverage dates; end date is computed in the create procedure |
| `status` | ENUM | NOT NULL, default Pending | Stored lifecycle state |
| `created_at`, `updated_at` | TIMESTAMP | Audit defaults | Audit timestamps |

### `payment`

| Column | Type | Constraints | Meaning |
|---|---|---|---|
| `payment_id` | INT UNSIGNED | PK, auto increment | Payment identifier |
| `sub_id` | INT UNSIGNED | FK to `subscription`, RESTRICT delete | Paid subscription |
| `amount` | DECIMAL(10,2) | NOT NULL, CHECK > 0 | Installment amount |
| `paid_on` | DATETIME | NOT NULL, default current timestamp | Payment time |
| `payment_mode` | ENUM | NOT NULL | Payment method |
| `created_at`, `updated_at` | TIMESTAMP | Audit defaults | Audit timestamps |

### `attendance`

| Column | Type | Constraints | Meaning |
|---|---|---|---|
| `att_id` | INT UNSIGNED | PK, auto increment | Visit identifier |
| `member_id` | INT UNSIGNED | FK to `member`, CASCADE delete | Visiting member |
| `visit_date` | DATE | NOT NULL | Visit calendar date |
| `check_in` | TIME | NOT NULL | Check-in time |
| `check_out` | TIME | NULL; CHECK later than check-in | Same-day checkout time |
| `created_at`, `updated_at` | TIMESTAMP | Audit defaults | Audit timestamps |

### `trainer`

| Column | Type | Constraints | Meaning |
|---|---|---|---|
| `trainer_id` | INT UNSIGNED | PK, auto increment | Trainer identifier |
| `name` | VARCHAR(100) | NOT NULL | Trainer name |
| `specialization` | VARCHAR(100) | NOT NULL | Training specialty |
| `phone` | VARCHAR(15) | NOT NULL, UNIQUE | Contact number |
| `salary` | DECIMAL(10,2) | NOT NULL, CHECK >= 0 | Salary amount |
| `created_at`, `updated_at` | TIMESTAMP | Audit defaults | Audit timestamps |

### `training_session`

| Column | Type | Constraints | Meaning |
|---|---|---|---|
| `session_id` | INT UNSIGNED | PK, auto increment | Session identifier |
| `trainer_id` | INT UNSIGNED | FK to `trainer`, RESTRICT delete | Conducting trainer |
| `slot_datetime` | DATETIME | NOT NULL; unique with trainer | Session start time |
| `focus_area` | VARCHAR(100) | NOT NULL | Session topic |
| `created_at`, `updated_at` | TIMESTAMP | Audit defaults | Audit timestamps |

### `session_booking`

| Column | Type | Constraints | Meaning |
|---|---|---|---|
| `booking_id` | INT UNSIGNED | PK, auto increment | Booking identifier |
| `session_id` | INT UNSIGNED | FK to `training_session`, CASCADE delete | Booked session |
| `member_id` | INT UNSIGNED | FK to `member`, CASCADE delete | Booking member |
| `booked_at` | DATETIME | Default current timestamp | Most recent booking time |
| `booking_status` | ENUM | NOT NULL, default Booked | Booking lifecycle |
| `created_at`, `updated_at` | TIMESTAMP | Audit defaults | Audit timestamps |
| `(session_id, member_id)` | — | UNIQUE | One reusable booking row per member/session |

### `equipment`

| Column | Type | Constraints | Meaning |
|---|---|---|---|
| `equip_id` | INT UNSIGNED | PK, auto increment | Equipment identifier |
| `name` | VARCHAR(100) | NOT NULL | Equipment name |
| `category` | VARCHAR(60) | NOT NULL | Equipment category |
| `purchase_date` | DATE | NOT NULL | Purchase date |
| `condition_status` | ENUM | NOT NULL, default Good | Current condition |
| `created_at`, `updated_at` | TIMESTAMP | Audit defaults | Audit timestamps |

### `maintenance_log`

| Column | Type | Constraints | Meaning |
|---|---|---|---|
| `log_id` | INT UNSIGNED | PK, auto increment | Maintenance record identifier |
| `equip_id` | INT UNSIGNED | FK to `equipment`, CASCADE delete | Serviced equipment |
| `service_date` | DATE | NOT NULL | Service date; procedure validates against purchase date and today |
| `cost` | DECIMAL(10,2) | NOT NULL, CHECK >= 0 | Service cost |
| `technician` | VARCHAR(100) | NOT NULL | Technician name |
| `created_at`, `updated_at` | TIMESTAMP | Audit defaults | Audit timestamps |

## Relationship mapping

| ER relationship | Database mapping |
|---|---|
| Member takes Subscription (1:N) | `subscription.member_id` FK to `member.member_id` |
| Plan defines Subscription (1:N) | `subscription.plan_id` FK to `membership_plan.plan_id` |
| Subscription settled by Payment (1:N) | `payment.sub_id` FK to `subscription.sub_id`; permits installments |
| Member records Attendance (1:N) | `attendance.member_id` FK to `member.member_id` |
| Member books Session (M:N) | `session_booking` joins `member` and `training_session`; unique pair prevents duplicate rows |
| Trainer conducts Session (1:N) | `training_session.trainer_id` FK to `trainer.trainer_id` |
| Equipment undergoes Maintenance_Log (1:N) | `maintenance_log.equip_id` FK to `equipment.equip_id` |

All foreign keys cascade on key updates. Subscription/payment and trainer/session history use RESTRICT deletes; member attendance/bookings, session bookings, and equipment maintenance logs use CASCADE deletes.

## ENUM values

| Column | Allowed values |
|---|---|
| `member.gender` | `Male`, `Female`, `Other` |
| `subscription.status` | `Pending`, `Active`, `Expired`, `Cancelled` |
| `payment.payment_mode` | `Cash`, `Card`, `UPI`, `NetBanking` |
| `session_booking.booking_status` | `Booked`, `Cancelled`, `Attended`, `No_Show` |
| `equipment.condition_status` | `Excellent`, `Good`, `Fair`, `Needs_Repair`, `Out_Of_Service` |

## Procedure error codes

The backend should branch on `MYSQL_ERRNO`, never on message text. SQLSTATE is `45000` for business errors.

| MYSQL_ERRNO | Message | Suggested HTTP status | Meaning |
|---:|---|---:|---|
| 45001 | `45001 member not found` | 404 | The member ID does not exist |
| 45002 | `45002 overlapping subscription` | 409 | New Pending/Active date range overlaps another one |
| 45003 | `45003 payment exceeds plan fee` | 409 | Total payment would exceed the plan fee |
| 45004 | `45004 no active subscription covering date` | 409 | No stored-Active subscription covers check-in or session date |
| 45005 | `45005 member already checked in today` | 409 | An open visit already exists today |
| 45006 | `45006 trainer slot already taken` | 409 | Trainer already has a session at that time |
| 45007 | `45007 duplicate booking` | 409 | Booking is already Booked or Attended |
| 45008 | `45008 duplicate email or phone` | 409 | Member email or phone is already registered |
| 45009 | `45009 record not found` | 404 | Requested plan, subscription, trainer, session, booking, or equipment is missing |
| 45010 | `45010 invalid state or invalid input` | 400 | Input is invalid or operation is not allowed from current state |
| 45011 | `45011 no open visit to check out` | 409 | No open visit exists for checkout today |

