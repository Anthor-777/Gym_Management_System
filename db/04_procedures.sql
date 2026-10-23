USE gym_management;
DROP EVENT IF EXISTS ev_daily_maintenance;
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
DELIMITER $$

CREATE PROCEDURE sp_register_member(IN p_name VARCHAR(100),IN p_dob DATE,IN p_gender VARCHAR(10),IN p_phone VARCHAR(15),IN p_email VARCHAR(120))
BEGIN
  DECLARE v_id INT UNSIGNED;
  DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45008,MESSAGE_TEXT='45008 duplicate email or phone'; END;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  IF p_name IS NULL OR TRIM(p_name)='' OR p_dob IS NULL OR p_gender IS NULL OR p_gender NOT IN ('Male','Female','Other')
     OR p_phone IS NULL OR TRIM(p_phone)='' OR p_email IS NULL OR TRIM(p_email)='' THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45010,MESSAGE_TEXT='45010 invalid member input';
  END IF;
  INSERT INTO member(name,dob,gender,phone,email) VALUES(TRIM(p_name),p_dob,p_gender,TRIM(p_phone),TRIM(p_email));
  SET v_id=LAST_INSERT_ID(); COMMIT;
  SELECT * FROM member WHERE member_id=v_id;
END$$

CREATE PROCEDURE sp_create_subscription(IN p_member_id INT UNSIGNED,IN p_plan_id INT UNSIGNED,IN p_start_date DATE)
BEGIN
  DECLARE v_count INT; DECLARE v_locked_member INT UNSIGNED; DECLARE v_months TINYINT UNSIGNED; DECLARE v_end DATE; DECLARE v_id INT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT COUNT(*) INTO v_count FROM member WHERE member_id=p_member_id;
  IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45001,MESSAGE_TEXT='45001 member not found'; END IF;
  SELECT member_id INTO v_locked_member FROM member WHERE member_id=p_member_id FOR UPDATE;
  SELECT COUNT(*),MAX(duration_months) INTO v_count,v_months FROM membership_plan WHERE plan_id=p_plan_id;
  IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45009,MESSAGE_TEXT='45009 plan not found'; END IF;
  IF p_start_date IS NULL THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45010,MESSAGE_TEXT='45010 invalid start date'; END IF;
  SET v_end=DATE_SUB(DATE_ADD(p_start_date,INTERVAL v_months MONTH),INTERVAL 1 DAY);
  IF EXISTS(SELECT 1 FROM subscription s WHERE s.member_id=p_member_id AND s.status IN ('Pending','Active')
            AND p_start_date<=s.end_date AND v_end>=s.start_date) THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45002,MESSAGE_TEXT='45002 overlapping subscription';
  END IF;
  INSERT INTO subscription(member_id,plan_id,start_date,end_date,status) VALUES(p_member_id,p_plan_id,p_start_date,v_end,'Pending');
  SET v_id=LAST_INSERT_ID(); COMMIT;
  SELECT * FROM subscription WHERE sub_id=v_id;
END$$

