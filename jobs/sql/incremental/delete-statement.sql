delete t from ${tableName}_${partitionNum} t
inner join patient_last_update_date d on t.patient_id = d.patient_id
where d.partition_num = ${partitionNum}
and d.last_updated >= @previousWatermark
and d.last_updated <= @newWatermark
;