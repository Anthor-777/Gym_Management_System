-- Optional destructive reset. Run only against the intended development database.
CREATE DATABASE IF NOT EXISTS gym_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE gym_management;
SET FOREIGN_KEY_CHECKS = 0;
DROP EVENT IF EXISTS ev_daily_maintenance;
DROP VIEW IF EXISTS v_member_current_subscription, v_subscription_payment_summary,
  v_expiring_subscriptions, v_active_members_count, v_todays_attendance,
  v_monthly_revenue, v_trainer_schedule, v_member_attendance_summary,
  v_equipment_maintenance_summary;
DROP PROCEDURE IF EXISTS sp_register_member;
DROP PROCEDURE IF EXISTS sp_create_subscription;
DROP PROCEDURE IF EXISTS sp_record_payment;
DROP PROCEDURE IF EXISTS sp_cancel_subscription;
DROP PROCEDURE IF EXISTS sp_check_in;
DROP PROCEDURE IF EXISTS sp_check_out;
DROP PROCEDURE IF EXISTS sp_create_session;
DROP PROCEDURE IF EXISTS sp_book_session;
DROP PROCEDURE IF EXISTS sp_cancel_booking;
DROP PROCEDURE IF EXISTS sp_log_maintenance;
DROP PROCEDURE IF EXISTS sp_expire_subscriptions;
DROP PROCEDURE IF EXISTS sp_cancel_stale_pending;
DROP PROCEDURE IF EXISTS sp_close_stale_visits;
DROP PROCEDURE IF EXISTS sp_run_tests;
DROP TABLE IF EXISTS maintenance_log, session_booking, attendance, payment,
  training_session, subscription, equipment, trainer, membership_plan, member;
SET FOREIGN_KEY_CHECKS = 1;
