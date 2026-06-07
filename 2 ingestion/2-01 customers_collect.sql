--update rli.ingest.raw_customers set customer_name = 'Hooges Group' where customer_id = 1;
--drop table rli.collect.col_customers;
create table if not exists rli.collect.col_customers (
    customer_id number,
    customer_name varchar,
    state char(2),
    industry varchar,
    loaded_at timestamp_ntz,
    record_source varchar
);

create or replace procedure rli.collect.collect_customers()
  returns string
  language sql
  execute as caller
as
$$
begin
merge into rli.collect.col_customers as tgt
using (
    with deduplicated as (
        select
            *,
            row_number() over (
                partition by customer_id
                order by customer_id desc
            ) as row_num
        from rli.ingest.raw_customers
    )
    select
        customer_id,
        customer_name,
        state,
        industry,
        current_timestamp() as loaded_at,
        'raw_customers' as record_source
    from deduplicated
    where row_num = 1
) as src
on
    tgt.customer_id = src.customer_id
    and tgt.customer_name = src.customer_name
    and tgt.state = src.state
    and tgt.industry = src.industry
when not matched then
    insert (
        customer_id,
        customer_name,
        state,
        industry,
        loaded_at,
        record_source
    )
    values (
        src.customer_id,
        src.customer_name,
        src.state,
        src.industry,
        src.loaded_at,
        src.record_source
    );
    return 'customers collected successfully';
end;
$$;

create or replace task rli.collect.collect_customers_nightly
  warehouse = compute_wh
  schedule = 'using cron 25 1 * * * America/Chicago'
as
  call rli.collect.collect_customers();


alter task rli.collect.collect_customers_nightly resume;