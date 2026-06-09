--select * from rli.collect.col_policies;
--drop table rli.transform.trn_policies;
create table if not exists rli.transform.trn_policies (
    policy_id number,
    customer_id number,
    policy_type varchar,
    effective_date date,
    expiration_date date,
    premium number(8,2),
    loaded_at timestamp_ntz
);

create or replace procedure rli.transform.transform_policies()
  returns string
  language sql
  execute as caller
as
$$
begin
-------------------------------------
-- TRANSFORM POLICIES ---------------
-------------------------------------
merge into rli.transform.trn_policies as tgt
using (
    select
        p.policy_id,
        p.customer_id,
        p.policy_type,
        p.effective_date,
        p.expiration_date,
        p.premium,
        p.loaded_at
    from rli.collect.col_policies p
    inner join rli.transform.trn_customers c
        on c.customer_id = p.customer_id
    --------------------------------------------------------
    -- I've decided to not eliminate rows where the dates
    -- are potentially incorrect, and simply note it in the
    -- cleaned_data table JS 2026-06-06
    --------------------------------------------------------
    --where --p.premium is not null
        --and 
        --p.expiration_date >= p.effective_date
    --------------------------------------------------------
    qualify row_number() over (partition by 
        p.policy_id order by p.loaded_at desc) = 1
) as src
on tgt.policy_id = src.policy_id
when matched then
    update set
        tgt.policy_id = src.policy_id,
        tgt.customer_id = src.customer_id,
        tgt.policy_type = src.policy_type,
        tgt.effective_date = src.effective_date,
        tgt.expiration_date = src.expiration_date,
        tgt.premium = src.premium,
        tgt.loaded_at = src.loaded_at
when not matched then
    insert (
        policy_id,
        customer_id,
        policy_type,
        effective_date,
        expiration_date,
        premium,
        loaded_at)
    values (
        policy_id,
        customer_id,
        policy_type,
        effective_date,
        expiration_date,
        premium,
        loaded_at);

-------------------------------------
-- DOCUMENT CLEANED DATA ------------
-------------------------------------
delete from rli.transform.cleaned_data
where table_name = 'trn_policies';

insert into rli.transform.cleaned_data (table_name, table_id, reason, action_taken)
select distinct
    'trn_policies',
    p.policy_id,
    'expiration_date before effective_date',
    'transform data and alert'
from rli.collect.col_policies p
where p.expiration_date < p.effective_date
  and not exists (
      select 1 from rli.transform.cleaned_data c
      where c.table_name = 'trn_policies'
        and c.table_id = p.policy_id
        and c.reason = 'expiration_date before effective_date'
  );

-------------------------------------
-- DOCUMENT ORPHANED DATA -----------
-------------------------------------
--delete from rli.transform.orphaned_data
-- where table_name = 'trn_policies';

insert into rli.transform.cleaned_data (table_name, table_id, reason, action_taken)
select distinct
    'trn_policies',
    --'trn_customers',
    p.policy_id,
    'missing parent in rli.transform.trn_customers ' || p.customer_id,
    'record not transformed'
from rli.collect.col_policies p
left join rli.transform.trn_customers c
    on c.customer_id = p.customer_id
where c.customer_id is null
  and p.customer_id is not null
  and not exists (
      -- select 1 from rli.transform.cleaned_data o
      -- where o.table_name = 'trn_policies'
      --   and o.key_value = p.policy_id
      --   and o.key_value = p.customer_id
        select 1 from rli.transform.cleaned_data o
        where o.table_name = 'trn_policies'
            and o.table_id = p.policy_id
            and o.reason = 'missing parent in rli.transform.trn_customers ' || p.customer_id
            and o.action_taken = 'record not transformed'
  );

    return 'policies transformed successfully';
end;
$$;


create or replace task rli.transform.transform_policies_nightly
  warehouse = compute_wh
  schedule = 'using cron 55 1 * * * America/Chicago'
as
  call rli.transform.transform_policies();


alter task rli.transform.transform_policies_nightly resume;