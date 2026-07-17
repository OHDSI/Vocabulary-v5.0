CREATE OR REPLACE FUNCTION vocabulary_download.py_load_atc()
RETURNS TABLE(
    class_code text, 
    class_name text, 
    ddd text, 
    u text, 
    adm_r text, 
    note text, 
    start_date date, 
    revision_date date, 
    active text, 
    replaced_by text, 
    ver text)
LANGUAGE plpython3u
AS 
$BODY$

from bs4 import BeautifulSoup as bs
import requests
from datetime import date, datetime
import pandas as pd
import numpy as np
import os
import re


def atc_dates_parse():
    urls = ['https://atcddd.fhi.no/atc_ddd_index/', 
           'https://atcddd.fhi.no/atc_ddd_alterations__cumulative/ddd_alterations/',
           'https://atcddd.fhi.no/atc_ddd_alterations__cumulative/atc_alterations/']

    ver = ''
    
    for url in urls:
        response = requests.get(url)
        soup = bs(response.text, 'html.parser')
        last_updated_div = soup.find('div', id='last_updated')
        date_string = last_updated_div.find('i').text.replace('Last updated: ', '').strip()
        date = datetime.strptime(date_string, '%Y-%m-%d')
        ver += date.strftime('%y%m%d')
        
    return ver


def atc_alterations():
    url = f"https://atcddd.fhi.no/atc_ddd_alterations__cumulative/atc_alterations/"
    
    response = requests.request("GET", url)
    parsed = bs (response.text, 'lxml')
    result = []
    
    trs = parsed.find_all('tr')
    result = []
    for tr in trs:
        find = tr.find_all('td')
        if len(find)>3:
            code_old = find[0].text.split()[0].strip()
            name = re.match(r'[A-Za-z0-9, -]+', find[1].text.strip()).group(0)
            code_new = find[2].text.split()[0].strip()
            date_of_change = find[3].text.strip()
            result.append((code_old, name, code_new, date_of_change))
    
    if len(result) == 0:
        raise Exception ('No source codes from atc_alterations')
    
    return pd.DataFrame(result, columns=['code_old', 'name', 'code_new', 'date_of_change'])

def ddd_table():
    url = f"https://atcddd.fhi.no/atc_ddd_alterations__cumulative/ddd_alterations/"
    response = requests.request("GET", url)
    parsed = bs (response.text, 'lxml')
    trs = parsed.find_all('tr')
    result = []
    for tr in trs:
        find = tr.find_all('td')
        if len(find)>3:
            name = re.sub(r'\s*\xa0.*$', '', find[0].text.strip())
            old_dose = re.sub(r'\s*\xa0.*$', '', find[1].text.strip())
            old_unit = re.sub(r'\s*\xa0.*$', '', find[2].text.strip())
            old_route = re.sub(r'\s*\xa0.*$', '', find[3].text.strip())
            new_dose = re.sub(r'\s*\xa0.*$', '', find[4].text.strip())
            new_unit = re.sub(r'\s*\xa0.*$', '', find[5].text.strip())
            new_route = re.sub(r'\s*\xa0.*$', '', find[6].text.strip())
            code = re.sub(r'\s*\xa0.*$', '', find[7].text.strip())
            date = re.sub(r'\s*\xa0.*$', '', find[8].text.strip())

            result.append((name, old_dose, old_unit, old_route, new_dose, new_unit, new_route, code, date))
    
    if len(result) == 0:
        raise Exception ('No source codes from ddd_alterations')
        
    return pd.DataFrame(result, columns=['name', 'old_dose', 'old_unit', 'old_route', 'new_dose', 'new_unit', 'new_route', 'code', 'date'])

