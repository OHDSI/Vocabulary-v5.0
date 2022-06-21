do $$
declare
r record;
main_group text[];
new_grp text[];
was_found boolean:=true;
begin
 create temp table aggregated_groups on commit drop as
 select array[scd] as grp_main, array_agg(distinct sc) as grp
 from --table from dataset
 group by scd;
 while was_found loop --we will collapse the groups until there is one common group for each scd (grp_main)
   was_found:=false;
   for r in (select * from aggregated_groups) loop
     select array_agg(u.grp_main) filter (where u.grp_main is not null) as grp_main, array_agg(distinct /*deduplication inside groups*/ u.grp) filter (where u.grp is not null) as grp
     into main_group, new_grp
     from aggregated_groups ag
    cross join unnest (ag.grp_main || r.grp_main, ag.grp || r.grp) as u(grp_main,grp) --aggregate all arrays into new one, so we use unnest+array_agg
     where ag.grp_main<>r.grp_main and ag.grp && r.grp;
     if main_group is not null then
       --remove processed groups
       delete from aggregated_groups where grp_main && main_group;
       --add new merged group
       insert into aggregated_groups values (main_group, new_grp);
       was_found:=true; --set the flag, continue the original iteration
       exit; --exit from the current cycle
     end if;
   end loop;
 end loop;
end $$
