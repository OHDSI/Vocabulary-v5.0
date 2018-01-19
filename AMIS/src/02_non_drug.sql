-- UPDATE SOURCE_TABLE SET ATC_CODE = regexp_replace(regexp_replace(IND, '\s.*'), '^"');

UPDATE SOURCE_TABLE SET ATC_CODE = regexp_replace(IND, '\s.*');

UPDATE SOURCE_TABLE SET DOMAIN_ID = 'Device' 
WHERE IND like 'B05AX03%' or IND like 'B05AX02%' 
or IND like 'B05AX01%' or IND like 'V09%' or IND like 'V08%' 
or IND like 'V04%' or IND like 'B05AX04%' or IND like 'B05ZB%'
or IND like '%B05AX %' or IND like '%D03AX32%' or IND like '%V03AX%'
or IND like 'V10%' or IND like 'V %' or ind like '%V03AN%';

UPDATE SOURCE_TABLE SET DOMAIN_ID = 'Drug' WHERE DOMAIN_ID is NULL;

