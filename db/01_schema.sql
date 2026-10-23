CREATE DATABASE IF NOT EXISTS gym_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE gym_management;

CREATE TABLE IF NOT EXISTS member (
  member_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  dob DATE NOT NULL,
  gender ENUM('Male','Female','Other') NOT NULL,
  -- Serves exact phone lookup and prevents duplicate member contact numbers.
  phone VARCHAR(15) NOT NULL UNIQUE,
  -- Serves exact email lookup and prevents duplicate member accounts.
  email VARCHAR(120) NOT NULL UNIQUE,
  join_date DATE NOT NULL DEFAULT (CURRENT_DATE),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS membership_plan (
  plan_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  -- Serves plan dropdown lookup by name and prevents duplicate plan names.
  plan_name VARCHAR(60) NOT NULL UNIQUE,
  duration_months TINYINT UNSIGNED NOT NULL,
  fee DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_plan_duration CHECK (duration_months > 0),
  CONSTRAINT chk_plan_fee CHECK (fee >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS trainer (
  trainer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  specialization VARCHAR(100) NOT NULL,
  -- Serves exact trainer phone lookup and prevents duplicate contacts.
  phone VARCHAR(15) NOT NULL UNIQUE,
  salary DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_trainer_salary CHECK (salary >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS equipment (
  equip_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  category VARCHAR(60) NOT NULL,
  purchase_date DATE NOT NULL,
  condition_status ENUM('Excellent','Good','Fair','Needs_Repair','Out_Of_Service') NOT NULL DEFAULT 'Good',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS subscription (
  sub_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  member_id INT UNSIGNED NOT NULL,
  plan_id INT UNSIGNED NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status ENUM('Pending','Active','Expired','Cancelled') NOT NULL DEFAULT 'Pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Serves member subscription filtering by status.
  KEY ix_subscription_member_status (member_id, status),
  -- Serves expiration and upcoming renewal queries.
  KEY ix_subscription_end_date (end_date),
  -- Serves status filters combined with date ranges (active count, expiring soon, expiry job).
  KEY ix_subscription_status_end (status, end_date),
  -- Serves subscription lookup by plan.
  KEY ix_subscription_plan (plan_id),
  CONSTRAINT chk_subscription_dates CHECK (end_date > start_date),
  CONSTRAINT fk_subscription_member FOREIGN KEY (member_id) REFERENCES member(member_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_subscription_plan FOREIGN KEY (plan_id) REFERENCES membership_plan(plan_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS payment (
  payment_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sub_id INT UNSIGNED NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  paid_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  payment_mode ENUM('Cash','Card','UPI','NetBanking') NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Serves subscription payment totals.
  KEY ix_payment_sub (sub_id),
  -- Serves payment date-range and monthly revenue reports.
  KEY ix_payment_paid_on (paid_on),
  CONSTRAINT chk_payment_amount CHECK (amount > 0),
  CONSTRAINT fk_payment_subscription FOREIGN KEY (sub_id) REFERENCES subscription(sub_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS attendance (
  att_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  member_id INT UNSIGNED NOT NULL,
  visit_date DATE NOT NULL,
  check_in TIME NOT NULL,
  check_out TIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Serves a member's attendance history and date-range summaries.
  KEY ix_attendance_member_date (member_id, visit_date),
  -- Serves today's attendance view and dashboard visit counts (filter by date alone).
  KEY ix_attendance_visit_date (visit_date),
  CONSTRAINT chk_attendance_checkout CHECK (check_out IS NULL OR check_out > check_in),
  CONSTRAINT fk_attendance_member FOREIGN KEY (member_id) REFERENCES member(member_id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS training_session (
  session_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  trainer_id INT UNSIGNED NOT NULL,
  slot_datetime DATETIME NOT NULL,
  focus_area VARCHAR(100) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Serves trainer schedule lookup and prevents a trainer's duplicate time slot.
  CONSTRAINT uq_trainer_slot UNIQUE (trainer_id, slot_datetime),
  -- Serves upcoming session calendars.
  KEY ix_session_slot_datetime (slot_datetime),
  CONSTRAINT fk_session_trainer FOREIGN KEY (trainer_id) REFERENCES trainer(trainer_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS session_booking (
  booking_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  session_id INT UNSIGNED NOT NULL,
  member_id INT UNSIGNED NOT NULL,
  booked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  booking_status ENUM('Booked','Cancelled','Attended','No_Show') NOT NULL DEFAULT 'Booked',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Serves session roster lookup and prevents duplicate member/session bookings.
  CONSTRAINT uq_session_member UNIQUE (session_id, member_id),
  -- Serves member booking history.
  KEY ix_booking_member (member_id),
  CONSTRAINT fk_booking_session FOREIGN KEY (session_id) REFERENCES training_session(session_id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_booking_member FOREIGN KEY (member_id) REFERENCES member(member_id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS maintenance_log (
  log_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  equip_id INT UNSIGNED NOT NULL,
  service_date DATE NOT NULL,
  cost DECIMAL(10,2) NOT NULL,
  technician VARCHAR(100) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Serves maintenance totals and service history by equipment.
  KEY ix_maintenance_equip (equip_id),
  CONSTRAINT chk_maintenance_cost CHECK (cost >= 0),
  CONSTRAINT fk_maintenance_equipment FOREIGN KEY (equip_id) REFERENCES equipment(equip_id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
