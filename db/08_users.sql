USE gym_management;
-- '%' is for development only. Restrict the account to the backend host in production.
CREATE USER IF NOT EXISTS 'gym_app'@'%' IDENTIFIED BY 'CHANGE_ME';
GRANT SELECT, INSERT, UPDATE ON gym_management.* TO 'gym_app'@'%';
GRANT DELETE ON gym_management.member TO 'gym_app'@'%';
GRANT DELETE ON gym_management.membership_plan TO 'gym_app'@'%';
GRANT DELETE ON gym_management.trainer TO 'gym_app'@'%';
GRANT DELETE ON gym_management.equipment TO 'gym_app'@'%';
GRANT DELETE ON gym_management.attendance TO 'gym_app'@'%';
GRANT DELETE ON gym_management.training_session TO 'gym_app'@'%';
GRANT DELETE ON gym_management.session_booking TO 'gym_app'@'%';
-- No DELETE privilege is granted for payment, subscription, or maintenance_log.
GRANT EXECUTE ON gym_management.* TO 'gym_app'@'%';
