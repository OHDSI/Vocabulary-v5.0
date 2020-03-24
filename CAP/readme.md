CAP vocabulary

Overview

Snapshot of CAP (College of American Pathologists) eCC protocols for Breast Cancer is implemented as a non-standardized Vocabulary for the purpose of having a set of concepts to capture relevant pathological report data.

                                                    Source
XML files provided by CAP were used to retrieve the data.
The source items hierarchy,  was applied to subsequent concept relationships creation and formulation of essential concept names.

                                                    Concept characteristics
    Concept code
A numeric value (C-key) originated from the source was used as a source code.
The only exception - manually created CAP (as modifications of the source file name)  protocols codes


    Concept name
Descriptions attached to distinct codes were designated as their names.

    Alternative concept name
To preserve a maximum of relevant source data we propose to maintain parental relationships in name as a sequence separated by ‘|’-symbol, putting them in concept_synonym_stage table.
The left flanking word in this sequence is an exact concept_name, all the right-handed words are parents for it.
These names are inserted into synonym table.


    Domains and Concept Classes
Concepts in CAP vocabulary belong to one of three Domains:

Observation concepts describe items providing information from which distinct protocol (‘CAP protocol’) or from which variables-values logic group (‘CAP header’) it originates from.

Meas Value domain contains ‘CAP value’ class concepts somehow corresponding to distinct clinical entities.

The Measurement domain is represented by ‘CAP variable’ concepts expressing the meaning of report question-element.

The recognition of Domains and Classes performed on the bases of alphabetical HTML-tags assigned to source codes according to the only rule 'Distance' containing names should be assigned as Variables.
note
#  ‘DI’ source tag was considered by us (vocabulary team) as a comment guiding a pathologist performing the report
and is not significant for Observational research, so were not included into release.
* CAP Protocol classes were created manually from XML-source files




                                                Intravocabulary items Relationships
As for now, CAP vocabulary includes only a set of hierarchical and attributive relationships:
1)linking CAP values to their parental variables,
2) sharing the structure of protocol,
3) representing simple child-parental relations






