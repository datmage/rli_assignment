--select * from rli.collect.col_endorsements;
--drop table rli.transform.trn_endorsements;
--delete from rli.transform.trn_endorsements;
create table if not exists rli.transform.trn_endorsements (
    endorsement_id number,
    policy_id number,
    endorsement_type varchar,
    endorsement_date date,
    endorsement_amount numeric(8,2),
    loaded_at timestamp_ntz
);

create or replace procedure rli.transform.transform_endorsements()
  returns string
  language sql
  execute as caller
as
$$
begin
merge into rli.transform.trn_endorsements as tgt
using (
    select
        e.endorsement_id,
        e.policy_id,
        e.endorsement_type,
        e.endorsement_date,
        e.endorsement_amount,
        e.loaded_at
    from rli.collect.col_endorsements e
    inner join rli.transform.trn_policies p
        on e.policy_id = p.policy_id
    qualify row_number() over (partition by --e.endorsement_key, 
        e.endorsement_id order by e.loaded_at desc) = 1
) as src
on tgt.endorsement_id = src.endorsement_id
when matched then
    update set
        tgt.endorsement_id = src.endorsement_id,
        tgt.policy_id = src.policy_id,
        tgt.endorsement_type = src.endorsement_type,
        tgt.endorsement_date = src.endorsement_date,
        tgt.endorsement_amount = src.endorsement_amount,
        tgt.loaded_at = src.loaded_at
when not matched then
    insert (
        endorsement_id,
        policy_id,
        endorsement_type,
        endorsement_date,
        endorsement_amount,
        loaded_at
    )
    values (
        src.endorsement_id,
        src.policy_id,
        src.endorsement_type,
        src.endorsement_date,
        src.endorsement_amount,
        src.loaded_at
    );

-------------------------------------
-- DOCUMENT ORPHANED DATA -----------
-------------------------------------
delete from rli.transform.orphaned_data
where table_name = 'trn_endorsements';

insert into rli.transform.orphaned_data (table_name, foreign_table, key_value)
select distinct
    'trn_endorsements',
    'trn_policies',
    e.policy_id
from rli.collect.col_endorsements e
left join rli.collect.col_policies p
    on p.policy_id = e.policy_id
where p.policy_id is null
  and e.policy_id is not null
  and not exists (
      select 1 from rli.transform.orphaned_data o
      where o.table_name = 'trn_endorsements'
        and o.foreign_table = 'trn_policies'
        and o.key_value = e.policy_id
  );

    return 'endorsements transformed successfully';
end;
$$;


create or replace task rli.transform.transform_endorsements_nightly
  warehouse = compute_wh
  schedule = 'using cron 10 2 * * * America/Chicago'
as
  call rli.transform.transform_endorsements();


alter task rli.transform.transform_endorsements_nightly resume;
