DROP VIEW if exists current_pipeline_summary;
CREATE VIEW current_pipeline_summary AS
select max(cast(jparent.initiated as date)) as run_date,
  max(j.status) as status,
  count(*) as count,
  null as description, 
  null as error_message,
  min(j.started) as started,
  max(j.completed) as completed,
  null as uuid,
  null as parent_child,
  max(jparent.uuid) as parent_uuid
from petl_job_execution j 
inner join petl_job_execution jparent on jparent.uuid =
	(select top 1 uuid from petl_job_execution pje 
	where description in ('Refreshing HUMCI data','Refreshing ZL data')
	order by initiated desc)
where j.initiated >= jparent.initiated 
and j.status = 'SUCCEEDED'
group by j.status

union

select cast(jparent.initiated as date),
  j.status,
  null,
  j.description, 
  j.error_message,
  j.started,
  j.completed,
  j.uuid,
CASE 
	when ((j.description like 'Importing from%' and j.description like '% to %') or (j.description like 'Creating derived%')) 
	   then 'child'
	else 'parent'
END,
jparent.uuid as parent_uuid
from petl_job_execution j 
inner join petl_job_execution jparent on jparent.uuid =
	(select top 1 uuid from petl_job_execution pje 
	where description in ('Refreshing HUMCI data','Refreshing ZL data')
	order by initiated desc)
where j.initiated >= jparent.initiated 
and j.status <> 'SUCCEEDED';
