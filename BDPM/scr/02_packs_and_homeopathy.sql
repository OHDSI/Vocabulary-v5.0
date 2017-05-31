--create table with homeopathic drugs as they will be proceeded in different way
create table homeop_drug as 
(
select a.* from ingredient a join drug b on a.drug_code=b.drug_code where ingredient like '%HOMÉOPA%' or drug_descr like '%degré de dilution compris entre%'
);


