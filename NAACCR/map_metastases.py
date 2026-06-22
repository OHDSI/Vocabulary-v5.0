"""Metastasis mapping: fills maps_to_id, maps_to_value_id, value_as_number, unit_id in christian.naaccr_mapping."""
import os, sys
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

batches = [

    # ── Batch 1: already-mapped Metastasis-class rows → add Positive polarity ──
    # Excludes: Staging/Grading, Histopattern, LN concepts, M-stage-only v_names,
    #           2810/550 (extension, not met), 776/70 generic redundants
    ('Already-mapped Metastasis-class non-LN → add Positive polarity',
     """UPDATE christian.naaccr_mapping
        SET maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE maps_to_id IS NOT NULL
          AND maps_to_id NOT IN (36769269, 36769243, 36768587)
          AND maps_to_value_id IS NULL
          AND maps_to_id IN (
              SELECT concept_id FROM prodv5.concept
              WHERE concept_class_id = 'Metastasis'
          )
          AND lower(v_name) NOT LIKE 'stated as m%'
          AND NOT (item='2810' AND lower(v_name) LIKE '%%extension or metastasis%%')
          AND NOT (item='776' AND value='70' AND maps_to_id=36769180)""",
     {'pos': POS}),

    # ── Batch 2: site-specific binary items (0=No, 1=Yes already mapped) ──
    ('1112 Bone Met val=0 → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769301, maps_to_name='Metastasis to bone',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='1112' AND value='0'""",
     {'neg': NEG}),
    ('1115 Liver Met val=0 → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770544, maps_to_name='Metastasis to liver',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='1115' AND value='0'""",
     {'neg': NEG}),
    ('1116 Lung Met val=0 → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770283, maps_to_name='Metastasis to lung',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='1116' AND value='0'""",
     {'neg': NEG}),
    ('1117 Other Distant Met val=0 → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='1117' AND value='0'""",
     {'neg': NEG}),

    # ── Batch 3: Pediatric Mets ──
    ('1138 Pediatric Met val=00 → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='1138' AND value='00'""",
     {'neg': NEG}),
    ('1138 Pediatric Met val=70 → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='1138' AND value='70'""",
     {'pos': POS}),

    # ── Batch 4: staging items with metastasis stage ──
    ('1185 INRGSS M/MS stage → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='1185' AND value IN ('3','4')""",
     {'pos': POS}),
    ('1188 IRSS Stage IV → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='1188' AND value='4'""",
     {'pos': POS}),

    # ── Batch 5: Recurrence Type ──
    ('1880 Recurrence Type 59/70 → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='1880' AND value IN ('59','70')""",
     {'pos': POS}),

    # ── Batch 6: CS Extension (2810) — only specific reclassified met codes ──
    ('2810 code 130 malignant ascites → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770524, maps_to_name='Malignant ascites',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2810' AND value='130' AND lower(v_name) LIKE '%%malignant ascites%%'""",
     {'pos': POS}),
    ('2810 685/695 microscopic peritoneal → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35226253, maps_to_name='Metastasis to peritoneum',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2810' AND value IN ('685','695')""",
     {'pos': POS}),
    ('2810 722/725 peritoneal ≤2cm → Positive 1.5cm',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35226253, maps_to_name='Metastasis to peritoneum',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive',
            value_as_number=1.5, unit_id=%(cm)s, unit_name='centimeter'
        WHERE item='2810' AND value IN ('722','725')""",
     {'pos': POS, 'cm': CM}),
    ('2810 735 peritoneal >2cm → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35226253, maps_to_name='Metastasis to peritoneum',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2810' AND value='735'""",
     {'pos': POS}),
    ('2810 750 skin → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35225673, maps_to_name='Metastasis to skin',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2810' AND value='750' AND lower(v_name) LIKE '%%skin%%'""",
     {'pos': POS}),
    ('2810 750 peritoneal NOS → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35226253, maps_to_name='Metastasis to peritoneum',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2810' AND value='750' AND lower(v_name) LIKE '%%peritoneal%%'""",
     {'pos': POS}),
    ('2810 790/795 peritoneal implants → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35226253, maps_to_name='Metastasis to peritoneum',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2810' AND value IN ('790','795') AND lower(v_name) LIKE '%%peritoneal%%'""",
     {'pos': POS}),
    ('2810 720/760 pleural reclassified → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770024, maps_to_name='Malignant pleural effusion',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2810' AND value IN ('720','760')
          AND lower(v_name) LIKE '%%pleural%%' AND lower(v_name) LIKE '%%reclassif%%'""",
     {'pos': POS}),
    ('2810 790 pericardial → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35226251, maps_to_name='Metastasis to pericardium',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2810' AND value='790' AND lower(v_name) LIKE '%%pericardial%%'""",
     {'pos': POS}),

    # ── Batch 7: CS Mets at Dx (2850) ──
    ('2850 val=00 no distant met → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='2850' AND value='00'""",
     {'neg': NEG}),
    ('2850 val=05 molecular/circulating → Equivocal',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(equ)s, maps_to_value_name='Equivocal'
        WHERE item='2850' AND value='05' AND lower(v_name) LIKE '%%molecular%%'""",
     {'equ': EQU}),
    ('2850 pleural codes → Malignant pleural effusion Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770024, maps_to_name='Malignant pleural effusion',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2850' AND value IN ('15','16','17','18') AND lower(v_name) LIKE '%%pleural%%'""",
     {'pos': POS}),
    ('2850 skin → Metastasis to skin Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35225673, maps_to_name='Metastasis to skin',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2850' AND value='20' AND lower(v_name) LIKE '%%skin%%'""",
     {'pos': POS}),
    ('2850 remaining met codes → Metastasis Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2850' AND maps_to_id IS NULL
          AND value NOT IN ('00','99','50','51','52','55')
          AND lower(v_name) NOT LIKE '%%obsolete%%'
          AND lower(v_name) NOT LIKE '%%lymph node chain%%'
          AND lower(v_name) NOT LIKE '%%distant lymph node%%'
          AND lower(v_name) NOT LIKE '%%see code%%'
          AND lower(v_name) NOT LIKE 'stated as m%'""",
     {'pos': POS}),

    # ── Batch 8: CS Mets Eval (2860) — SKIP entirely ──

    # ── Batch 9: Mets at DX (2874) ──
    ('2874 val=000 no met → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='2874' AND value='000'""",
     {'neg': NEG}),
    ('2874 val=005 molecular circulating → Equivocal',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(equ)s, maps_to_value_name='Equivocal'
        WHERE item='2874' AND value='005'""",
     {'equ': EQU}),
    ('2874 val=010-040 confirmed → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2874' AND value IN ('010','020','030','040')""",
     {'pos': POS}),

    # ── Batch 10: Biopsy of Metastatic Site (2890) ──
    ('2890 code 100 met NOS → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2890' AND i_name='Biopsy of Metastatic Site' AND value='100'""",
     {'pos': POS}),
    ('2890 code 110 omentum → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35226218, maps_to_name='Metastasis to omentum',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2890' AND i_name='Biopsy of Metastatic Site' AND value='110'""",
     {'pos': POS}),
    ('2890 code 120 small intestine → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35225719, maps_to_name='Metastasis to small intestine',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2890' AND i_name='Biopsy of Metastatic Site' AND value='120'""",
     {'pos': POS}),
    ('2890 code 130 liver → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770544, maps_to_name='Metastasis to liver',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2890' AND i_name='Biopsy of Metastatic Site' AND value='130'""",
     {'pos': POS}),

    # ── Batch 11: item 2910 (three sub-variables) ──
    ('2910 Pathologic M1 val=000 → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='2910' AND i_name='Pathologic M1: Source of Pathologic Metastatic Specimen'
          AND value='000'""",
     {'neg': NEG}),
    ('2910 Resected Pulmonary val=000 → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770283, maps_to_name='Metastasis to lung',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='2910' AND i_name='Resected Pulmonary Metastasis' AND value='000'""",
     {'neg': NEG}),
    ('2910 Resected Pulmonary val=099 → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770283, maps_to_name='Metastasis to lung',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2910' AND i_name='Resected Pulmonary Metastasis' AND value='099'""",
     {'pos': POS}),
    ('2910 Size of Largest Met val=000 → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='2910' AND i_name='Size of Largest Metastasis' AND value='000'""",
     {'neg': NEG}),
    ('2910 Size of Largest Met val=980 ≥980mm → Positive 98cm',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive',
            value_as_number=98, unit_id=%(cm)s, unit_name='centimeter'
        WHERE item='2910' AND i_name='Size of Largest Metastasis' AND value='980'""",
     {'pos': POS, 'cm': CM}),
    ('2910 Size of Largest Met val=991 <3cm → Positive 1.5cm',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive',
            value_as_number=1.5, unit_id=%(cm)s, unit_name='centimeter'
        WHERE item='2910' AND i_name='Size of Largest Metastasis' AND value='991'""",
     {'pos': POS, 'cm': CM}),
    ('2910 Size of Largest Met val=992 3-8cm → Positive 5.5cm',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive',
            value_as_number=5.5, unit_id=%(cm)s, unit_name='centimeter'
        WHERE item='2910' AND i_name='Size of Largest Metastasis' AND value='992'""",
     {'pos': POS, 'cm': CM}),
    ('2910 Size of Largest Met val=993 >8cm → Positive 8cm',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive',
            value_as_number=8, unit_id=%(cm)s, unit_name='centimeter'
        WHERE item='2910' AND i_name='Size of Largest Metastasis' AND value='993'""",
     {'pos': POS, 'cm': CM}),

    # ── Batch 12: Malignant Ascites (2920) ──
    ('2920 Malignant Ascites val=000 → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770524, maps_to_name='Malignant ascites',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='2920' AND i_name='Malignant Ascites' AND value='000'""",
     {'neg': NEG}),
    ('2920 Malignant Ascites val=990 → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770524, maps_to_name='Malignant ascites',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='2920' AND i_name='Malignant Ascites' AND value='990'""",
     {'pos': POS}),

    # ── Batch 13: SS2018 val=7 ──
    ('764 SS2018 val=7 distant site/LN → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='764' AND value='7'""",
     {'pos': POS}),

    # ── Batch 14: EOD Mets (776) ──
    ('776 EOD Mets val=00 → Negative',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(neg)s, maps_to_value_name='Negative'
        WHERE item='776' AND value='00'""",
     {'neg': NEG}),
    ('776 EOD Mets val=05 pleural → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770024, maps_to_name='Malignant pleural effusion',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='776' AND value='05'""",
     {'pos': POS}),
    ('776 EOD Mets val=10 bone only → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769301, maps_to_name='Metastasis to bone',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='776' AND value='10' AND lower(v_name) LIKE '%%bone metastasis only%%'""",
     {'pos': POS}),
    ('776 EOD Mets val=35 spinal → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35225743, maps_to_name='Metastasis to spinal cord',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='776' AND value='35'""",
     {'pos': POS}),
    ('776 EOD Mets val=60 liver+other → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36770544, maps_to_name='Metastasis to liver',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='776' AND value='60' AND lower(v_name) LIKE '%%liver%%'""",
     {'pos': POS}),
    ('776 EOD Mets val=70 CNS/CSF → Positive',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=35226096, maps_to_name='Metastasis to central nervous system',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='776' AND value='70' AND lower(v_name) LIKE '%%cns%%'""",
     {'pos': POS}),
    ('776 EOD Mets remaining positive non-LN',
     """UPDATE christian.naaccr_mapping
        SET maps_to_id=36769180, maps_to_name='Metastasis',
            maps_to_value_id=%(pos)s, maps_to_value_name='Positive'
        WHERE item='776' AND maps_to_id IS NULL
          AND value NOT IN ('00')
          AND lower(v_name) NOT LIKE '%%no distant metastas%%'
          AND lower(v_name) NOT LIKE '%%single distant lymph node%%'
          AND lower(v_name) NOT LIKE '%%lymph node(s), nos%%'""",
     {'pos': POS}),
]

DRY_RUN = '--commit' not in sys.argv

if DRY_RUN:
    print("DRY RUN — pass --commit to execute\n")
    total = 0
    for label, sql, params in batches:
        # extract WHERE clause for counting
        where_idx = sql.upper().rfind('WHERE ')
        where_clause = sql[where_idx:]
        count_sql = f"SELECT count(*) FROM christian.naaccr_mapping {where_clause}"
        try:
            cur.execute(count_sql, params)
            n = cur.fetchone()[0]
            total += n
            print(f"  {n:>5}  {label}")
        except Exception as e:
            conn.rollback()
            print(f"  ERR    {label}: {e}")
    print(f"\nTotal rows to be updated: {total}")
else:
    print("EXECUTING updates...\n")
    total = 0
    for label, sql, params in batches:
        try:
            cur.execute(sql, params)
            n = cur.rowcount
            total += n
            print(f"  {n:>5}  {label}")
        except Exception as e:
            conn.rollback()
            print(f"  ERR    {label}: {e}")
            sys.exit(1)
    conn.commit()
    print(f"\nCommitted. Total rows updated: {total}")

conn.close()
