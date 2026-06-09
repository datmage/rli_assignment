--drop table rli.collect.col_policies;
create table if not exists rli.collect.col_policies (
    policy_id number,
    customer_id number,
    policy_type varchar,
    effective_date date,
    expiration_date date,
    premium number(8,2),
    loaded_at timestamp_ntz,
    record_source varchar
);


create or replace procedure rli.collect.collect_policies()
  returns string
  language sql
  execute as caller
as
$$
begin
merge into rli.collect.col_policies as tgt
using (
    with deduplicated as (
        select
            *,
            row_number() over (
                partition by policy_id
                order by policy_id desc
            ) as row_num
        from rli.ingest.raw_policies
    )
    select
        policy_id,
        customer_id,
        policy_type,
        effective_date,
        expiration_date,
        premium,
        current_timestamp() as loaded_at,
        'raw_policies' as record_source
    from deduplicated
    where row_num = 1
) as src
on
    tgt.policy_id = src.policy_id
    and tgt.customer_id = src.customer_id
    and tgt.policy_type = src.policy_type
    and tgt.effective_date = src.effective_date
    and tgt.expiration_date = src.expiration_date
    and tgt.premium = src.premium
when not matched then
    insert (
        policy_id,
        customer_id,
        policy_type,
        effective_date,
        expiration_date,
        premium,
        loaded_at,
        record_source
    )
    values (
        src.policy_id,
        src.customer_id,
        src.policy_type,
        src.effective_date,
        src.expiration_date,
        src.premium,
        src.loaded_at,
        src.record_source
    );
  return 'policies collected successfully';
end;
$$;


create or replace task rli.collect.collect_policies_nightly
  warehouse = compute_wh
  schedule = 'using cron 30 1 * * * America/Chicago'
as
  call rli.collect.collect_policies();


alter task rli.collect.collect_policies_nightly resume;
