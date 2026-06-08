-------------------------------------------------------------------------
-- QUESTION -------------------------------------------------------------
-- Which customers or policy groups may represent elevated financial risk? 
-------------------------------------------------------------------------
-- METHODOLOGY ----------------------------------------------------------
-- Select policy totals for each customer, state, industry, and state/industry
-------------------------------------------------------------------------

--select * from rli.transform.trn_customers;
drop table if exists rli.present.prs_customer_risk;
create table if not exists rli.present.prs_customer_risk(
    customer_id number,
    customer_name varchar(),
    state char(2),
    industry varchar(),
    policy_type varchar(),
    total_payments number(12,2),
    total_endorsements number(12,2),
    payments_endorsements number(12,2),
    claims number(12,2),
    net_income number(12,2)--,
    --loss_ratio number(15,8) -- calculate loss ratio when selecting
);

create or replace procedure rli.present.generate_customer_risk_tables()
  returns string
  language sql
  execute as caller
as
$$
begin

delete from rli.present.prs_customer_risk;
insert into rli.present.prs_customer_risk
select
    customer_id,
    customer_name,
    state,
    industry,
    policy_type,
    total_payments,
    total_endorsements,
    payments_endorsements,
    claims,
    net_income
from (
    select
        p.customer_id,
        c.customer_name,
        c.state,
        c.industry,
        p.policy_type,
        sum(t.total_payments) as total_payments,
        sum(t.total_endorsements) as total_endorsements,
        sum(t.total_pe) as payments_endorsements,
        sum(t.total_claims) as claims,
        sum(t.net_income) as net_income
    from rli.transform.trn_policies p
    join table(rli.present.policy_totals_all()) t
        on t.policy_id = p.policy_id
    join rli.transform.trn_customers c
        on c.customer_id = p.customer_id
    group by p.customer_id, c.customer_name, c.state, c.industry, p.policy_type
);
    return 'risk by customer calculated successfully';
end;
$$;


create or replace task rli.present.generate_customer_risk_tables_nightly
  warehouse = compute_wh
  schedule = 'using cron 15 3 * * * America/Chicago'
as
  call rli.present.generate_customer_risk_tables();


alter task rli.present.generate_customer_risk_tables_nightly resume;
