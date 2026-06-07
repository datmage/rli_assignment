-- create file format for payments csv file
create file format if not exists rli.ingest.payments_csv_format
  type = 'csv'
  field_optionally_enclosed_by = '"'
  skip_header = 1
  null_if = ('', 'NULL');


create stage if not exists rli.ingest.payments_file_stage
  file_format = rli.ingest.payments_csv_format;


create or replace procedure rli.ingest.load_raw_payments()
  returns string
  language sql
  execute as caller
as
$$
begin
  delete from rli.ingest.raw_payments;
  copy into rli.ingest.raw_payments
    from @rli.ingest.payments_file_stage/payments.csv
    file_format = (format_name = rli.ingest.payments_csv_format)
    on_error = 'continue'
    force = true;
  return 'payments loaded successfully';
end;
$$;


create or replace task rli.ingest.load_payments_nightly
  warehouse = compute_wh
  schedule = 'using cron 15 1 * * * America/Chicago'
as
  call rli.ingest.load_raw_payments();


alter task rli.ingest.load_payments_nightly resume;