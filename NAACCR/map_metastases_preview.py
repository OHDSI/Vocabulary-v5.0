"""Preview metastasis mapping: writes what WOULD be updated to a CSV for spot-checking."""
import os, csv
from dotenv import load_dotenv
import psycopg2

load_dotenv()
conn = psycopg2.connect(
    host=os.getenv('DB_HOST'), port=os.getenv('DB_PORT'),
    dbname=os.getenv('DB_NAME'), user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD')
)
cur = conn.cursor()

POS = 9191
NEG = 9189
EQU = 4172976
CM  = 8582

# Each entry: (batch_label, WHERE clause, SET values dict, params dict)
# We SELECT the current row plus show what it would become.
batches = [
    ('Already-mapped Metastasis-class non-LN add Positive polarity',
     """maps_to_id IS NOT NULL
        AND maps_to_id NOT IN (36769269,36769243,36768587)
        AND maps_to_value_id IS NULL
        AND maps_to_id IN (SELECT concept_id FROM prodv5.concept WHERE concept_class_id='Metastasis')
        AND lower(v_name) NOT LIKE 'stated as m%%'
        AND NOT (item='2810' AND lower(v_name) LIKE %(like_ext)s)
        AND NOT (item='776' AND value='70' AND maps_to_id=36769180)""",
     {'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_ext': '%extension or metastasis%'}),

    ('1112 Bone Met val=0 Negative',
     "item='1112' AND value='0'",
     {'maps_to_id': 36769301, 'maps_to_name': 'Metastasis to bone', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),
    ('1115 Liver Met val=0 Negative',
     "item='1115' AND value='0'",
     {'maps_to_id': 36770544, 'maps_to_name': 'Metastasis to liver', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),
    ('1116 Lung Met val=0 Negative',
     "item='1116' AND value='0'",
     {'maps_to_id': 36770283, 'maps_to_name': 'Metastasis to lung', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),
    ('1117 Other Distant Met val=0 Negative',
     "item='1117' AND value='0'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),

    ('1138 Pediatric Met val=00 Negative',
     "item='1138' AND value='00'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),
    ('1138 Pediatric Met val=70 Positive',
     "item='1138' AND value='70'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),

    ('1185 INRGSS M/MS stage Positive',
     "item='1185' AND value IN ('3','4')",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),
    ('1188 IRSS Stage IV Positive',
     "item='1188' AND value='4'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),

    ('1880 Recurrence Type 59/70 Positive',
     "item='1880' AND value IN ('59','70')",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),

    ('2810 code 130 malignant ascites Positive',
     "item='2810' AND value='130' AND lower(v_name) LIKE %(like_asc)s",
     {'maps_to_id': 36770524, 'maps_to_name': 'Malignant ascites', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_asc': '%malignant ascites%'}),
    ('2810 685/695 microscopic peritoneal Positive',
     "item='2810' AND value IN ('685','695')",
     {'maps_to_id': 35226253, 'maps_to_name': 'Metastasis to peritoneum', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),
    ('2810 722/725 peritoneal le2cm Positive 1.5cm',
     "item='2810' AND value IN ('722','725')",
     {'maps_to_id': 35226253, 'maps_to_name': 'Metastasis to peritoneum', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive', 'value_as_number': 1.5, 'unit_id': CM, 'unit_name': 'centimeter'}, {}),
    ('2810 735 peritoneal gt2cm Positive',
     "item='2810' AND value='735'",
     {'maps_to_id': 35226253, 'maps_to_name': 'Metastasis to peritoneum', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),
    ('2810 750 skin Positive',
     "item='2810' AND value='750' AND lower(v_name) LIKE %(like_skin)s",
     {'maps_to_id': 35225673, 'maps_to_name': 'Metastasis to skin', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_skin': '%skin%'}),
    ('2810 750 peritoneal NOS Positive',
     "item='2810' AND value='750' AND lower(v_name) LIKE %(like_per)s",
     {'maps_to_id': 35226253, 'maps_to_name': 'Metastasis to peritoneum', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_per': '%peritoneal%'}),
    ('2810 790/795 peritoneal implants Positive',
     "item='2810' AND value IN ('790','795') AND lower(v_name) LIKE %(like_per)s",
     {'maps_to_id': 35226253, 'maps_to_name': 'Metastasis to peritoneum', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_per': '%peritoneal%'}),
    ('2810 720/760 pleural reclassified Positive',
     "item='2810' AND value IN ('720','760') AND lower(v_name) LIKE %(like_pl)s AND lower(v_name) LIKE %(like_re)s",
     {'maps_to_id': 36770024, 'maps_to_name': 'Malignant pleural effusion', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_pl': '%pleural%', 'like_re': '%reclassif%'}),
    ('2810 790 pericardial Positive',
     "item='2810' AND value='790' AND lower(v_name) LIKE %(like_pc)s",
     {'maps_to_id': 35226251, 'maps_to_name': 'Metastasis to pericardium', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_pc': '%pericardial%'}),

    ('2850 val=00 no distant met Negative',
     "item='2850' AND value='00'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),
    ('2850 val=05 molecular Equivocal',
     "item='2850' AND value='05' AND lower(v_name) LIKE %(like_mol)s",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': EQU, 'maps_to_value_name': 'Equivocal'},
     {'like_mol': '%molecular%'}),
    ('2850 pleural codes Positive',
     "item='2850' AND value IN ('15','16','17','18') AND lower(v_name) LIKE %(like_pl)s",
     {'maps_to_id': 36770024, 'maps_to_name': 'Malignant pleural effusion', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_pl': '%pleural%'}),
    ('2850 skin Positive',
     "item='2850' AND value='20' AND lower(v_name) LIKE %(like_sk)s",
     {'maps_to_id': 35225673, 'maps_to_name': 'Metastasis to skin', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_sk': '%skin%'}),
    ('2850 remaining met codes Positive',
     """item='2850' AND maps_to_id IS NULL
        AND value NOT IN ('00','99','50','51','52','55')
        AND lower(v_name) NOT LIKE %(like_obs)s
        AND lower(v_name) NOT LIKE %(like_lnc)s
        AND lower(v_name) NOT LIKE %(like_lnd)s
        AND lower(v_name) NOT LIKE %(like_see)s
        AND lower(v_name) NOT LIKE 'stated as m%%'""",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_obs': '%obsolete%', 'like_lnc': '%lymph node chain%', 'like_lnd': '%distant lymph node%', 'like_see': '%see code%'}),

    ('2874 val=000 no met Negative',
     "item='2874' AND value='000'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),
    ('2874 val=005 molecular Equivocal',
     "item='2874' AND value='005'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': EQU, 'maps_to_value_name': 'Equivocal'}, {}),
    ('2874 val=010-040 confirmed Positive',
     "item='2874' AND value IN ('010','020','030','040')",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),

    ('2890 code 100 met NOS Positive',
     "item='2890' AND i_name='Biopsy of Metastatic Site' AND value='100'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),
    ('2890 code 110 omentum Positive',
     "item='2890' AND i_name='Biopsy of Metastatic Site' AND value='110'",
     {'maps_to_id': 35226218, 'maps_to_name': 'Metastasis to omentum', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),
    ('2890 code 120 small intestine Positive',
     "item='2890' AND i_name='Biopsy of Metastatic Site' AND value='120'",
     {'maps_to_id': 35225719, 'maps_to_name': 'Metastasis to small intestine', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),
    ('2890 code 130 liver Positive',
     "item='2890' AND i_name='Biopsy of Metastatic Site' AND value='130'",
     {'maps_to_id': 36770544, 'maps_to_name': 'Metastasis to liver', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),

    ('2910 Pathologic M1 val=000 Negative',
     "item='2910' AND i_name='Pathologic M1: Source of Pathologic Metastatic Specimen' AND value='000'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),
    ('2910 Resected Pulmonary val=000 Negative',
     "item='2910' AND i_name='Resected Pulmonary Metastasis' AND value='000'",
     {'maps_to_id': 36770283, 'maps_to_name': 'Metastasis to lung', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),
    ('2910 Resected Pulmonary val=099 Positive',
     "item='2910' AND i_name='Resected Pulmonary Metastasis' AND value='099'",
     {'maps_to_id': 36770283, 'maps_to_name': 'Metastasis to lung', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),
    ('2910 Size Largest Met val=000 Negative',
     "item='2910' AND i_name='Size of Largest Metastasis' AND value='000'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),
    ('2910 Size Largest Met val=980 Positive 98cm',
     "item='2910' AND i_name='Size of Largest Metastasis' AND value='980'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive', 'value_as_number': 98, 'unit_id': CM, 'unit_name': 'centimeter'}, {}),
    ('2910 Size Largest Met val=991 Positive 1.5cm',
     "item='2910' AND i_name='Size of Largest Metastasis' AND value='991'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive', 'value_as_number': 1.5, 'unit_id': CM, 'unit_name': 'centimeter'}, {}),
    ('2910 Size Largest Met val=992 Positive 5.5cm',
     "item='2910' AND i_name='Size of Largest Metastasis' AND value='992'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive', 'value_as_number': 5.5, 'unit_id': CM, 'unit_name': 'centimeter'}, {}),
    ('2910 Size Largest Met val=993 Positive 8cm',
     "item='2910' AND i_name='Size of Largest Metastasis' AND value='993'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive', 'value_as_number': 8, 'unit_id': CM, 'unit_name': 'centimeter'}, {}),

    ('2920 Malignant Ascites val=000 Negative',
     "item='2920' AND i_name='Malignant Ascites' AND value='000'",
     {'maps_to_id': 36770524, 'maps_to_name': 'Malignant ascites', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),
    ('2920 Malignant Ascites val=990 Positive',
     "item='2920' AND i_name='Malignant Ascites' AND value='990'",
     {'maps_to_id': 36770524, 'maps_to_name': 'Malignant ascites', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),

    ('764 SS2018 val=7 Positive',
     "item='764' AND value='7'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),

    ('776 EOD Mets val=00 Negative',
     "item='776' AND value='00'",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': NEG, 'maps_to_value_name': 'Negative'}, {}),
    ('776 EOD Mets val=05 pleural Positive',
     "item='776' AND value='05'",
     {'maps_to_id': 36770024, 'maps_to_name': 'Malignant pleural effusion', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),
    ('776 EOD Mets val=10 bone only Positive',
     "item='776' AND value='10' AND lower(v_name) LIKE %(like_bn)s",
     {'maps_to_id': 36769301, 'maps_to_name': 'Metastasis to bone', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_bn': '%bone metastasis only%'}),
    ('776 EOD Mets val=35 spinal Positive',
     "item='776' AND value='35'",
     {'maps_to_id': 35225743, 'maps_to_name': 'Metastasis to spinal cord', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'}, {}),
    ('776 EOD Mets val=60 liver+other Positive',
     "item='776' AND value='60' AND lower(v_name) LIKE %(like_lv)s",
     {'maps_to_id': 36770544, 'maps_to_name': 'Metastasis to liver', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_lv': '%liver%'}),
    ('776 EOD Mets val=70 CNS/CSF Positive',
     "item='776' AND value='70' AND lower(v_name) LIKE %(like_cns)s",
     {'maps_to_id': 35226096, 'maps_to_name': 'Metastasis to central nervous system', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_cns': '%cns%'}),
    ('776 EOD Mets remaining positive non-LN',
     """item='776' AND maps_to_id IS NULL
        AND value NOT IN ('00')
        AND lower(v_name) NOT LIKE %(like_nd)s
        AND lower(v_name) NOT LIKE %(like_sl)s
        AND lower(v_name) NOT LIKE %(like_ln)s""",
     {'maps_to_id': 36769180, 'maps_to_name': 'Metastasis', 'maps_to_value_id': POS, 'maps_to_value_name': 'Positive'},
     {'like_nd': '%no distant metastas%', 'like_sl': '%single distant lymph node%', 'like_ln': '%lymph node(s), nos%'}),
]

out_path = r'C:\Users\reich\OneDrive - OHDSI\GitHub\Vocabulary-v5.0\NAACCR\metastasis_preview.csv'
set_cols = ['maps_to_id', 'maps_to_name', 'maps_to_value_id', 'maps_to_value_name', 'value_as_number', 'unit_id', 'unit_name']
fieldnames = ['batch', 'item', 'i_name', 'value', 'v_name',
              'cur_maps_to_id', 'cur_maps_to_name', 'cur_maps_to_value_id', 'cur_maps_to_value_name',
              'new_maps_to_id', 'new_maps_to_name', 'new_maps_to_value_id', 'new_maps_to_value_name',
              'new_value_as_number', 'new_unit_id', 'new_unit_name']

total = 0
with open(out_path, 'w', newline='', encoding='utf-8-sig') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    for label, where, new_vals, params in batches:
        sql = f"""SELECT item, i_name, value, v_name,
                         maps_to_id, maps_to_name, maps_to_value_id, maps_to_value_name
                  FROM christian.naaccr_mapping
                  WHERE {where}
                  ORDER BY item, value"""
        cur.execute(sql, params)
        rows = cur.fetchall()
        total += len(rows)
        for r in rows:
            v_name_clean = ' | '.join(str(r[3] or '').replace('\r', '').split('\n'))
            writer.writerow({
                'batch': label,
                'item': r[0], 'i_name': r[1], 'value': r[2], 'v_name': v_name_clean,
                'cur_maps_to_id': r[4], 'cur_maps_to_name': r[5],
                'cur_maps_to_value_id': r[6], 'cur_maps_to_value_name': r[7],
                'new_maps_to_id': new_vals.get('maps_to_id', ''),
                'new_maps_to_name': new_vals.get('maps_to_name', ''),
                'new_maps_to_value_id': new_vals.get('maps_to_value_id', ''),
                'new_maps_to_value_name': new_vals.get('maps_to_value_name', ''),
                'new_value_as_number': new_vals.get('value_as_number', ''),
                'new_unit_id': new_vals.get('unit_id', ''),
                'new_unit_name': new_vals.get('unit_name', ''),
            })

conn.close()
print(f"Written {total} rows to {out_path}")
