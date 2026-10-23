USE gym_management;

CREATE OR REPLACE VIEW v_member_current_subscription AS
SELECT m.member_id, m.name AS member_name, s.sub_id, s.plan_id, mp.plan_name,
       s.start_date, s.end_date,
       CASE WHEN s.sub_id IS NULL THEN NULL WHEN s.status='Active' THEN GREATEST(DATEDIFF(s.end_date,CURRENT_DATE),0) ELSE 0 END AS days_remaining,
       s.status,
       CASE WHEN s.status='Active' AND s.end_date<CURRENT_DATE THEN 'Expired' ELSE s.status END AS effective_status
FROM member m
LEFT JOIN subscription s ON s.sub_id=(
  SELECT s2.sub_id FROM subscription s2 WHERE s2.member_id=m.member_id
  ORDER BY (s2.status='Active' AND s2.start_date<=CURRENT_DATE AND s2.end_date>=CURRENT_DATE) DESC,
           s2.start_date DESC, s2.sub_id DESC LIMIT 1
)
LEFT JOIN membership_plan mp ON mp.plan_id=s.plan_id;

CREATE OR REPLACE VIEW v_subscription_payment_summary AS
SELECT s.sub_id,s.member_id,s.plan_id,mp.plan_name,mp.fee AS plan_fee,
       COALESCE(SUM(p.amount),0.00) AS total_paid,
       GREATEST(mp.fee-COALESCE(SUM(p.amount),0.00),0.00) AS balance_due,
       CASE WHEN mp.fee=0 THEN 'Paid'
            WHEN COALESCE(SUM(p.amount),0)=0 THEN 'Unpaid'
            WHEN COALESCE(SUM(p.amount),0)<mp.fee THEN 'Partial' ELSE 'Paid' END AS payment_state,
       s.status,CASE WHEN s.status='Active' AND s.end_date<CURRENT_DATE THEN 'Expired' ELSE s.status END AS effective_status,
       s.start_date,s.end_date
FROM subscription s JOIN membership_plan mp ON mp.plan_id=s.plan_id
LEFT JOIN payment p ON p.sub_id=s.sub_id
GROUP BY s.sub_id,s.member_id,s.plan_id,mp.plan_name,mp.fee,s.status,s.end_date,s.start_date;

CREATE OR REPLACE VIEW v_expiring_subscriptions AS
SELECT s.sub_id,m.member_id,m.name AS member_name,m.phone,m.email,mp.plan_name,s.start_date,s.end_date,
       CASE WHEN s.status='Active' AND s.end_date<CURRENT_DATE THEN 'Expired' ELSE s.status END AS effective_status
FROM subscription s JOIN member m ON m.member_id=s.member_id JOIN membership_plan mp ON mp.plan_id=s.plan_id
WHERE s.status='Active' AND s.end_date BETWEEN CURRENT_DATE AND DATE_ADD(CURRENT_DATE,INTERVAL 7 DAY);

CREATE OR REPLACE VIEW v_active_members_count AS
SELECT COUNT(DISTINCT s.member_id) AS active_members
FROM subscription s WHERE s.status='Active' AND s.start_date<=CURRENT_DATE AND s.end_date>=CURRENT_DATE;

CREATE OR REPLACE VIEW v_todays_attendance AS
SELECT a.att_id,a.member_id,m.name AS member_name,a.visit_date,a.check_in,a.check_out
FROM attendance a JOIN member m ON m.member_id=a.member_id WHERE a.visit_date=CURRENT_DATE;

CREATE OR REPLACE VIEW v_monthly_revenue AS
SELECT YEAR(paid_on) AS revenue_year,MONTH(paid_on) AS revenue_month,SUM(amount) AS total_collected,
       SUM(CASE WHEN payment_mode='Cash' THEN amount ELSE 0 END) AS cash_total,
       SUM(CASE WHEN payment_mode='Card' THEN amount ELSE 0 END) AS card_total,
       SUM(CASE WHEN payment_mode='UPI' THEN amount ELSE 0 END) AS upi_total,
       SUM(CASE WHEN payment_mode='NetBanking' THEN amount ELSE 0 END) AS netbanking_total
FROM payment GROUP BY YEAR(paid_on),MONTH(paid_on);

CREATE OR REPLACE VIEW v_trainer_schedule AS
SELECT t.trainer_id,t.name AS trainer_name,t.specialization,ts.session_id,ts.slot_datetime,ts.focus_area,
       SUM(CASE WHEN sb.booking_status='Booked' THEN 1 ELSE 0 END) AS booked_count
FROM trainer t JOIN training_session ts ON ts.trainer_id=t.trainer_id
LEFT JOIN session_booking sb ON sb.session_id=ts.session_id
WHERE ts.slot_datetime>=CURRENT_TIMESTAMP
GROUP BY t.trainer_id,t.name,t.specialization,ts.session_id,ts.slot_datetime,ts.focus_area;

CREATE OR REPLACE VIEW v_member_attendance_summary AS
SELECT m.member_id,m.name AS member_name,
       SUM(CASE WHEN a.visit_date>=DATE_SUB(CURRENT_DATE,INTERVAL 29 DAY) AND a.visit_date<=CURRENT_DATE THEN 1 ELSE 0 END) AS visits_last_30_days,
       MAX(a.visit_date) AS last_visit_date
FROM member m LEFT JOIN attendance a ON a.member_id=m.member_id GROUP BY m.member_id,m.name;

CREATE OR REPLACE VIEW v_equipment_maintenance_summary AS
SELECT e.equip_id,e.name,e.category,e.condition_status,MAX(ml.service_date) AS last_service_date,
       COALESCE(SUM(ml.cost),0.00) AS total_maintenance_cost,
       CASE WHEN MAX(ml.service_date) IS NULL THEN NULL ELSE DATEDIFF(CURRENT_DATE,MAX(ml.service_date)) END AS days_since_last_service
FROM equipment e LEFT JOIN maintenance_log ml ON ml.equip_id=e.equip_id
GROUP BY e.equip_id,e.name,e.category,e.condition_status;
