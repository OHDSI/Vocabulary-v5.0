# Schema Creation

If you do not have development schema, you could create a custom schema and upload all necessary tables for desired vocabularies. To perform this, you need the following:

* Access to [Athena OHDSI](http://athena.ohdsi.org) (vocabulary service).
* Access to your workspace (database).
* SQL client (e.g., SQL Workbench, DBeaver, SQL Developer, pgAdmin) with permissions to upload data.
* Basic understanding of [OMOP CDM (Common Data Model)](https://ohdsi.github.io/CommonDataModel/cdm54.html) and vocabulary concepts.

Steps: 
1. Verify OMOP CDM Instance and Database Access:
* Ensure your OMOP Common Data Model (CDM) instance is properly deployed and operational.
* Confirm that you have the necessary credentials and permissions to access the database schema where the OMOP Standardized Vocabularies will be stored.

2. Verify Required OMOP Vocabulary Tables:
* Connect to your OMOP database using your preferred SQL client.
* Verify the existence of the following OMOP Standardized Vocabulary tables:
  
|Table|
|---|
|CONCEPT|
|CONCEPT_ANCESTOR|
|CONCEPT_CLASS|
|CONCEPT_RELATIONSHIP|
|CONCEPT_SYNONYM|
|DOMAIN|
|DRUG_STRENGTH|
|RELATIONSHIP|
|VOCABULARY|

If any of the required OMOP vocabulary tables are missing, create them using the [Data Definition Language (DDL)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/DevV5_DDL.sql) specifications provided in the official OMOP CDM documentation.

3. Download Required Vocabularies from [Athena OHDSI](http://athena.ohdsi.org):
   
3.1. Access Athena:
* Open your web browser and navigate to the [Athena OHDSI](http://athena.ohdsi.org) website.
* Log in using your credentials. If you do not have an account, register for one.
  
3.2. Search for Relevant Vocabularies:
* Use the search functionality to find the vocabulary versions you need.
* You may need the following vocabularies:
  
|Vocabulary|
|---|
|RxNorm|
|RxNorm Extension|
|SNOMED|
|CVX|
|UCUM|

3.3. Select and Download:
* Click "Download" in the top right corner of the page.
* Select the desired vocabularies.
* Click "Download Vocabularies."
* Name the bundle and choose the appropriate version.
* Initiate the download process. Athena will send the vocabularies as CSV files (often zipped) to your email.
* Unzip the downloaded files to a local directory.
  
3.4 Verify Downloaded Files:
Confirm that you have the following essential vocabulary files:

|Files|
|---|
|CONCEPT.csv|
|CONCEPT_ANCESTOR.csv|
|CONCEPT_CLASS.csv|
|CONCEPT_RELATIONSHIP.csv|
|CONCEPT_SYNONYM.csv|
|DOMAIN.csv|
|DRUG_STRENGTH.csv|
|RELATIONSHIP.csv|
|VOCABULARY.csv|

4. Upload Vocabularies into Your OMOP Workspace Schema:
 
4.1. Connect to Your OMOP Database:
* Open your SQL client and connect to your database using your credentials.
* Ensure you are connected to the correct schema where your tables reside.

4.2 Import CSV Files:
Import the data from the downloaded Athena CSV files into the corresponding OMOP vocabulary tables:

|File||Table in Database|
|---|---|---|
|CONCEPT.csv| → |concept|
|CONCEPT_ANCESTOR.csv| → |concept_ancestor|
|CONCEPT_CLASS.csv| → |concept_class|
|CONCEPT_RELATIONSHIP.csv| → |concept_relationship|
|CONCEPT_SYNONYM.csv| → |concept_synonym|
|DOMAIN.csv| → |domain|
|DRUG_STRENGTH.csv| → |drug_strength|
|RELATIONSHIP.csv| → |relationship|
|VOCABULARY.csv| → |vocabulary|