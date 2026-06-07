--drop table if exists rli.collect.col_endorsements;
create table if not exists rli.collect.col_endorsements (
    endorsement_id number,
    policy_id number,
    endorsement_type varchar,
    endorsement_date date,
    endorsement_amount number(8,2),
    loaded_at timestamp_ntz,
    record_source varchar
);

create or replace procedure rli.collect.collect_endorsements()
  returns string
  language sql
  execute as caller
as
$$
begin
merge into rli.collect.col_endorsements as tgt
using (
    with deduplicated as (
        select
            *,
            row_number() over (
                partition by variant_col:endorsement_id
                order by variant_col:endorsement_id desc
            ) as row_num
        from rli.ingest.raw_endorsements
    )
    select
        variant_col:endorsement_id as endorsement_id,
        variant_col:policy_id as policy_id,
        variant_col:endorsement_type as endorsement_type,
        variant_col:endorsement_date as endorsement_date,
        variant_col:endorsement_amount as endorsement_amount,
        current_timestamp() as loaded_at,
        'raw_endorsements' as record_source
    from deduplicated
    where row_num = 1
) as src
on
    tgt.endorsement_id = src.endorsement_id
    and tgt.policy_id = src.policy_id
    and tgt.endorsement_type = src.endorsement_type
    and tgt.endorsement_date = src.endorsement_date
    and tgt.endorsement_amount = src.endorsement_amount

when not matched then
    insert (
        endorsement_id,
        policy_id,
        endorsement_type,
        endorsement_date,
        endorsement_amount,
        loaded_at,
        record_source
    )
    values (
        src.endorsement_id,
        src.policy_id,
        src.endorsement_type,
        src.endorsement_date,
        src.endorsement_amount,
        src.loaded_at,
        src.record_source
    );
  return 'endorsements collected successfully';
end;
$$;

create or replace task rli.collect.collect_endorsements_nightly
  warehouse = compute_wh
  schedule = 'using cron 45 1 * * * America/Chicago'
as
  call rli.collect.collect_endorsements();


alter task rli.collect.collect_endorsements_nightly resume;



