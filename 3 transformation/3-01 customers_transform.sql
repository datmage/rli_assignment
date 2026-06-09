--drop table rli.transform.trn_customers;
create table if not exists rli.transform.trn_customers (
    customer_id number,
    customer_name varchar,
    state char(2),
    industry varchar,
    loaded_at timestamp_ntz
);
--drop table rli.transform.cleaned_data;
create table if not exists rli.transform.cleaned_data (
    table_name varchar,
    table_id number,
    reason varchar,
    action_taken varchar
);
-- create table if not exists rli.transform.orphaned_data (
--     table_name varchar,
--     foreign_table varchar,
--     key_value number
-- );

create or replace procedure rli.transform.transform_customers()
  returns string
  language sql
  execute as caller
as
$$
begin
-------------------------------------
-- TRANSFORM CUSTOMERS --------------
-------------------------------------
merge into rli.transform.trn_customers as tgt
using (
    select
        customer_id,
        customer_name,
        state,
        industry,
        loaded_at
    from rli.collect.col_customers
    qualify row_number() over (partition by --customer_key, 
        customer_id order by loaded_at desc) = 1
) as src
on tgt.customer_id = src.customer_id
when matched then
    update set
        tgt.customer_id = src.customer_id,
        tgt.customer_name = src.customer_name,
        tgt.state = src.state,
        tgt.industry = src.industry,
        tgt.loaded_at = src.loaded_at
when not matched then
    insert (
        customer_id,
        customer_name,
        state,
        industry,
        loaded_at)
    values (
        src.customer_id,
        src.customer_name,
        src.state,
        src.industry,
        src.loaded_at);
    return 'customers transformed successfully';
end;
$$;


create or replace task rli.transform.transform_customers_nightly
  warehouse = compute_wh
  schedule = 'using cron 50 1 * * * America/Chicago'
as
  call rli.transform.transform_customers();


alter task rli.transform.transform_customers_nightly resume;
