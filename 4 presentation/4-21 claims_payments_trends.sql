-------------------------------------------------------------------------
-- QUESTION -------------------------------------------------------------
-- How do claims and payments trend across different policy segments?
-------------------------------------------------------------------------
-- METHODOLOGY ----------------------------------------------------------
-- Select claims and payments by policy type and yearmonth
-------------------------------------------------------------------------

--call rli.present.call_month_totals(to_date('2024-01-01'), to_date('2026-12-31'));

create table if not exists rli.present.prs_claims_payments_by_segment_yearmonth(
    yearmonth number,
    policy_type varchar,
    state char(2),
    industry varchar(),
    total_payments number(12,2),
    claims number(12,2)
);




create or replace procedure rli.present.generate_claims_payments_by_segment_yearmonth()
  returns string
  language sql
  execute as caller
as
$$
declare
    current_date_iter date;
    current_month number;
    current_year number;
    month_start date;
    month_end date;
begin
delete from rli.present.prs_claims_payments_by_segment_yearmonth;

current_date_iter := (select date_trunc('month', min(payment_date)) from rli.transform.trn_payments);

while (current_date_iter <= current_date()) do
    current_month := month(current_date_iter);
    current_year := year(current_date_iter);
    month_start := current_date_iter;
    month_end := dateadd('day', -1, dateadd('month', 1, current_date_iter));


------------------------------------------------
-- by policy_type, state, and industry
    insert into rli.present.prs_claims_payments_by_segment_yearmonth
    select
        :current_year * 100 + :current_month as yearmonth,
        policy_type,
        state,
        industry,
        total_payments,
        claims
    from (
        select
            s.policy_type,
            s.state,
            s.industry,
            sum(s.total_payments) as total_payments,
            sum(s.total_claims) as claims
        from (
            select *
            from rli.transform.trn_policies p
            join table(rli.present.policy_totals(:month_start, :month_end)) t
                on t.policy_id = p.policy_id
            join rli.transform.trn_customers c
                on c.customer_id = p.customer_id
        ) s
        group by s.policy_type, s.state, s.industry
    );

    current_date_iter := dateadd('month', 1, current_date_iter);
end while;

    return 'claims payments by yearmonth calculated successfully';
end;
$$;


create or replace task rli.present.generate_claims_payments_by_segment_yearmonth_nightly
  warehouse = compute_wh
  schedule = 'using cron 10 3 * * * America/Chicago'
as
  call rli.present.generate_claims_payments_by_segment_yearmonth();


alter task rli.present.generate_claims_payments_by_segment_yearmonth_nightly resume;