CREATE PROCEDURE sp_record_payment(IN p_sub_id INT UNSIGNED,IN p_amount DECIMAL(10,2),IN p_payment_mode VARCHAR(20))
BEGIN
  DECLARE v_status VARCHAR(20); DECLARE v_fee DECIMAL(10,2); DECLARE v_total DECIMAL(12,2); DECLARE v_payment INT UNSIGNED; DECLARE v_count INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT COUNT(*) INTO v_count FROM subscription WHERE sub_id=p_sub_id;
  IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45009,MESSAGE_TEXT='45009 subscription not found'; END IF;
  SELECT s.status,mp.fee INTO v_status,v_fee FROM subscription s JOIN membership_plan mp ON mp.plan_id=s.plan_id WHERE s.sub_id=p_sub_id FOR UPDATE;
  IF v_status<>'Pending' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45010,MESSAGE_TEXT='45010 payment requires Pending subscription'; END IF;
  IF p_amount IS NULL OR p_amount<=0 OR p_payment_mode IS NULL OR p_payment_mode NOT IN ('Cash','Card','UPI','NetBanking') THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45010,MESSAGE_TEXT='45010 invalid payment input'; END IF;
  SELECT COALESCE(SUM(amount),0) INTO v_total FROM payment WHERE sub_id=p_sub_id;
  IF v_total+p_amount>v_fee THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45003,MESSAGE_TEXT='45003 payment exceeds plan fee'; END IF;
  INSERT INTO payment(sub_id,amount,payment_mode) VALUES(p_sub_id,p_amount,p_payment_mode);
  SET v_payment=LAST_INSERT_ID(); SET v_total=v_total+p_amount;
  IF v_total=v_fee THEN UPDATE subscription SET status='Active' WHERE sub_id=p_sub_id; END IF;
  COMMIT;
  SELECT p.*,s.status AS subscription_status,v_total AS total_paid,(v_fee-v_total) AS balance_due
    FROM payment p JOIN subscription s ON s.sub_id=p.sub_id WHERE p.payment_id=v_payment;
END$$

CREATE PROCEDURE sp_cancel_subscription(IN p_sub_id INT UNSIGNED)
BEGIN
  DECLARE v_status VARCHAR(20); DECLARE v_count INT; DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT COUNT(*) INTO v_count FROM subscription WHERE sub_id=p_sub_id;
  IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45009,MESSAGE_TEXT='45009 subscription not found'; END IF;
  SELECT status INTO v_status FROM subscription WHERE sub_id=p_sub_id FOR UPDATE;
  IF v_status NOT IN ('Pending','Active') THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45010,MESSAGE_TEXT='45010 subscription cannot be cancelled'; END IF;
  UPDATE subscription SET status='Cancelled' WHERE sub_id=p_sub_id; COMMIT;
  SELECT * FROM subscription WHERE sub_id=p_sub_id;
END$$

CREATE PROCEDURE sp_check_in(IN p_member_id INT UNSIGNED)
BEGIN
  DECLARE v_count INT; DECLARE v_locked_member INT UNSIGNED; DECLARE v_id INT UNSIGNED; DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT COUNT(*) INTO v_count FROM member WHERE member_id=p_member_id;
  IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45001,MESSAGE_TEXT='45001 member not found'; END IF;
  SELECT member_id INTO v_locked_member FROM member WHERE member_id=p_member_id FOR UPDATE;
  IF NOT EXISTS(SELECT 1 FROM subscription WHERE member_id=p_member_id AND status='Active' AND start_date<=CURRENT_DATE AND end_date>=CURRENT_DATE) THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45004,MESSAGE_TEXT='45004 no active subscription covering date'; END IF;
  IF EXISTS(SELECT 1 FROM attendance WHERE member_id=p_member_id AND visit_date=CURRENT_DATE AND check_out IS NULL) THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45005,MESSAGE_TEXT='45005 member already checked in today'; END IF;
  INSERT INTO attendance(member_id,visit_date,check_in) VALUES(p_member_id,CURRENT_DATE,CURRENT_TIME);
  SET v_id=LAST_INSERT_ID(); COMMIT; SELECT * FROM attendance WHERE att_id=v_id;
END$$

CREATE PROCEDURE sp_check_out(IN p_member_id INT UNSIGNED)
BEGIN
  DECLARE v_id INT UNSIGNED; DECLARE v_count INT; DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT COUNT(*) INTO v_count FROM attendance WHERE member_id=p_member_id AND visit_date=CURRENT_DATE AND check_out IS NULL;
  IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45011,MESSAGE_TEXT='45011 no open visit to check out'; END IF;
  SELECT att_id INTO v_id FROM attendance WHERE member_id=p_member_id AND visit_date=CURRENT_DATE AND check_out IS NULL ORDER BY att_id DESC LIMIT 1 FOR UPDATE;
  -- CURRENT_TIME has 1-second precision; if checkout lands in the same second as check-in, bump by 1s so chk_attendance_checkout (check_out > check_in) holds.
  UPDATE attendance SET check_out=IF(CURRENT_TIME>check_in,CURRENT_TIME,ADDTIME(check_in,'00:00:01')) WHERE att_id=v_id; COMMIT;
  SELECT * FROM attendance WHERE att_id=v_id;
