-------------------------------------------------------------------------
-- QUESTION -------------------------------------------------------------
-- How can leadership monitor policy profitability and claims exposure over time? 
-------------------------------------------------------------------------
-- METHODOLOGY ----------------------------------------------------------
-- Select policy totals by quarter
-------------------------------------------------------------------------

--drop table rli.present.prs_quarterly_policy_data;
create table if not exists rli.present.prs_quarterly_policy_data(
    policy_id number,
    customer_id varchar,
    customer_name varchar,
    yearquarter varchar,
    total_payments number(12,2),
    total_endorsements number(12,2),
    payments_endorsements number(12,2),
    claims number(12,2),
    net_income number(12,2),
    loss_ratio number(15,8)
);



create or replace procedure rli.present.generate_quarterly_policy_data()
  returns string
  language sql
  execute as caller
as
$$
declare
    current_date_iter date;
    quarter_start date;
    quarter_end date;
    current_year number;
    current_quarter number;
    yearquarter varchar;
begin

delete from rli.present.prs_quarterly_policy_data;

current_date_iter := (select date_trunc('quarter', min(payment_date)) from rli.transform.trn_payments);

while (current_date_iter <= current_date()) do
    current_year := year(current_date_iter);
    current_quarter := quarter(current_date_iter);
    yearquarter := :current_year || 'Q' || :current_quarter;
    quarter_start := current_date_iter;
    quarter_end := dateadd('day', -1, dateadd('quarter', 1, current_date_iter));

    insert into rli.present.prs_quarterly_policy_data
    select
        t.policy_id,
        c.customer_id,
        c.customer_name,
        :yearquarter,
        t.total_payments,
        t.total_endorsements,
        t.total_pe,
        t.total_claims,
        t.net_income,
        case when t.total_pe > 0 then t.total_claims / t.total_pe else null end as loss_ratio
    from table(rli.present.policy_totals(:quarter_start, :quarter_end)) t
    join rli.transform.trn_policies p
        on p.policy_id = t.policy_id
    join rli.transform.trn_customers c
        on c.customer_id = p.customer_id
    where p.effective_date <= :quarter_end
      and p.expiration_date >= :quarter_start;

    current_date_iter := dateadd('quarter', 1, current_date_iter);
end while;

    return 'quarterly policy data calculated successfully';
end;
$$;


create or replace task rli.present.generate_quarterly_policy_data_nightly
  warehouse = compute_wh
  schedule = 'using cron 20 3 * * * America/Chicago'
as
  call rli.present.generate_quarterly_policy_data();


alter task rli.present.generate_quarterly_policy_data_nightly resume;



