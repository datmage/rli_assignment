-------------------------------------------------------------------------
-- QUESTION -------------------------------------------------------------
-- Which policy types are generating the highest loss ratios?
-------------------------------------------------------------------------
-- METHODOLOGY ----------------------------------------------------------
-- Select loss ratio by policy type
-- Additionally, select loss ratio by policy type and yearmonth
-------------------------------------------------------------------------
create table if not exists rli.present.prs_loss_ratio_by_policy_type(
    policy_type varchar,
    type_total_payments number(12,2),
    type_total_endorsements number(12,2),
    type_payments_endorsements number(12,2),
    closed_claims number(12,2),
    open_claims number(12,2),
    pending_claims number(12,2),
    type_claims number(12,2),
    net_income number(12,2),
    loss_ratio number(15,8)
);

create or replace procedure rli.present.generate_loss_ratio_by_policy_type()
  returns string
  language sql
  execute as caller
as
$$
begin
-------------------------------------
-- GENERATE LOSS RATIOS -------------
-------------------------------------
delete from rli.present.prs_loss_ratio_by_policy_type;

insert into rli.present.prs_loss_ratio_by_policy_type
select
    policy_type,
    type_total_payments,
    type_total_endorsements,
    type_payments_endorsements,
    closed_claims,
    open_claims,
    pending_claims,
    type_claims,
    net_income,
    --case when type_payments_endorsements > 0 then type_claims / type_payments_endorsements else null end as loss_ratio
    rli.present.loss_ratio(
        type_total_payments,
        type_total_endorsements,
        closed_claims,
        open_claims,
        pending_claims
    ) as loss_ratio
from (
    select
        s.policy_type,
        sum(s.total_payments) as type_total_payments,
        sum(s.total_endorsements) as type_total_endorsements,
        sum(s.total_pe) as type_payments_endorsements,
        sum(s.closed_claims) as closed_claims,
        sum(s.open_claims) as open_claims,
        sum(s.pending_claims) as pending_claims,
        sum(s.total_claims) as type_claims,
        sum(s.net_income) as net_income
    from (
        select *
        from rli.transform.trn_policies p
        ----------------------------------------------------
        -- this function call can be sent a start and end
        -- date to narrow down the data set
        -- I may create a data set of policy totals
        -- by month in addition to this data set
        ----------------------------------------------------
        join table(rli.present.policy_totals_all()) t
        ----------------------------------------------------
        ----------------------------------------------------
            on t.policy_id = p.policy_id
    ) s
    group by s.policy_type
);
    return 'loss ratios calculated successfully';
end;
$$;


create or replace task rli.present.generate_loss_ratio_by_policy_nightly
  warehouse = compute_wh
  schedule = 'using cron 0 3 * * * America/Chicago'
as
  call rli.present.generate_loss_ratio_by_policy_type();


alter task rli.present.generate_loss_ratio_by_policy_nightly resume;

--drop table rli.present.prs_loss_ratio_by_policy_type_yearmonth;
create table if not exists rli.present.prs_loss_ratio_by_policy_type_yearmonth(
    yearmonth number,
    policy_type varchar,
    type_total_payments number(12,2),
    type_total_endorsements number(12,2),
    type_payments_endorsements number(12,2),
    closed_claims number(12,2),
    open_claims number(12,2),
    pending_claims number(12,2),
    type_claims number(12,2),
    net_income number(12,2),
    loss_ratio number(15,8)
);


create or replace procedure rli.present.generate_loss_ratio_by_policy_type_yearmonth()
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
delete from rli.present.prs_loss_ratio_by_policy_type_yearmonth;

current_date_iter := (select date_trunc('month', min(payment_date)) from rli.transform.trn_payments);

while (current_date_iter <= current_date()) do
    current_month := month(current_date_iter);
    current_year := year(current_date_iter);
    month_start := current_date_iter;
    month_end := dateadd('day', -1, dateadd('month', 1, current_date_iter));

    insert into rli.present.prs_loss_ratio_by_policy_type_yearmonth
    select
        :current_year * 100 + :current_month as yearmonth,
        policy_type,
        type_total_payments,
        type_total_endorsements,
        type_payments_endorsements,
        closed_claims,
        open_claims,
        pending_claims,
        type_claims,
        net_income,
        --case when type_payments_endorsements > 0 then type_claims / type_payments_endorsements else null end as loss_ratio
        rli.present.loss_ratio(
            type_total_payments,
            type_total_endorsements,
            closed_claims,
            open_claims,
            pending_claims
        ) as loss_ratio
    from (
        select
            s.policy_type,
            sum(s.total_payments) as type_total_payments,
            sum(s.total_endorsements) as type_total_endorsements,
            sum(s.total_pe) as type_payments_endorsements,
            sum(s.closed_claims) as closed_claims,
            sum(s.open_claims) as open_claims,
            sum(s.pending_claims) as pending_claims,
            sum(s.total_claims) as type_claims,
            sum(s.net_income) as net_income
        from (
            select *
            from rli.transform.trn_policies p
            join table(rli.present.policy_totals(:month_start, :month_end)) t
                on t.policy_id = p.policy_id
        ) s
        group by s.policy_type
    );

    current_date_iter := dateadd('month', 1, current_date_iter);
end while;

    return 'loss ratios by yearmonth calculated successfully';
end;
$$;


create or replace task rli.present.generate_loss_ratio_by_policy_yearmonth_nightly
  warehouse = compute_wh
  schedule = 'using cron 5 3 * * * America/Chicago'
as
  call rli.present.generate_loss_ratio_by_policy_type_yearmonth();


alter task rli.present.generate_loss_ratio_by_policy_yearmonth_nightly resume;



