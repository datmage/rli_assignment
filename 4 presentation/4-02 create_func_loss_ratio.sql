create or replace function rli.present.loss_ratio(
    payments number(12,2),
    endorsements number(12,2),
    closed_claims number(12,2),
    open_claims number(12,2),
    pending_claims number(12,2)
)
returns number(12,8)
language sql
as
$$
    case
        when payments + endorsements <> 0
        then (closed_claims + open_claims + pending_claims) / (payments + endorsements)
        else null
    end
$$;
