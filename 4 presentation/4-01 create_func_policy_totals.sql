create or replace function rli.present.policy_totals(startdate date, enddate date)
returns table (
    policy_id number,
    premium number(8,2),
    total_payments number(12,2),
    total_endorsements number(12,2),
    total_pe number(12,2), --sum of payments and adjustments
    total_claims number(12,2),
    net_income number(12,2)
)
as
$$
    select
        po.policy_id,
        po.premium,
        coalesce(pa.total_payments, 0) as total_payments,
        coalesce(en.total_endorsements, 0) as total_endorsements,
        coalesce(pa.total_payments, 0) + coalesce(en.total_endorsements, 0) as total_pe,
        coalesce(cl.total_claims, 0) as total_claims,
        coalesce(pa.total_payments, 0) - coalesce(cl.total_claims, 0) + coalesce(en.total_endorsements, 0) as net_income
    from rli.transform.trn_policies po
    left join (
        select policy_id, sum(payment_amount) as total_payments
        from rli.transform.trn_payments
        where (startdate is null or payment_date >= startdate)
          and (enddate is null or payment_date <= enddate)
        group by policy_id
    ) pa on pa.policy_id = po.policy_id
    left join (
        select policy_id, sum(claim_amount) as total_claims
        from rli.transform.trn_claims
        where (startdate is null or claim_date >= startdate)
          and (enddate is null or claim_date <= enddate)
        group by policy_id
    ) cl on cl.policy_id = po.policy_id
    left join (
        select policy_id, sum(endorsement_amount) as total_endorsements
        from rli.transform.trn_endorsements
        where (startdate is null or endorsement_date >= startdate)
          and (enddate is null or endorsement_date <= enddate)
        group by policy_id
    ) en on en.policy_id = po.policy_id
$$;

create or replace function rli.present.policy_totals_all()
returns table (
    policy_id number,
    premium number(8,2),
    total_payments number(12,2),
    total_endorsements number(12,2),
    total_pe number(12,2),
    total_claims number(12,2),
    net_income number(12,2)
)
as
$$
    select * from table(rli.present.policy_totals(null::date, null::date))
$$;
