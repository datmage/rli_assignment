--drop table rli.collect.col_payments;
create table if not exists rli.collect.col_payments (
    --payment_key varchar,
    payment_id number,
    policy_id number,
    payment_date date,
    payment_amount number(8,2),
    loaded_at timestamp_ntz,
    record_source varchar
);

create or replace procedure rli.collect.collect_payments()
  returns string
  language sql
  execute as caller
as
$$
begin
merge into rli.collect.col_payments as tgt
using (
    with deduplicated as (
        select
            *,
            row_number() over (
                partition by payment_id
                order by payment_id desc
            ) as row_num
        from rli.ingest.raw_payments
    )
    select
        payment_id,
        policy_id,
        payment_date,
        payment_amount,
        current_timestamp() as loaded_at,
        'raw_payments' as record_source
    from deduplicated
    where row_num = 1
) as src
on
    tgt.payment_id = src.payment_id
    and tgt.policy_id = src.policy_id
    and tgt.payment_date = src.payment_date
    and tgt.payment_amount = src.payment_amount
when not matched then
    insert (
        payment_id,
        policy_id,
        payment_date,
        payment_amount,
        loaded_at,
        record_source
    )
    values (
        src.payment_id,
        src.policy_id,
        src.payment_date,
        src.payment_amount,
        src.loaded_at,
        src.record_source
    );
  return 'payments collected successfully';
end;
$$;


create or replace task rli.collect.collect_payments_nightly
  warehouse = compute_wh
  schedule = 'using cron 40 1 * * * America/Chicago'
as
  call rli.collect.collect_payments();


alter task rli.collect.collect_payments_nightly resume;