END$$

CREATE PROCEDURE sp_create_session(IN p_trainer_id INT UNSIGNED,IN p_slot_datetime DATETIME,IN p_focus_area VARCHAR(100))
BEGIN
  DECLARE v_count INT; DECLARE v_id INT UNSIGNED;
  DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45006,MESSAGE_TEXT='45006 trainer slot already taken'; END;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT COUNT(*) INTO v_count FROM trainer WHERE trainer_id=p_trainer_id;
  IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45009,MESSAGE_TEXT='45009 trainer not found'; END IF;
  IF p_slot_datetime IS NULL OR p_slot_datetime<=CURRENT_TIMESTAMP OR p_focus_area IS NULL OR TRIM(p_focus_area)='' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45010,MESSAGE_TEXT='45010 invalid session input'; END IF;
  INSERT INTO training_session(trainer_id,slot_datetime,focus_area) VALUES(p_trainer_id,p_slot_datetime,TRIM(p_focus_area));
  SET v_id=LAST_INSERT_ID(); COMMIT; SELECT * FROM training_session WHERE session_id=v_id;
END$$

CREATE PROCEDURE sp_book_session(IN p_session_id INT UNSIGNED,IN p_member_id INT UNSIGNED)
BEGIN
  DECLARE v_slot DATETIME; DECLARE v_date DATE; DECLARE v_count INT; DECLARE v_status VARCHAR(20); DECLARE v_id INT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT COUNT(*) INTO v_count FROM training_session WHERE session_id=p_session_id;
  IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45009,MESSAGE_TEXT='45009 session not found'; END IF;
  SELECT slot_datetime INTO v_slot FROM training_session WHERE session_id=p_session_id FOR UPDATE;
  IF v_slot<=CURRENT_TIMESTAMP THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45010,MESSAGE_TEXT='45010 session slot is not in the future'; END IF;
  SELECT COUNT(*) INTO v_count FROM member WHERE member_id=p_member_id;
  IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45001,MESSAGE_TEXT='45001 member not found'; END IF;
  SET v_date=DATE(v_slot);
  IF NOT EXISTS(SELECT 1 FROM subscription WHERE member_id=p_member_id AND status='Active' AND start_date<=v_date AND end_date>=v_date) THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45004,MESSAGE_TEXT='45004 no active subscription covering date'; END IF;
  SELECT COUNT(*),MAX(booking_status),MAX(booking_id) INTO v_count,v_status,v_id FROM session_booking WHERE session_id=p_session_id AND member_id=p_member_id;
  IF v_count>0 THEN
    IF v_status IN ('Cancelled','No_Show') THEN UPDATE session_booking SET booking_status='Booked',booked_at=CURRENT_TIMESTAMP WHERE booking_id=v_id;
    ELSE SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45007,MESSAGE_TEXT='45007 duplicate booking'; END IF;
  ELSE
    INSERT INTO session_booking(session_id,member_id) VALUES(p_session_id,p_member_id); SET v_id=LAST_INSERT_ID();
  END IF;
  COMMIT; SELECT * FROM session_booking WHERE booking_id=v_id;
END$$

CREATE PROCEDURE sp_cancel_booking(IN p_booking_id INT UNSIGNED)
BEGIN
  DECLARE v_status VARCHAR(20); DECLARE v_slot DATETIME; DECLARE v_count INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT COUNT(*) INTO v_count FROM session_booking WHERE booking_id=p_booking_id;
  IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45009,MESSAGE_TEXT='45009 booking not found'; END IF;
  SELECT sb.booking_status,ts.slot_datetime INTO v_status,v_slot
    FROM session_booking sb JOIN training_session ts ON ts.session_id=sb.session_id WHERE sb.booking_id=p_booking_id FOR UPDATE;
  IF v_status<>'Booked' OR v_slot<=CURRENT_TIMESTAMP THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45010,MESSAGE_TEXT='45010 booking cannot be cancelled'; END IF;
  UPDATE session_booking SET booking_status='Cancelled' WHERE booking_id=p_booking_id; COMMIT;
  SELECT * FROM session_booking WHERE booking_id=p_booking_id;
