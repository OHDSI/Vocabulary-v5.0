LOAD DATA
INFILE Keyv2.all
INTO TABLE KEYV2
REPLACE
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  termclass,
  classnumber,
  description_short,
  description,
  description_long,
  termcode,
  lang,
  readcode,
  digit
)
