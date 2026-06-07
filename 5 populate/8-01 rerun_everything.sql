------------------------------------------------------------------
-- This reruns everything and generates all new data
------------------------------------------------------------------
-- Data files must be uploaded into proper stage locations in
-- snowflake before ingestions can be run
------------------------------------------------------------------

-------------------------------------------
-- ingest 
-------------------------------------------
delete from rli.ingest.raw_customers;
delete from rli.ingest.raw_policies;
delete from rli.ingest.raw_claims;
delete from rli.ingest.raw_payments;
delete from rli.ingest.raw_endorsements;
call rli.ingest.load_raw_customers();
call rli.ingest.load_raw_policies();
call rli.ingest.load_raw_claims();
call rli.ingest.load_raw_payments();
call rli.ingest.load_raw_endorsements();

-------------------------------------------
-- collect (ingest stage 2)
-------------------------------------------
delete from rli.collect.col_customers;
delete from rli.collect.col_policies;
delete from rli.collect.col_claims;
delete from rli.collect.col_payments;
delete from rli.collect.col_endorsements;
call rli.collect.collect_customers();
call rli.collect.collect_policies();
call rli.collect.collect_claims();
call rli.collect.collect_payments();
call rli.collect.collect_endorsements();

-------------------------------------------
-- transform
-------------------------------------------
delete from rli.transform.trn_customers;
delete from rli.transform.trn_policies;
delete from rli.transform.trn_claims;
delete from rli.transform.trn_payments;
delete from rli.transform.trn_endorsements;
call rli.transform.transform_customers();
call rli.transform.transform_policies();
call rli.transform.transform_claims();
call rli.transform.transform_payments();
call rli.transform.transform_endorsements();

-------------------------------------------
-- present
-------------------------------------------
call rli.present.generate_loss_ratio_by_policy_type();
call rli.present.generate_loss_ratio_by_policy_type_yearmonth(); -- (30 seconds)
call rli.present.generate_claims_payments_by_segment_yearmonth(); -- (35 seconds)
call rli.present.generate_customer_risk_tables(); -- (10 seconds)
call rli.present.generate_quarterly_policy_data(); -- (10 seconds)