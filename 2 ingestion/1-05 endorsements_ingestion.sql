-- create file format for endorsements json file
create or replace file format rli.ingest.endorsements_json_format
  type = 'json'
  strip_outer_array = true
  null_if = ('', 'NULL');


create stage if not exists rli.ingest.endorsements_file_stage
  file_format = rli.ingest.endorsements_json_format;
  

create or replace procedure rli.ingest.load_raw_endorsements()
  returns string
  language sql
  execute as caller
as
$$
begin
  delete from rli.ingest.raw_endorsements;
  copy into rli.ingest.raw_endorsements
    from @rli.ingest.endorsements_file_stage/endorsements.json
    file_format = (format_name = rli.ingest.endorsements_json_format)
    on_error = 'continue'
    force = true;
  return 'endorsements loaded successfully';
end;
$$;


create or replace task rli.ingest.load_endorsements_nightly
  warehouse = compute_wh
  schedule = 'using cron 20 1 * * * America/Chicago'
as
  call rli.ingest.load_raw_endorsements();


alter task rli.ingest.load_endorsements_nightly resume;