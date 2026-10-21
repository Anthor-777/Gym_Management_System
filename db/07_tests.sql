USE gym_management;
DROP PROCEDURE IF EXISTS sp_run_tests;
CREATE TEMPORARY TABLE IF NOT EXISTS test_results(test_name VARCHAR(120) PRIMARY KEY,result VARCHAR(10),details VARCHAR(255));
TRUNCATE TABLE test_results;
DELIMITER $$
CREATE PROCEDURE sp_run_tests()
BEGIN
  DECLARE v_member INT UNSIGNED; DECLARE v_member2 INT UNSIGNED; DECLARE v_sub INT UNSIGNED;
  DECLARE v_sub2 INT UNSIGNED; DECLARE v_session INT UNSIGNED; DECLARE v_booking INT UNSIGNED;
  DECLARE v_equip INT UNSIGNED; DECLARE v_trainer INT UNSIGNED; DECLARE v_plan INT UNSIGNED; DECLARE v_errno INT;
  SELECT plan_id INTO v_plan FROM membership_plan WHERE plan_name='Monthly';

  -- Expects a new member registration to succeed.
  CALL sp_register_member('Test Member',DATE_SUB(CURRENT_DATE,INTERVAL 25 YEAR),'Other','9899900001','workflow.test@example.in');
  SELECT member_id INTO v_member FROM member WHERE email='workflow.test@example.in';
  INSERT INTO test_results VALUES('register member','PASS','Created test member');

  -- Expects a Pending subscription to be created.
  CALL sp_create_subscription(v_member,v_plan,CURRENT_DATE);
  SELECT sub_id INTO v_sub FROM subscription WHERE member_id=v_member ORDER BY sub_id DESC LIMIT 1;
  INSERT INTO test_results VALUES('create subscription','PASS','Created Pending subscription');

  -- Expects a partial payment to succeed.
  CALL sp_record_payment(v_sub,500,'UPI');
  INSERT INTO test_results VALUES('partial payment','PASS','Accepted partial amount');

  -- Expects exact final payment to activate the subscription.
  CALL sp_record_payment(v_sub,700,'Card');
  IF (SELECT status FROM subscription WHERE sub_id=v_sub)='Active' THEN
    INSERT INTO test_results VALUES('full payment activates','PASS','Status is Active');
  ELSE INSERT INTO test_results VALUES('full payment activates','FAIL','Status did not become Active'); END IF;

  -- Expects check-in and check-out to succeed.
  CALL sp_check_in(v_member); INSERT INTO test_results VALUES('check in','PASS','Visit opened');
  CALL sp_check_out(v_member); INSERT INTO test_results VALUES('check out','PASS','Visit closed');

  -- Expects a second immediate check-in to fail with 45005.
  CALL sp_check_in(v_member);
  SET v_errno=0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
      INSERT INTO test_results VALUES('second check in',IF(v_errno=45005,'PASS','FAIL'),CONCAT('MYSQL_ERRNO=',v_errno)); END;
    CALL sp_check_in(v_member);
  END;
  IF v_errno=0 THEN INSERT INTO test_results VALUES('second check in','FAIL','Expected error 45005 was not raised'); END IF;
  CALL sp_check_out(v_member);

  -- Expects a second overlapping Pending/Active subscription to fail with 45002.
  SET v_errno=0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
      INSERT INTO test_results VALUES('overlapping subscription',IF(v_errno=45002,'PASS','FAIL'),CONCAT('MYSQL_ERRNO=',v_errno)); END;
    CALL sp_create_subscription(v_member,v_plan,CURRENT_DATE);
  END;
  IF v_errno=0 THEN INSERT INTO test_results VALUES('overlapping subscription','FAIL','Expected error 45002 was not raised'); END IF;

  -- Expects check-in for a member without a covering Active subscription to fail with 45004.
  SET v_errno=0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
      INSERT INTO test_results VALUES('check in without active plan',IF(v_errno=45004,'PASS','FAIL'),CONCAT('MYSQL_ERRNO=',v_errno)); END;
    CALL sp_check_in(15);
  END;
  IF v_errno=0 THEN INSERT INTO test_results VALUES('check in without active plan','FAIL','Expected error 45004 was not raised'); END IF;

  -- Expects overpayment on a separate Pending subscription to fail with 45003.
  CALL sp_register_member('Payment Test',DATE_SUB(CURRENT_DATE,INTERVAL 30 YEAR),'Male','9899900002','payment.test@example.in');
  SELECT member_id INTO v_member2 FROM member WHERE email='payment.test@example.in';
  CALL sp_create_subscription(v_member2,v_plan,CURRENT_DATE);
  SELECT sub_id INTO v_sub2 FROM subscription WHERE member_id=v_member2 ORDER BY sub_id DESC LIMIT 1;
  SET v_errno=0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
      INSERT INTO test_results VALUES('overpayment',IF(v_errno=45003,'PASS','FAIL'),CONCAT('MYSQL_ERRNO=',v_errno)); END;
    CALL sp_record_payment(v_sub2,1201,'Cash');
  END;
  IF v_errno=0 THEN INSERT INTO test_results VALUES('overpayment','FAIL','Expected error 45003 was not raised'); END IF;

  -- Expects an invalid check-out time to be rejected by the table CHECK.
  SET v_errno=0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
      INSERT INTO test_results VALUES('check out before check in','PASS',CONCAT('Rejected, MYSQL_ERRNO=',v_errno)); END;
    INSERT INTO attendance(member_id,visit_date,check_in,check_out) VALUES(v_member,CURRENT_DATE,'18:00:00','17:59:00');
  END;
  IF v_errno=0 THEN INSERT INTO test_results VALUES('check out before check in','FAIL','Expected CHECK violation was not raised'); END IF;

  -- Expects a future session to be created.
  SELECT trainer_id INTO v_trainer FROM trainer ORDER BY trainer_id LIMIT 1;
  CALL sp_create_session(v_trainer,DATE_ADD(CURRENT_TIMESTAMP,INTERVAL 10 DAY),'Test Strength');
  SELECT session_id INTO v_session FROM training_session WHERE trainer_id=v_trainer AND focus_area='Test Strength' ORDER BY session_id DESC LIMIT 1;
  INSERT INTO test_results VALUES('create session','PASS','Created future trainer slot');

  -- Expects the same trainer slot to fail with 45006.
  SET v_errno=0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
      INSERT INTO test_results VALUES('double book trainer',IF(v_errno=45006,'PASS','FAIL'),CONCAT('MYSQL_ERRNO=',v_errno)); END;
    CALL sp_create_session(v_trainer,DATE_ADD(CURRENT_TIMESTAMP,INTERVAL 10 DAY),'Duplicate Slot');
  END;
  IF v_errno=0 THEN INSERT INTO test_results VALUES('double book trainer','FAIL','Expected error 45006 was not raised'); END IF;

  -- Expects a covered future session booking to succeed.
  CALL sp_book_session(v_session,v_member); SELECT booking_id INTO v_booking FROM session_booking WHERE session_id=v_session AND member_id=v_member;
  INSERT INTO test_results VALUES('book session','PASS','Created booking');

  -- Expects an existing Booked row to fail with 45007.
  SET v_errno=0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
      INSERT INTO test_results VALUES('duplicate booking',IF(v_errno=45007,'PASS','FAIL'),CONCAT('MYSQL_ERRNO=',v_errno)); END;
    CALL sp_book_session(v_session,v_member);
  END;
  IF v_errno=0 THEN INSERT INTO test_results VALUES('duplicate booking','FAIL','Expected error 45007 was not raised'); END IF;

  -- Expects cancellation and rebooking of the same booking row to succeed.
  CALL sp_cancel_booking(v_booking); CALL sp_book_session(v_session,v_member);
  INSERT INTO test_results VALUES('cancel and rebook','PASS','Booking returned to Booked');

  -- Expects duplicate email/phone registration to fail with 45008.
  SET v_errno=0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
      INSERT INTO test_results VALUES('duplicate email',IF(v_errno=45008,'PASS','FAIL'),CONCAT('MYSQL_ERRNO=',v_errno)); END;
    CALL sp_register_member('Duplicate Test',DATE_SUB(CURRENT_DATE,INTERVAL 25 YEAR),'Other','9899900003','workflow.test@example.in');
  END;
  IF v_errno=0 THEN INSERT INTO test_results VALUES('duplicate email','FAIL','Expected error 45008 was not raised'); END IF;

  -- Expects a maintenance log and equipment condition update to succeed.
  SELECT equip_id INTO v_equip FROM equipment ORDER BY equip_id LIMIT 1;
  CALL sp_log_maintenance(v_equip,CURRENT_DATE,250,'Test Technician','Good');
  INSERT INTO test_results VALUES('log maintenance','PASS','Inserted log and updated condition');

  -- Expects payment on a non-Pending subscription to fail with 45010.
  SET v_errno=0;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
      INSERT INTO test_results VALUES('payment on Active subscription',IF(v_errno=45010,'PASS','FAIL'),CONCAT('MYSQL_ERRNO=',v_errno)); END;
    CALL sp_record_payment(v_sub,1,'Cash');
  END;
  IF v_errno=0 THEN INSERT INTO test_results VALUES('payment on Active subscription','FAIL','Expected error 45010 was not raised'); END IF;
END$$
DELIMITER ;
CALL sp_run_tests();
SELECT test_name,result,details FROM test_results ORDER BY test_name;
SELECT COUNT(*) AS total_cases,SUM(result='PASS') AS passed,SUM(result='FAIL') AS failed FROM test_results;
DROP PROCEDURE sp_run_tests;
