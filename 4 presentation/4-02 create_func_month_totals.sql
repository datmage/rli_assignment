create or replace procedure rli.present.month_totals(start_date date, end_date date)
  returns table (
    year_month number,
    total_payments number(12,2),
    total_endorsements number(12,2),
    total_pe number(12,2),
    total_claims number(12,2),
    net_income number(12,2))
  language sql
  execute as caller
as
$$
declare
    current_date_iter date;
    current_month number;
    current_year number;
    res resultset;
begin
    create or replace temporary table rli.present.tmp_month_totals (
        year_month number,
        total_payments number(12,2),
        total_endorsements number(12,2),
        total_pe number(12,2),
        total_claims number(12,2),
        net_income number(12,2)
    );

    current_date_iter := date_trunc('month', :start_date);

    while (current_date_iter <= :end_date) do
        current_month := month(current_date_iter);
        current_year := year(current_date_iter);

        insert into rli.present.tmp_month_totals
        select :current_year * 100 + :current_month, *
        from table(rli.present.month_totals(:current_month, :current_year));

        current_date_iter := dateadd('month', 1, current_date_iter);
    end while;

    res := (select * from rli.present.tmp_month_totals where net_income <> 0 order by year_month);
    return table(res);
end;
$$;