/*
AVOF-1346
NDFRT, VA Product, VA Class are now retired
see more at https://www.nlm.nih.gov/pubs/techbull/ja18/brief/ja18_ndfrt_removed_rxnorm.html
*/

update concept set standard_concept=null where vocabulary_id in ('NDFRT', 'VA Product', 'VA Class') and standard_concept is not null;
update vocabulary_conversion set click_default=null where vocabulary_id_v5 in ('NDFRT', 'VA Product', 'VA Class') and click_default is not null;