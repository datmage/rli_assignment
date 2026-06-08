-- create file format for customers csv file
create file format if not exists rli.ingest.customers_csv_format
  type = 'csv'
  field_optionally_enclosed_by = '"'
  skip_header = 1
  null_if = ('', 'NULL');
  
  
create stage if not exists rli.ingest.customers_file_stage
  file_format = rli.ingest.customers_csv_format;

create table if not exists rli.ingest.raw_customers (
  customer_id number,
  customer_name varchar,
  state varchar(2),
  industry varchar
);
  
create or replace procedure rli.ingest.load_raw_customers()
  returns string
  language sql
  execute as caller
as
$$
begin
  delete from rli.ingest.raw_customers;
  copy into rli.ingest.raw_customers
    from @rli.ingest.customers_file_stage/customers.csv
    file_format = (format_name = rli.ingest.customers_csv_format)
    on_error = 'continue'
    force = true;
  return 'customers loaded successfully';
end;
$$;


create or replace task rli.ingest.load_customers_nightly
  warehouse = compute_wh
  schedule = 'using cron 0 1 * * * America/Chicago'
as
  call rli.ingest.load_raw_customers();


alter task rli.ingest.load_customers_nightly resume;