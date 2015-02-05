CREATE TABLE PRODUCT
(
  PRODUCTID                  VARCHAR2(50 BYTE),
  PRODUCTNDC                 VARCHAR2(10 BYTE),
  PRODUCTTYPENAME            VARCHAR2(27 BYTE),
  PROPRIETARYNAME            VARCHAR2(226 BYTE),
  PROPRIETARYNAMESUFFIX      VARCHAR2(126 BYTE),
  NONPROPRIETARYNAME         VARCHAR2(4000 BYTE),
  DOSAGEFORMNAME             VARCHAR2(48 BYTE),
  ROUTENAME                  VARCHAR2(118 BYTE),
  STARTMARKETINGDATE         DATE,
  ENDMARKETINGDATE           DATE,
  MARKETINGCATEGORYNAME      VARCHAR2(40 BYTE),
  APPLICATIONNUMBER          VARCHAR2(100 BYTE),
  LABELERNAME                VARCHAR2(100 BYTE),
  SUBSTANCENAME              VARCHAR2(4000 BYTE),
  ACTIVE_NUMERATOR_STRENGTH  VARCHAR2(4000 BYTE),
  ACTIVE_INGRED_UNIT         VARCHAR2(4000 BYTE),
  PHARM_CLASSES              VARCHAR2(4000 BYTE),
  DEASCHEDULE                VARCHAR2(5 BYTE)
);

CREATE INDEX idx_f_product
   ON product (SUBSTR (productid, INSTR (productid, '_') + 1))
   NOLOGGING;
   
CREATE INDEX idx_f1_product
ON product( 
    CASE
    WHEN INSTR (productndc, '-') = 5
    THEN '0' || SUBSTR (productndc,1,INSTR (productndc, '-') - 1)
    ELSE SUBSTR (productndc, 1, INSTR (productndc, '-') - 1)
    END||
    CASE
    WHEN LENGTH ( SUBSTR (productndc, INSTR (productndc, '-'))) = 4
    THEN '0' || SUBSTR (productndc,INSTR (productndc, '-') + 1)
    ELSE
      SUBSTR (productndc,INSTR (productndc, '-') + 1)
    END)
NOLOGGING;   