The working folder contains a set of SQL scripts grouped into packages based on their function. Each package includes detailed documentation in its folder’s README file.

A general description of each package is provided below:

| Name                         | Description                                                                                                            |
|------------------------------|------------------------------------------------------------------------------------------------------------------------|
| `APIgrabber`                 | Scripts used for processing NDC codes.                                                                                 |
| `DevV5_additional_functions` | Functions not available in PostgreSQL by default but used in vocabulary processing.                                    |
| `QA_TESTS`                   | Scripts for automated QA of the schema after the `GenericUpdate` script.                                               |
| `admin_pack`                 | Package for administrative tasks and logging of manual work.                                                           |
| `audit_pack`                 | Package for logging base tables in `devv5` with the ability to restore to any point in time in any dev schema.         |
| `google_pack`                | Package that enables the use of Google APIs and simplifies integration between Google Drive and the vocabulary server. |
| `load_input_tables`          | Scripts for loading source input tables.                                                                               |
| `metadata`                   | Scripts related to vocabulary metadata.                                                                                |
| `reference_pack`             | Standard functions used for vocabulary work (e.g., `AddNewConcept`, `AddNewVocabulary`, etc.).                         |
| `sources_archive`            | Package for archiving source tables.                                                                                   |
| `vocabulary_download`        | Scripts for automatically downloading vocabularies.                                                                    |
| `vocabulary_pack`            | Advanced functions used in vocabulary processing (e.g., `ATCPostprocessing`, `AddFreshMAPSTO`, etc.).                  |
