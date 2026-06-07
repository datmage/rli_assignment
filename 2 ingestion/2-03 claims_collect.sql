create table if not exists rli.collect.col_claims (
    claim_id number,
    policy_id number,
    claim_date date,
    claim_amount number(12,2),
    claim_status varchar,
    loaded_at timestamp_ntz,
    record_source varchar
);


create or replace procedure rli.collect.collect_claims()
  returns string
  language sql
  execute as caller
as
$$
begin
merge into rli.collect.col_claims as tgt
using (
    with deduplicated as (
        select
            *,
            row_number() over (
                partition by claim_id, policy_id
                order by claim_date desc
            ) as row_num
        from rli.ingest.raw_claims
--        where
--            policy_id <> 999999
    )
    select
        claim_id,
        policy_id,
        claim_date,
        claim_amount,
        upper(trim(claim_status)) as claim_status,
        current_timestamp() as loaded_at,
        'raw_claims' as record_source
    from deduplicated
    where row_num = 1
) as src
on tgt.claim_id = src.claim_id
    and tgt.policy_id = src.policy_id
    and tgt.claim_date = src.claim_date
    and tgt.claim_amount = src.claim_amount
    and tgt.claim_status = src.claim_status
when not matched then
    insert (
        claim_id,
        policy_id,
        claim_date,
        claim_amount,
        claim_status,
        loaded_at,
        record_source
    )
    values (
        src.claim_id,
        src.policy_id,
        src.claim_date,
        src.claim_amount,
        src.claim_status,
        src.loaded_at,
        src.record_source
    );
  return 'claims collected successfully';
end;
$$;


create or replace task rli.collect.collect_claims_nightly
  warehouse = compute_wh
  schedule = 'using cron 35 1 * * * America/Chicago'
as
  call rli.collect.collect_claims();


alter task rli.collect.collect_claims_nightly resume;



