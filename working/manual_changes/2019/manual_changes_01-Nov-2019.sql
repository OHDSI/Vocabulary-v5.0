--rename some SNOMED relationships

--'Has method (SNOMED)' => 'Has method'
do $$
declare
	rel_concept_id int4:=44818751;
begin
	update concept c set concept_name=r.relationship_id
	from relationship r
	where r.relationship_concept_id=c.concept_id
	and r.relationship_concept_id=rel_concept_id;
	
	update relationship r set relationship_name=r.relationship_id where r.relationship_concept_id=rel_concept_id;
	
	--reverse
	update concept c set concept_name=r.relationship_id
	from (
		select r2.* from relationship r1, relationship r2
		where r1.relationship_concept_id=rel_concept_id
		and r2.relationship_id=r1.reverse_relationship_id
	) r
	where r.relationship_concept_id=c.concept_id;
	
	update relationship r set relationship_name=r.relationship_id
	from relationship r1
	where r1.relationship_concept_id=rel_concept_id
	and r.relationship_id=r1.reverse_relationship_id;
end $$;

--'Has property type (SNOMED)' => 'Has property type'
do $$
declare
	rel_concept_id int4:=5075;
begin
	update concept c set concept_name=r.relationship_id
	from relationship r
	where r.relationship_concept_id=c.concept_id
	and r.relationship_concept_id=rel_concept_id;
	
	update relationship r set relationship_name=r.relationship_id where r.relationship_concept_id=rel_concept_id;
	
	--reverse
	update concept c set concept_name=r.relationship_id
	from (
		select r2.* from relationship r1, relationship r2
		where r1.relationship_concept_id=rel_concept_id
		and r2.relationship_id=r1.reverse_relationship_id
	) r
	where r.relationship_concept_id=c.concept_id;
	
	update relationship r set relationship_name=r.relationship_id
	from relationship r1
	where r1.relationship_concept_id=rel_concept_id
	and r.relationship_id=r1.reverse_relationship_id;
end $$;

--'Has time aspect (SNOMED)' => 'Has time aspect'
do $$
declare
	rel_concept_id int4:=44818774;
begin
	update concept c set concept_name=r.relationship_id
	from relationship r
	where r.relationship_concept_id=c.concept_id
	and r.relationship_concept_id=rel_concept_id;
	
	update relationship r set relationship_name=r.relationship_id where r.relationship_concept_id=rel_concept_id;
	
	--reverse
	update concept c set concept_name=r.relationship_id
	from (
		select r2.* from relationship r1, relationship r2
		where r1.relationship_concept_id=rel_concept_id
		and r2.relationship_id=r1.reverse_relationship_id
	) r
	where r.relationship_concept_id=c.concept_id;
	
	update relationship r set relationship_name=r.relationship_id
	from relationship r1
	where r1.relationship_concept_id=rel_concept_id
	and r.relationship_id=r1.reverse_relationship_id;
end $$;

--'Has component (SNOMED)' => 'Has component'
do $$
declare
	rel_concept_id int4:=44818767;
begin
	update concept c set concept_name=r.relationship_id
	from relationship r
	where r.relationship_concept_id=c.concept_id
	and r.relationship_concept_id=rel_concept_id;
	
	update relationship r set relationship_name=r.relationship_id where r.relationship_concept_id=rel_concept_id;
	
	--reverse
	update concept c set concept_name=r.relationship_id
	from (
		select r2.* from relationship r1, relationship r2
		where r1.relationship_concept_id=rel_concept_id
		and r2.relationship_id=r1.reverse_relationship_id
	) r
	where r.relationship_concept_id=c.concept_id;
	
	update relationship r set relationship_name=r.relationship_id
	from relationship r1
	where r1.relationship_concept_id=rel_concept_id
	and r.relationship_id=r1.reverse_relationship_id;
end $$;

--'Has scale type (SNOMED)' => 'Has scale type'
do $$
declare
	rel_concept_id int4:=44818773;
begin
	update concept c set concept_name=r.relationship_id
	from relationship r
	where r.relationship_concept_id=c.concept_id
	and r.relationship_concept_id=rel_concept_id;
	
	update relationship r set relationship_name=r.relationship_id where r.relationship_concept_id=rel_concept_id;
	
	--reverse
	update concept c set concept_name=r.relationship_id
	from (
		select r2.* from relationship r1, relationship r2
		where r1.relationship_concept_id=rel_concept_id
		and r2.relationship_id=r1.reverse_relationship_id
	) r
	where r.relationship_concept_id=c.concept_id;
	
	update relationship r set relationship_name=r.relationship_id
	from relationship r1
	where r1.relationship_concept_id=rel_concept_id
	and r.relationship_id=r1.reverse_relationship_id;
end $$;