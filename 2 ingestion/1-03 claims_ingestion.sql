-- create file format for claims csv file
create file format if not exists rli.ingest.claims_csv_format
  type = 'csv'
  field_optionally_enclosed_by = '"'
  skip_header = 1
  null_if = ('', 'NULL');
  
  
create stage if not exists rli.ingest.claims_file_stage
  file_format = rli.ingest.claims_csv_format;


create or replace procedure rli.ingest.load_raw_claims()
  returns string
  language sql
  execute as caller
as
$$
begin
  delete from rli.ingest.raw_claims;
  copy into rli.ingest.raw_claims
    from @rli.ingest.claims_file_stage/claims.csv
    file_format = (format_name = rli.ingest.claims_csv_format)
    on_error = 'continue'
    force = true;
  return 'claims loaded successfully';
end;
$$;


create or replace task rli.ingest.load_claims_nightly
  warehouse = compute_wh
  schedule = 'using cron 10 1 * * * America/Chicago'
as
  call rli.ingest.load_raw_claims();


alter task rli.ingest.load_claims_nightly resume;