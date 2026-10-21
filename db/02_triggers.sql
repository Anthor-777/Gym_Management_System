USE gym_management;
DROP TRIGGER IF EXISTS bi_member_validate;
DROP TRIGGER IF EXISTS bu_member_validate;
DROP TRIGGER IF EXISTS bi_subscription_validate;
DROP TRIGGER IF EXISTS bu_subscription_validate;
DROP TRIGGER IF EXISTS bi_payment_validate;
DROP TRIGGER IF EXISTS bu_payment_validate;
DROP TRIGGER IF EXISTS bi_attendance_open_visit;
DROP TRIGGER IF EXISTS bu_attendance_open_visit;
DELIMITER $$

-- BUSINESS RULE CONSTANT: minimum_member_age_years = 14; keep insert and update checks aligned.
CREATE TRIGGER bi_member_validate BEFORE INSERT ON member FOR EACH ROW
BEGIN
  IF NEW.dob >= NEW.join_date OR NEW.dob > CURRENT_DATE
     OR NEW.dob > DATE_SUB(NEW.join_date, INTERVAL 14 YEAR) THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 45010, MESSAGE_TEXT = '45010 invalid member date or age';
  END IF;
END$$
CREATE TRIGGER bu_member_validate BEFORE UPDATE ON member FOR EACH ROW
BEGIN
  IF NEW.dob >= NEW.join_date OR NEW.dob > CURRENT_DATE
     OR NEW.dob > DATE_SUB(NEW.join_date, INTERVAL 14 YEAR) THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 45010, MESSAGE_TEXT = '45010 invalid member date or age';
  END IF;
END$$

CREATE TRIGGER bi_subscription_validate BEFORE INSERT ON subscription FOR EACH ROW
BEGIN
  IF NEW.status IN ('Pending','Active') AND EXISTS (
    SELECT 1 FROM subscription s WHERE s.member_id = NEW.member_id
      AND s.status IN ('Pending','Active')
      AND NEW.start_date <= s.end_date AND NEW.end_date >= s.start_date
  ) THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 45002, MESSAGE_TEXT = '45002 overlapping subscription';
  END IF;
END$$
CREATE TRIGGER bu_subscription_validate BEFORE UPDATE ON subscription FOR EACH ROW
BEGIN
  IF NEW.status IN ('Pending','Active') AND EXISTS (
    SELECT 1 FROM subscription s WHERE s.member_id = NEW.member_id AND s.sub_id <> OLD.sub_id
      AND s.status IN ('Pending','Active')
      AND NEW.start_date <= s.end_date AND NEW.end_date >= s.start_date
  ) THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 45002, MESSAGE_TEXT = '45002 overlapping subscription';
  END IF;
END$$

CREATE TRIGGER bi_payment_validate BEFORE INSERT ON payment FOR EACH ROW
BEGIN
  DECLARE v_fee DECIMAL(10,2);
  DECLARE v_total DECIMAL(12,2);
  SELECT mp.fee INTO v_fee FROM subscription s JOIN membership_plan mp ON mp.plan_id=s.plan_id WHERE s.sub_id=NEW.sub_id;
  SELECT COALESCE(SUM(amount),0) INTO v_total FROM payment WHERE sub_id=NEW.sub_id;
  IF v_total + NEW.amount > v_fee THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 45003, MESSAGE_TEXT = '45003 payment exceeds plan fee';
  END IF;
END$$
CREATE TRIGGER bu_payment_validate BEFORE UPDATE ON payment FOR EACH ROW
BEGIN
  DECLARE v_fee DECIMAL(10,2);
  DECLARE v_total DECIMAL(12,2);
  SELECT mp.fee INTO v_fee FROM subscription s JOIN membership_plan mp ON mp.plan_id=s.plan_id WHERE s.sub_id=NEW.sub_id;
  SELECT COALESCE(SUM(amount),0) INTO v_total FROM payment WHERE sub_id=NEW.sub_id AND payment_id<>OLD.payment_id;
  IF v_total + NEW.amount > v_fee THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 45003, MESSAGE_TEXT = '45003 payment exceeds plan fee';
  END IF;
END$$

CREATE TRIGGER bi_attendance_open_visit BEFORE INSERT ON attendance FOR EACH ROW
BEGIN
  IF NEW.check_out IS NULL AND NEW.visit_date = CURRENT_DATE AND EXISTS (
    SELECT 1 FROM attendance a WHERE a.member_id=NEW.member_id AND a.visit_date=CURRENT_DATE AND a.check_out IS NULL
  ) THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 45005, MESSAGE_TEXT = '45005 member already checked in today';
  END IF;
END$$
CREATE TRIGGER bu_attendance_open_visit BEFORE UPDATE ON attendance FOR EACH ROW
BEGIN
  IF NEW.check_out IS NULL AND NEW.visit_date = CURRENT_DATE AND EXISTS (
    SELECT 1 FROM attendance a WHERE a.member_id=NEW.member_id AND a.visit_date=CURRENT_DATE
      AND a.check_out IS NULL AND a.att_id<>OLD.att_id
  ) THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 45005, MESSAGE_TEXT = '45005 member already checked in today';
  END IF;
END$$

DELIMITER ;
