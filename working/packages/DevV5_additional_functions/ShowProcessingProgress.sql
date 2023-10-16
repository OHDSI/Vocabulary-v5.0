CREATE OR REPLACE FUNCTION devv5.ShowProcessingProgress (
	INOUT pProcessedCounter INT8,
	pTotalRows INT8,
	pNoticeKeyword TEXT,
	INOUT pProcessedPct INT2
)
RETURNS RECORD AS
$BODY$
	/*
	The function increments the row count and calculates the current progress percentage based on the total rows processed. Then it checks if the progress has reached or exceeded the next step of 10 percent. If it has, the function raises a notice message indicating the progress using the provided keyword.
	By using this function, you can easily monitor the progress of a process and receive notifications at regular intervals based on the percentage of completion.
	
	How to use:
	Declare two variables in you code:
	iProcessedCounter INT8:=0;
	iProcessedPct INT2:=0;
	In FOR...LOOP statement paste this code:
	SELECT * INTO iProcessedCounter,iProcessedPct FROM devv5.ShowProcessingProgress (iProcessedCounter, %total_rows%, %keword%, iProcessedPct);
	After the loop put this code:
	RAISE NOTICE '100%% of %keword% were processed';
	
	Replace %total_rows% and %keword% with your actual values
	
	Example:
	DO $$
	DECLARE 
		iProcessedCounter INT8:=0;
		iProcessedPct INT2:=0;
		iTotalRows INT8;
		iNoticeKeyword TEXT:='rows';
	BEGIN
		FOR iTotalRows IN (SELECT COUNT(*) OVER() FROM GENERATE_SERIES(1,15)) LOOP
			SELECT * INTO iProcessedCounter,iProcessedPct FROM devv5.ShowProcessingProgress (iProcessedCounter, iTotalRows, iNoticeKeyword, iProcessedPct);
		END LOOP;
		RAISE NOTICE '100%% of % were processed', iNoticeKeyword;
	END $$;
	*/
DECLARE
	iCurrentPct INT2;
BEGIN
	pProcessedCounter:=pProcessedCounter+1;
	iCurrentPct=(100*pProcessedCounter/pTotalRows);
	IF iCurrentPct>=10 AND iCurrentPct<100 AND iCurrentPct/10 > pProcessedPct/10 THEN
		pProcessedPct:=iCurrentPct;
		RAISE NOTICE '% of % were processed',pProcessedPct::TEXT||'%', pNoticeKeyword;
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' IMMUTABLE;
