--drop table rli.transform.trn_claims;
create table if not exists rli.transform.trn_claims (
    claim_id number,
    policy_id number,
    claim_date date,
    claim_amount number(12,2),
    claim_status varchar,
    loaded_at timestamp_ntz
);

create or replace procedure rli.transform.transform_claims()
  returns string
  language sql
  execute as caller
as
$$
begin
merge into rli.transform.trn_claims as tgt
using (
    select
        c.claim_id,
        c.policy_id,
        c.claim_date,
        c.claim_amount,
        c.claim_status,
        c.loaded_at
    from rli.collect.col_claims c
    inner join rli.transform.trn_policies p
        on c.policy_id = p.policy_id
    where c.claim_amount > 0
    qualify row_number() over (partition by --c.claim_key,
        c.claim_id order by c.loaded_at desc) = 1
) as src
on tgt.claim_id = src.claim_id
when matched then
    update set
        tgt.policy_id = src.policy_id,
        tgt.claim_date = src.claim_date,
        tgt.claim_amount = src.claim_amount,
        tgt.claim_status = src.claim_status,
        tgt.loaded_at = src.loaded_at
when not matched then
    insert (
        claim_id,
        policy_id,
        claim_date,
        claim_amount,
        claim_status,
        loaded_at
    )
    values (
        src.claim_id,
        src.policy_id,
        src.claim_date,
        src.claim_amount,
        src.claim_status,
        src.loaded_at
    );

-------------------------------------
-- DOCUMENT ORPHANED DATA -----------
-------------------------------------
delete from rli.transform.cleaned_data
where table_name = 'trn_claims';

insert into rli.transform.cleaned_data (table_name, table_id, reason, action_taken)
select distinct
    'trn_claims',
    c.claim_id,
    'missing parent in rli.transform.trn_policies ' || c.policy_id,
    'record not transformed'
-- insert into rli.transform.orphaned_data (table_name, foreign_table, key_value)
-- select distinct
--     'trn_claims',
--     'trn_policies',
--     c.policy_id
from rli.collect.col_claims c
left join rli.transform.trn_policies p
    on p.policy_id = c.policy_id
where p.policy_id is null
  and c.policy_id is not null
  and not exists (
      -- select 1 from rli.transform.orphaned_data o
      -- where o.table_name = 'trn_claims'
      --   and o.foreign_table = 'trn_policies'
      --   and o.key_value = c.claim_id
        select 1 from rli.transform.cleaned_data o
        where o.table_name = 'trn_claims'
            and o.table_id = c.claim_id
            and o.reason = 'missing parent in rli.transform.trn_policies ' || c.policy_id
            and o.action_taken = 'record not transformed'
  );

return 'claims transformed successfully';

end;
$$;

create or replace task rli.transform.transform_claims_nightly
  warehouse = compute_wh
  schedule = 'using cron 0 2 * * * America/Chicago'
as
  call rli.transform.transform_claims();


alter task rli.transform.transform_claims_nightly resume;
