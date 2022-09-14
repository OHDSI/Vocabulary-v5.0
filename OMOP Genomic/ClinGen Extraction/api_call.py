import requests
import pandas as pd
import json
import urllib3

# send a GET request with parameter
syn_gen_f1 = pd.read_csv("hgvs.csv")
syn_gen_f1 = syn_gen_f1.head(1000)
http = urllib3.PoolManager()
url = 'http://reg.test.genome.network/allele?hgvs='
j = []
i = 1
for seq in syn_gen_f1["concept_synonym_name"]:
    # convert symbol > to special code %3E
    url += requests.utils.quote(seq)
    res = http.request('GET', url)
    data = json.loads(res.data)
    r = {}
    try:
        r["communityStandardTitle"] = (data.get('communityStandardTitle'))
        for gen in data.get('genomicAlleles'):
            if gen.get('referenceGenome') != None:
                r[gen.get('referenceGenome')] = gen.get('hgvs')
            else:
                r['Other'] = gen.get('hgvs')
    except:
        pass
    if r['communityStandardTitle'] != None:
        with open("~\\output\\"+str(i)+".json", "w") as outfile:
            json.dump(r, outfile)
    else:
        continue
    print("HGVS Number "+str(i)+ ": "+seq+" processed")
    i += 1