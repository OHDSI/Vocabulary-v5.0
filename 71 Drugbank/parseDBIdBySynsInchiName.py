'''
Created 09/04/2014

@authors: Yifan Ning and Rich Boyce

@summary: parse drug synonymns, dbid, name from drugbank.xml then parse synonymns
          from UNIIs records and match the results. 
          Output: FDA PreferredTerm, FDA synonymn, UNII, Drugbank drug, drugbank id, matchedByKey 
'''

from lxml import etree
from lxml.etree import XMLParser, parse
import os, sys
from sets import Set

DRUGBANK_XML = "../drugbank.xml"
UNIIS_NAMES = "../UNII-data/UNIIs 27Jun2014 Names.txt"
PT_INCHI_RECORDS = "../UNII-data/UNIIs 27Jun2014 Records.txt"

NS = "{http://www.drugbank.ca}" 

DRUGBANK_BIO2RDF = "http://bio2rdf.org/drugbank:"
DRUGBANK_CA = "http://www.drugbank.ca/drugs/"



'''
data structure of drugbank.xml
	
</drug><drug type="small molecule" created="2005-06-13 07:24:05 -0600"
updated="2013-09-16 17:11:29 -0600" version="4.0">
  <drugbank-id>DB00641</drugbank-id>


ata structure of drugbank.xml                                                                                                                                  
                                                                                                                                                               
</drug><drug type="small molecule" created="2005-06-13 07:24:05 -0600"                                                                                          
updated="2013-09-16 17:11:29 -0600" version="4.0">                                                                                                              
  <drugbank-id>DB00641</drugbank-id>                                                                                                                            
  <name>Simvastatin</name>                                                                                                                                      
  <property>                                                                                                                                                   
      <kind>InChIKey</kind>                                                                                                         
      <value>InChIKey=RYMZZMVNJRMUDD-HGQWONQESA-N</value>                                                                                                      
      <source>ChemAxon</source>                                                                                                                                
    </property>    

  <synonymns>
   <synonymn>...</synonymn>
   </synonyms>


'''


if len(sys.argv) > 1:
    validate_mode = str(sys.argv[1])
else:
    print "Usage: parseDBIdAndUNIIsBySynonymns.py <match mode>(0: (Inchi | name | synomyns) matched, 1: (Inchi && (name | synomyns matched)))"
    sys.exit(1)


## get dict of mappings of drugbank id, name, inchikeys and synonmymns

def parseDbIdAndSynonymns(root):
    dict_name_inchi_syns = {}

    for childDrug in root.iter(tag=NS + "drug"):
        subId = childDrug.find(NS + "drugbank-id")
        
        if subId == None:
            continue
        else:
            drugbankid = subId.text
            drugbankName = unicode(childDrug.find(NS + "name").text.upper())   

            dict_name_inchi_syns[drugbankName]={}
            dict_name_inchi_syns[drugbankName]["dbid"] = drugbankid

            ## get inchikey
            ikey = ""
            
            for subProp in childDrug.iter(NS + "property"):
                subKind = subProp.find(NS + "kind")
                if subKind == None:
                    continue
                elif subKind.text == "InChIKey":
                    subValue = subProp.find(NS + "value")
                    if subValue is not None:
 
                        ikey = subValue.text[9:]
            
            dict_name_inchi_syns[drugbankName]["inchi"] = ikey

            ## get synonyms
            set_syns = set()
            syns = childDrug.find(NS + "synonyms")
            if syns is not None:

                for subProp in syns.iter():
                    if subProp == None or subProp.text == None:
                        continue

                    if subProp.text.strip().replace('\n',"") is not "":
                        set_syns.add(subProp.text.upper())
        
            dict_name_inchi_syns[drugbankName]["syns"] = set_syns

    return dict_name_inchi_syns


## get dict of unii with inchi from PT_INCHI_RECORDS
## UNII    PT      RN      MF      INCHIKEY        EINECS  NCIt    ITIS    NCBI    PLANTS  SMILES
def parsePTAndInchi(path):

    dict_inchi = {}

    for line in open(path,'r').readlines():
        row = line.split('\t')

        if len(row) == 0:
            continue
    
        unii = row[0]
        inchi = row[4].strip().upper()
        
        if unii and inchi:
            dict_inchi[unii]=inchi

    return dict_inchi



def validates(dict_unii_inchi, dict_xml, validate_mode):

    #print "mode:" + validate_mode

    #read mapping file that contains Name    TYPE    UNII    PT
    (NAME, TYPE, UNII, PT) = range(0,4) 

    for line in open(UNIIS_NAMES,'r').readlines():

        row = line.split('\t')

        if len(row) == 0:
            continue

        name = row[NAME].strip().upper()
        unii = row[UNII]
        inchi=""

        if dict_unii_inchi.has_key(unii):
            inchi = dict_unii_inchi[unii]

	if inchi == "":
            continue
        
        drug_type = row[TYPE]

        if (drug_type == "PT") or (drug_type == "SY") or (drug_type == "SN"):

            if validate_mode is "0":

                for k,v in dict_xml.items():

                    matchedBy = ""

                    if k == name:
                        matchedBy = "name"

                    if name in v["syns"]:
                        if matchedBy == "":
                            matchedBy = "synonyms"
                        else:
                            matchedBy += "ANDsynonyms"

                    if inchi == v["inchi"]:
                        if matchedBy == "":
                            matchedBy = "inchi"
                        else:
                            matchedBy += "ANDinchi"

                    if matchedBy is not "":

                        #print "MATCHED:" + matchedBy
                        #print "NAMES:" + name + "|" + unii + "|" + inchi
                        #print "DICT_XML:" + str(k) + "|" + str(v)

                        drugbankid = v["dbid"]
                        drugbankName = k
                
                        output = row[PT].strip() +'\t' + row[NAME].strip() +'\t' + row[UNII].strip() +'\t'+ drugbankName +'\t'+ drugbankid + '\t' + matchedBy
                        print output.encode('utf-8').strip()
                        break

            elif validate_mode == "1":

                for k,v in dict_xml.items():
                #print str(k) + "|" + str(v)
                    matchedBy = ""

                    if inchi == v["inchi"]:
                        if k == name:
                            matchedBy = "nameANDinchi"
                        if name in v["syns"]:
                            if matchedBy == "":
                                matchedBy = "synonymsANDinchi"
                            else:
                                matchedBy = "nameANDsynonymsANDinchi"
                        
                    if matchedBy is not "":

                        drugbankid = v["dbid"]
                        drugbankName = k
                        
                        output = row[PT].strip() +'\t' + row[NAME].strip() +'\t' + row[UNII].strip() +'\t'+ drugbankName +'\t'+ drugbankid+ '\t' + matchedBy      
                        print output.encode('utf-8').strip()
                        break


def main():
   
    p = XMLParser(huge_tree=True)
    tree = parse(DRUGBANK_XML,parser=p)
    root = tree.getroot()
    
    ## get name, syns and inchi from drugbank.xml
    dict_xml = parseDbIdAndSynonymns(root)    
    #print str(dict_xml)
    

    dict_unii_inchi = parsePTAndInchi(PT_INCHI_RECORDS)
    #print str(dict_unii_inchi)

    validates(dict_unii_inchi, dict_xml, validate_mode)



if __name__ == "__main__":
    main()        



