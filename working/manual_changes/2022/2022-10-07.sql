--Update  of CGI needed to set correct valid_end_dates
UPDATE concept c
SET  valid_end_date=current_date
WHERE c.invalid_reason ='D'
and c.vocabulary_id='CGI'
and c.valid_end_date<c.valid_start_date
;

