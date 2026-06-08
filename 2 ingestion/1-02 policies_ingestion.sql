-- create file format for policies csv file
create file format if not exists rli.ingest.policies_csv_format
  type = 'csv'
  field_optionally_enclosed_by = '"'
  skip_header = 1
  null_if = ('', 'NULL');


create stage if not exists rli.ingest.policies_file_stage
  file_format = rli.ingest.policies_csv_format;

create table if not exists rli.ingest.raw_policies (
  policy_id number,
  customer_id number,
  policy_type varchar,
  effective_date date,
  expiration_date date,
  premium number(8,2)
);

create or replace procedure rli.ingest.load_raw_policies()
  returns string
  language sql
  execute as caller
as
$$
begin
  delete from rli.ingest.raw_policies;
  copy into rli.ingest.raw_policies
    from @rli.ingest.policies_file_stage/policies.csv
    file_format = (format_name = rli.ingest.policies_csv_format)
    on_error = 'continue'
    force = true;
  return 'policies loaded successfully';
end;
$$;


create or replace task rli.ingest.load_policies_nightly
  warehouse = compute_wh
  schedule = 'using cron 5 1 * * * America/Chicago'
as
  call rli.ingest.load_raw_policies();


alter task rli.ingest.load_policies_nightly resume;