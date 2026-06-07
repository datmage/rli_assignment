-------------------------------------------------------------------
-- Turn off all of the nightly tasks ------------------------------
-------------------------------------------------------------------

alter task rli.ingest.load_customers_nightly suspend;
alter task rli.ingest.load_policies_nightly suspend;
alter task rli.ingest.load_claims_nightly suspend;
alter task rli.ingest.load_payments_nightly suspend;
alter task rli.ingest.load_endorsements_nightly suspend;

alter task rli.collect.collect_customers_nightly suspend;
alter task rli.collect.collect_policies_nightly suspend;
alter task rli.collect.collect_claims_nightly suspend;
alter task rli.collect.collect_payments_nightly suspend;
alter task rli.collect.collect_endorsements_nightly suspend;

alter task rli.transform.transform_customers_nightly suspend;
alter task rli.transform.transform_policies_nightly suspend;
alter task rli.transform.transform_claims_nightly suspend;
alter task rli.transform.transform_payments_nightly suspend;
alter task rli.transform.transform_endorsements_nightly suspend;

alter task rli.present.generate_loss_ratio_by_policy_yearmonth_nightly suspend;
alter task rli.present.generate_claims_payments_by_segment_yearmonth_nightly suspend;
alter task rli.present.generate_customer_risk_tables_nightly suspend;
alter task rli.present.generate_quarterly_policy_data_nightly suspend;