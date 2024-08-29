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
---- функция должна быть как в dev_atc с правками на проблему с дубликатами, но сорсовая таблица
---- приходит уже из sources.class_to_drug
DO $_$
BEGIN
	PERFORM dev_atc.pConceptAncestor();
END $_$;