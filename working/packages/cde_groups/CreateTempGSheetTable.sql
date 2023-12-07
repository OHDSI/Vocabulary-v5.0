CREATE OR REPLACE PROCEDURE cde_groups.CreateTempGSheetTable (pSpreadsheetID TEXT, pWorksheetName TEXT) AS
$BODY$
/*
	Internal function that creates a temporary table with the specified spreadsheet
*/
BEGIN
	CREATE TEMP TABLE cde_spread_sheet ON COMMIT DROP AS
		SELECT cde_groups.ClearString(source_code) source_code,
			cde_groups.ClearString(source_code_description) source_code_description,
			cde_groups.ClearString(source_vocabulary_id) source_vocabulary_id,
			cde_groups.ClearString(group_name) group_name,
			cde_groups.ClearString(group_id)::INT4 group_id,
			--remove any non-ascii chars including TAB, CR etc, split to array by comma and aggregate the cleaned rows back into an array
			ARRAY(SELECT * FROM (SELECT NULLIF(TRIM(UNNEST(STRING_TO_ARRAY(TRIM('{},:' FROM cde_groups.ClearString(group_code)),',') )),'') grp) s0 WHERE s0.grp IS NOT NULL) group_code,
			cde_groups.ClearString(target_concept_id)::INT4 target_concept_id
		FROM google_pack.GetSpreadSheetByID(pSpreadsheetID, pWorksheetName) AS (
				source_code TEXT,
				source_code_description TEXT,
				source_vocabulary_id TEXT,
				group_name TEXT,
				group_id TEXT,
				group_code TEXT,
				target_concept_id TEXT
			);

	ANALYZE cde_spread_sheet;
END;
$BODY$
LANGUAGE 'plpgsql';