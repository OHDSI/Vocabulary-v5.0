DROP TABLE IF EXISTS source_medicinal_product_mp;
CREATE TABLE source_medicinal_product_mp
(
    medicinalprod_id               VARCHAR(10),
    drug_record_number             VARCHAR(10),
    sequence_number_1              VARCHAR(10),
    sequence_number_2              VARCHAR(10),
    sequence_number_3              VARCHAR(10),
    sequence_number_4              VARCHAR(10),
    generic                        VARCHAR(1),
    drug_name                      VARCHAR(1500),
    name_specifier                 VARCHAR(30),
    country                        VARCHAR(5),
    company                        VARCHAR(10),
    marketing_authorization_holder VARCHAR(10),
    reference_code                 VARCHAR(10),
    source_country                 VARCHAR(10),
    year_of_reference              VARCHAR(10),
    product_type                   VARCHAR(10),
    product_group                  VARCHAR(10),
    create_date                    VARCHAR(8),
    date_changed                   VARCHAR(8)
);


DROP TABLE IF EXISTS ingredient_ing;
CREATE TABLE ingredient_ing
(
    ingredient_id    VARCHAR(10),
    create_date      VARCHAR(10),
    substance_id     VARCHAR(10),
    quantity         NUMERIC,
    quantity_2       VARCHAR(10),
    unit             VARCHAR(10),
    pharmproduct_id  VARCHAR(10),
    medicinalprod_id VARCHAR(10)
);


DROP TABLE IF EXISTS substance_sun;
CREATE TABLE substance_sun
(
    substance_id      VARCHAR(10),
    cas_number        VARCHAR(10),
    language_code     VARCHAR(5),
    substance_name    VARCHAR(255),
    year_of_reference VARCHAR(10),
    reference_code    VARCHAR(10)
);

DROP TABLE IF EXISTS strength_str;
CREATE TABLE strength_str
(
    strength_id VARCHAR(10),
    text        VARCHAR(255)
);


DROP TABLE IF EXISTS pharmaceutical_form_pf;
CREATE TABLE pharmaceutical_form_pf
(
    pharmform_id VARCHAR(10),
    text         VARCHAR(255)
);


DROP TABLE IF EXISTS organization_org;
CREATE TABLE organization_org
(
    organization_id VARCHAR(10),
    name            VARCHAR(100),
    country_code    VARCHAR(5)
);

