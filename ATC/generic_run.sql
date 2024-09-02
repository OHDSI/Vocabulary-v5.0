--- 1. Step
load_stage.sql

---- 2. Step
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;

--- 3. Step
class_to_drug.sql

---- 4. Step
DO $_$
BEGIN
	PERFORM dev_atc.pConceptAncestor();
END $_$;