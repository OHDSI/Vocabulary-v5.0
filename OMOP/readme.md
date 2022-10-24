dev_omop is a service schema, which is used to add new concepts, synonyms and concept relationships manually. We don't save the manual tables here.

To add a new concept/synonym/relationship:
1. Truncate the manual tables
2. Run the select query from the respective manual table
3. Press the '+' ('Add new row') button and input all the necessary data into the slots
4. Press 'Submit' (Ctrl + Enter)
5. Run load_stage.sql
6. Run GenericUpdate
7. Run the QA