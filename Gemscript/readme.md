1.need to describe how we get a the source_tables
2. make proper ctl-files.
3. 
plan for 05/12/
Dose Form
Add those short forms update
update gemscr_3 set 
GENERIC_NAME = regexp_replace (GENERIC_NAME, 'pes$','pessary' )
;
try the same algorith I used for Ingredients
;

 
manual_in_co_dose.txt is used for such "Co-amilozide 5mg/50mg tablets" dosaging parsing