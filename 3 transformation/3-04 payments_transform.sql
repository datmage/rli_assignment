--select * from rli.collect.col_payments;
--drop table rli.transform.trn_payments;
--delete from rli.transform.trn_payments;
create table if not exists rli.transform.trn_payments (
    payment_id number,
    policy_id number,
    payment_date date,
    payment_amount number(8,2),
    loaded_at timestamp_ntz
);

create or replace procedure rli.transform.transform_payments()
  returns string
  language sql
  execute as caller
as
$$
begin
merge into rli.transform.trn_payments as tgt
using (
    select
        a.payment_id,
        a.policy_id,
        a.payment_date,
        a.payment_amount,
        a.loaded_at
    from rli.collect.col_payments a
    inner join rli.transform.trn_policies o
        on o.policy_id = a.policy_id
    where a.payment_amount > 0
    qualify row_number() over (partition by
        a.payment_id order by a.loaded_at desc) = 1
) as src
on tgt.payment_id = src.payment_id
when matched then
    update set
        tgt.payment_id = src.payment_id,
        tgt.policy_id = src.policy_id,
        tgt.payment_date = src.payment_date,
        tgt.payment_amount = src.payment_amount,
        tgt.loaded_at = src.loaded_at
when not matched then
    insert (
        payment_id,
        policy_id,
        payment_date,
        payment_amount,
        loaded_at)
    values (
        src.payment_id,
        src.policy_id,
        src.payment_date,
        src.payment_amount,
        src.loaded_at);

-------------------------------------
-- DOCUMENT CLEANED DATA ------------
-------------------------------------
delete from rli.transform.cleaned_data
where table_name = 'trn_payments';

insert into rli.transform.cleaned_data (table_name, table_id, reason, action_taken)
select distinct
    'trn_payments',
    a.payment_id,
    'negative or zero value',
    'remove from transform and alert'
from rli.collect.col_payments a
where a.payment_amount <= 0
  and not exists (
      select 1 from rli.transform.cleaned_data c
      where c.table_name = 'trn_payments'
        and c.table_id = a.payment_id
        and c.reason = 'negative value'
  );

-------------------------------------
-- DOCUMENT ORPHANED DATA -----------
-------------------------------------
--delete from rli.transform.orphaned_data
--where table_name = 'trn_payments';

insert into rli.transform.cleaned_data (table_name, table_id, reason, action_taken)
select distinct
    'trn_payments',
    a.payment_id,
    'missing parent in rli.transform.trn_policies ' || a.policy_id,
    'record not transformed'
-- insert into rli.transform.orphaned_data (table_name, foreign_table, key_value)
-- select distinct
--     'trn_payments',
--     'trn_policies',
--     a.policy_id
from rli.collect.col_payments a
left join rli.transform.trn_policies p
    on p.policy_id = a.policy_id
where p.policy_id is null
  and a.policy_id is not null
  and not exists (
      -- select 1 from rli.transform.orphaned_data o
      -- where o.table_name = 'trn_payments'
      --   and o.foreign_table = 'trn_policies'
      --   and o.key_value = a.policy_id
        select 1 from rli.transform.cleaned_data o
        where o.table_name = 'trn_payments'
            and o.table_id = a.payment_id
            and o.reason = 'missing parent in rli.transform.trn_policies ' || a.policy_id
            and o.action_taken = 'record not transformed'
  );

    return 'payments transformed successfully';
end;
$$;


create or replace task rli.transform.transform_payments_nightly
  warehouse = compute_wh
  schedule = 'using cron 5 2 * * * America/Chicago'
as
  call rli.transform.transform_payments();


alter task rli.transform.transform_payments_nightly resume;