def parser (level = 1, layer_name = None):
    
    if level < 1:
        raise Exception("Minimum level is 1")        
    
    url = 'https://atcddd.fhi.no/atc_ddd_index/'
    
    if layer_name:
        url = f"https://atcddd.fhi.no/atc_ddd_index/?code={layer_name}&showdescription=no"
        
    response = requests.request("GET", url)
    parsed = bs (response.text, 'lxml')
    result = []
    
    if level == 5:
        trs = parsed.find_all('tr')
        temp_code = ''
        temp_ing = ''

        for tr in trs:
            tds = tr.find_all('td')
            if len(tr) >= 3 and tds[0].text.strip() != 'ATC code':
                code = tds[0].text.strip()
                ingridient = tds[1].text.strip()

                if code != '' and ingridient != '':
                    temp_code = code
                    temp_ing = ingridient
                else:
                    code = temp_code
                    ingridient = temp_ing

                dosage = tds[2].text.strip()
                unit = tds[3].text.strip()
                adm_rout = tds[4].text.strip()
                note = tds[5].text.strip()

                result.append((code, ingridient, dosage, unit, adm_rout, note))
        return result
    
    else:
        bis = parsed.find_all('b')
        for b in bis:
            a_tag = b.find_all('a')
            code = a_tag[0]['href'].split('=')[1].split('&')[0]
            description = a_tag[0].text
            result.append((code,description))  
    
   
    return result[level-1:]


l1_codes = parser(level=1)
if len(l1_codes) == 0:
    raise Exception ('No source codes from Level l1_codes')

l2_codes = []
for code in l1_codes:
    l2_codes+=parser(level = 2,layer_name=code[0])

if len(l2_codes) == 0:
    raise Exception ('No source codes from Level l2_codes')

l3_codes = []
for code in l2_codes:
    l3_codes+=parser(level = 3,layer_name=code[0])
if len(l3_codes) == 0:
    raise Exception ('No source codes from Level l3_codes')

l4_codes = []
for code in l3_codes:
    l4_codes+=parser(level = 4,layer_name=code[0])

if len(l4_codes) == 0:
    raise Exception ('No source codes from Level l4_codes')

l5_codes = []
for code in l4_codes:
    l5_codes+=parser(level = 5,layer_name=code[0])

if len(l5_codes) == 0:
    raise Exception ('No source codes from Level l5_codes')

ATC_general = pd.DataFrame(l1_codes+l2_codes+l3_codes+l4_codes+l5_codes, 
                           columns=('class_code','class_name', 'ddd', 'u','adm_r','note'))

ATC_general['valid_start_date'] = date.isoformat(date.today())
ATC_general['valid_end_date'] = date.isoformat(date (2099, 12,31))
ATC_general['change_type']=''
ATC_general['replaced_by']=''
ATC_general = ATC_general[['class_code','class_name', 'ddd', 'u','adm_r','note','valid_start_date','valid_end_date', 'change_type','replaced_by']]

def u_d_flags(ATC_codes, codes_changes):
    final = []
    for index in codes_changes.index:
        if codes_changes.iloc[index]['code_old'] in ATC_codes['class_code'].values:
            pass # do nothing if the code is in the main table
        else:
            new_code = codes_changes.iloc[index]['code_new']
            old_code = codes_changes.iloc[index]['code_old']
            name = codes_changes.iloc[index]['name']        
            date_of_change = int(codes_changes.iloc[index]['date_of_change'])
            
            # If the new code is 7-digit and there is no reference to the fact that it was deleted, it means a remap
            if len(new_code) == 7 and new_code != 'deleted': 
                # Create a new record to add to the table with the dead code
                result = (old_code, name,'','','','',date.isoformat(date (1970, 1,1)), date.isoformat(date (date_of_change, 1,1)), 'U', new_code)
                # Change the start date for the new code
                ATC_codes.loc[ATC_codes.class_code == new_code, 'valid_start_date'] = date.isoformat(date (date_of_change, 1,1))
            # If there is no new 7-digit code, the code is dead.
            else: 
                result = (old_code, name,'','','','',date.isoformat(date (1970, 1,1)), date.isoformat(date (date_of_change, 1,1)), 'D', '')
                
            final.append(result)
    final = pd.DataFrame(final, columns = ['class_code','class_name', 'ddd', 'u','adm_r','note','valid_start_date','valid_end_date', 'change_type','replaced_by'])
    return (pd.concat([ATC_codes, final] , ignore_index=True).sort_values('class_code'))


