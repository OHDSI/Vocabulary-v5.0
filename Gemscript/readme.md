1. Run fastrecreateschema() function including concept_ancestor creation.
2. Update source files:
	a. thin_gemsc_dmd -- THIN source
	b. gemscript_reference -- NN source
	c. gemscript_dmd_map -- unknown origin, never updated
3. Run load_stage.sql. Supply manual changes to mapping tables if required
4. Run Build_RxE.sql from /working/. Comment drops block to preserve temporary tables
5. Run mapdrugvovab.sql from /working/
6. Run final_part.sql to preserve mappings to SNOMED and dm+d

TODO: Update against most recent THIN source available