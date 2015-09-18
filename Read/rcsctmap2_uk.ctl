OPTIONS (direct=true, errors=0, skip=1)
LOAD DATA
INFILE rcsctmap2_uk.txt
INTO TABLE rcsctmap2_uk
TRUNCATE
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