def c_flags(ATC_codes, ddd_changes, codes_changes):
    final = []
    list_of_changed_codes = codes_changes.code_old.values
    
    for index in ddd_changes.index:
        
        # Get an info about the code
        name = ddd_changes.iloc[index]['name']
        code = ddd_changes.iloc[index]['code']
        date_of_change = int(ddd_changes.iloc[index]['date'])
        old_dose = ddd_changes.iloc[index]['old_dose']
        old_unit = ddd_changes.iloc[index]['old_unit']
        old_route = ddd_changes.iloc[index]['old_route']
        
        try:
            new_dose = float(ddd_changes.iloc[index]['new_dose'])
        except:
            pass
        
        new_unit = ddd_changes.iloc[index]['new_unit']
        new_route = ddd_changes.iloc[index]['new_route']
        
        
        
        # Add dead one to the list
        if len(code) == 7:
            final.append((code, name, old_dose, old_unit, old_route, '',
                          date.isoformat(date (1970, 1,1)), 
                          date.isoformat(date (date_of_change, 1,1)), 
                          'C', ''))
        else: 
            # Logic for a 5-digit code
            # Get a list of all codes at a sublevel
            codes_on_5th = ATC_codes.loc[(ATC_codes['class_code'].str.startswith(code)), 'class_code'].values[1:]
            
            for code_on_5th in codes_on_5th:
                try:
                    name = ATC_general.loc[ATC_general.class_code == code_on_5th, 'class_name'].iloc[0]
                    final.append((code_on_5th, name, old_dose,old_unit,old_route, '',
                                  date.isoformat(date (1970, 1,1)), date.isoformat(date (date_of_change, 1,1)), 'C', ''))
                    
                    ATC_codes.loc[
                        ATC_codes['class_code'] == code_on_5th,
                        'valid_start_date'
                    ] = date.isoformat(date (date_of_change, 1,1))
                    
                    # Insert date processing for codes without changed doses
                
                except:
                    pass
            
        if new_dose != 'deleted' and new_unit != 'deleted' and new_route != 'deleted':
            if code not in list_of_changed_codes:
                ATC_codes.loc[
                        (ATC_codes['class_code'] == code) &
                        (ATC_codes['ddd'] == new_dose) &
                        (ATC_codes['u'] == new_unit) &
                        (ATC_codes['adm_r'] == new_route),
                        'valid_start_date'
                    ] = date.isoformat(date (date_of_change, 1,1))
            else:
                ATC_codes.loc[
                        (ATC_codes['class_code'] == code) &
                        (ATC_codes['change_type'] == 'U'),
                        'valid_start_date'
                    ] = date.isoformat(date (date_of_change, 1,1))
                
                ATC_codes.loc[
                        (ATC_codes['class_code'] == code) &
                        (ATC_codes['change_type'] == 'U'),
                        'ddd'
                    ] = new_dose
                
                ATC_codes.loc[
                        (ATC_codes['class_code'] == code) &
                        (ATC_codes['change_type'] == 'U'),
                        'u'
                    ] = new_unit
                
                ATC_codes.loc[
                        (ATC_codes['class_code'] == code) &
                        (ATC_codes['change_type'] == 'U'),
                        'adm_r'
                    ] = new_route
                   
    final = pd.DataFrame(final, columns = ['class_code','class_name', 'ddd', 'u','adm_r', 'note','valid_start_date','valid_end_date', 'change_type','replaced_by'])
    return (pd.concat([ATC_codes, final] , ignore_index=True).sort_values('class_code'))

atc_change = atc_alterations()
ddd_change = ddd_table()

# Apply the function of arranging U and D flags
new_atc = u_d_flags(ATC_general, atc_change)

# Apply the function of arranging C flags
new_one = c_flags(new_atc, ddd_change, atc_change).sort_values('class_code')

new_one = new_one.replace(to_replace=np.nan, value='NA')
new_one = new_one.replace(to_replace='', value='NA')

new_one['version'] = atc_dates_parse()

return new_one.values.tolist()
$BODY$
;