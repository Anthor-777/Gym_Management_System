USE gym_management;

-- Paginated member results; bind LIMIT and OFFSET as integers.
SELECT member_id,name,dob,gender,phone,email,join_date
FROM member
WHERE (? IS NULL OR name LIKE CONCAT('%',?,'%') OR phone LIKE CONCAT('%',?,'%') OR email LIKE CONCAT('%',?,'%'))
ORDER BY name,member_id LIMIT ? OFFSET ?;
-- Member search total count for the same filter (no pagination).
SELECT COUNT(*) AS total_count FROM member
WHERE (? IS NULL OR name LIKE CONCAT('%',?,'%') OR phone LIKE CONCAT('%',?,'%') OR email LIKE CONCAT('%',?,'%'));

-- Member detail profile.
SELECT * FROM member WHERE member_id=?;
-- Member subscription history with effective status.
SELECT s.*,mp.plan_name,mp.fee,
       CASE WHEN s.status='Active' AND s.end_date<CURRENT_DATE THEN 'Expired' ELSE s.status END AS effective_status
FROM subscription s JOIN membership_plan mp ON mp.plan_id=s.plan_id
WHERE s.member_id=? ORDER BY s.start_date DESC,s.sub_id DESC;
-- Member payment history.
SELECT p.* FROM payment p JOIN subscription s ON s.sub_id=p.sub_id
WHERE s.member_id=? ORDER BY p.paid_on DESC,p.payment_id DESC;
-- Paginated recent attendance; bind LIMIT/OFFSET pagination values as integers (only LIMIT is used here).
SELECT att_id,visit_date,check_in,check_out FROM attendance
WHERE member_id=? ORDER BY visit_date DESC,check_in DESC LIMIT ?;

-- Plans list.
SELECT plan_id,plan_name,duration_months,fee FROM membership_plan ORDER BY duration_months;
-- Subscriptions by stored status with effective status.
SELECT s.sub_id,s.member_id,m.name AS member_name,s.plan_id,mp.plan_name,s.start_date,s.end_date,s.status,
       CASE WHEN s.status='Active' AND s.end_date<CURRENT_DATE THEN 'Expired' ELSE s.status END AS effective_status
FROM subscription s JOIN member m ON m.member_id=s.member_id JOIN membership_plan mp ON mp.plan_id=s.plan_id
WHERE s.status=? ORDER BY s.start_date DESC;
-- Payments in a half-open date range [start, end).
SELECT p.*,s.member_id,m.name AS member_name FROM payment p
JOIN subscription s ON s.sub_id=p.sub_id JOIN member m ON m.member_id=s.member_id
WHERE p.paid_on>=? AND p.paid_on<? ORDER BY p.paid_on DESC;
-- Today's attendance.
SELECT * FROM v_todays_attendance ORDER BY check_in;
-- Trainer schedule on a calendar date.
SELECT * FROM v_trainer_schedule WHERE DATE(slot_datetime)=? ORDER BY slot_datetime,trainer_name;
-- Available future sessions for a member; requires a covering Active subscription.
SELECT ts.session_id,ts.slot_datetime,ts.focus_area,t.trainer_id,t.name AS trainer_name
FROM training_session ts JOIN trainer t ON t.trainer_id=ts.trainer_id
WHERE ts.slot_datetime>CURRENT_TIMESTAMP
  AND EXISTS(SELECT 1 FROM subscription s WHERE s.member_id=? AND s.status='Active'
             AND s.start_date<=DATE(ts.slot_datetime) AND s.end_date>=DATE(ts.slot_datetime))
  AND NOT EXISTS(SELECT 1 FROM session_booking b WHERE b.session_id=ts.session_id AND b.member_id=?
                 AND b.booking_status IN ('Booked','Attended'))
ORDER BY ts.slot_datetime;
-- Equipment filtered by condition; pass NULL for all conditions.
SELECT equip_id,name,category,purchase_date,condition_status FROM equipment
WHERE (? IS NULL OR condition_status=?) ORDER BY name;
-- Dashboard summary values (revenue uses paid_on in the server's configured local time zone).
SELECT (SELECT active_members FROM v_active_members_count) AS active_members,
       (SELECT COUNT(*) FROM attendance WHERE visit_date=CURRENT_DATE) AS todays_visits,
       (SELECT COALESCE(SUM(amount),0) FROM payment WHERE YEAR(paid_on)=YEAR(CURRENT_DATE) AND MONTH(paid_on)=MONTH(CURRENT_DATE)) AS month_revenue,
       (SELECT COUNT(*) FROM v_expiring_subscriptions) AS expiring_soon,
       (SELECT COUNT(*) FROM equipment WHERE condition_status IN ('Needs_Repair','Out_Of_Service')) AS equipment_needing_repair;