END$$

CREATE PROCEDURE sp_log_maintenance(IN p_equip_id INT UNSIGNED,IN p_service_date DATE,IN p_cost DECIMAL(10,2),IN p_technician VARCHAR(100),IN p_new_condition_status VARCHAR(20))
BEGIN
  DECLARE v_purchase DATE; DECLARE v_count INT; DECLARE v_id INT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT COUNT(*) INTO v_count FROM equipment WHERE equip_id=p_equip_id;
  IF v_count=0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45009,MESSAGE_TEXT='45009 equipment not found'; END IF;
  SELECT purchase_date INTO v_purchase FROM equipment WHERE equip_id=p_equip_id FOR UPDATE;
  IF p_service_date IS NULL OR p_service_date<v_purchase OR p_service_date>CURRENT_DATE OR p_cost IS NULL OR p_cost<0 OR p_technician IS NULL OR TRIM(p_technician)='' OR p_new_condition_status IS NULL OR p_new_condition_status NOT IN ('Excellent','Good','Fair','Needs_Repair','Out_Of_Service') THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45010,MESSAGE_TEXT='45010 invalid maintenance input'; END IF;
  INSERT INTO maintenance_log(equip_id,service_date,cost,technician) VALUES(p_equip_id,p_service_date,p_cost,TRIM(p_technician));
  SET v_id=LAST_INSERT_ID(); UPDATE equipment SET condition_status=p_new_condition_status WHERE equip_id=p_equip_id; COMMIT;
  SELECT ml.*,e.condition_status FROM maintenance_log ml JOIN equipment e ON e.equip_id=ml.equip_id WHERE ml.log_id=v_id;
END$$

CREATE PROCEDURE sp_expire_subscriptions(OUT p_rows_affected INT)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION; UPDATE subscription SET status='Expired' WHERE status='Active' AND end_date<CURRENT_DATE;
  SET p_rows_affected=ROW_COUNT(); COMMIT;
END$$
CREATE PROCEDURE sp_cancel_stale_pending(IN p_days INT,OUT p_rows_affected INT)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  IF p_days IS NULL OR p_days<0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=45010,MESSAGE_TEXT='45010 invalid stale day count'; END IF;
  START TRANSACTION;
  UPDATE subscription AS s SET status='Cancelled' WHERE s.status='Pending' AND s.start_date<DATE_SUB(CURRENT_DATE,INTERVAL p_days DAY)
    AND NOT EXISTS(SELECT 1 FROM payment p WHERE p.sub_id=s.sub_id);
  SET p_rows_affected=ROW_COUNT(); COMMIT;
END$$
CREATE PROCEDURE sp_close_stale_visits(OUT p_rows_affected INT)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  -- Assumed close time for visits left open past midnight.
  UPDATE attendance SET check_out='23:59:59' WHERE check_out IS NULL AND visit_date<CURRENT_DATE AND check_in<'23:59:59';
  SET p_rows_affected=ROW_COUNT(); COMMIT;
END$$

DELIMITER ;

-- Requires event_scheduler=ON. OUT values use session variables; the body returns no result set.
-- BUSINESS RULE CONSTANT: stale_pending_days = 7; keep this event argument aligned with README policy.
DELIMITER $$
CREATE EVENT IF NOT EXISTS ev_daily_maintenance
ON SCHEDULE EVERY 1 DAY STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 5 MINUTE)
ON COMPLETION PRESERVE ENABLE
DO BEGIN
  CALL sp_expire_subscriptions(@expired_rows);
  CALL sp_cancel_stale_pending(7,@cancelled_rows);
  CALL sp_close_stale_visits(@closed_visit_rows);
END$$
DELIMITER ;
