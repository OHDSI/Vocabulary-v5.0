OPTIONS (SKIP=1)
LOAD DATA
INFILE rcsctmap2_uk_20141001000001.txt
INTO TABLE rcsctmap2_uk
REPLACE
FIELDS TERMINATED BY '\t'
TRAILING NULLCOLS
(
MapId,
ReadCode,
TermCode,
ConceptId,
DescriptionId,
IS_ASSURED,
EffectiveDate date 'YYYY.MM.DD',
MapStatus
)
