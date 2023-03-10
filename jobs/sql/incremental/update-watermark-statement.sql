insert into petl_incremental_update_log
    (table_name, partition_num, starting_watermark, ending_watermark, completed_datetime)
values
    ('${tableName}', ${partitionNum}, @previousWatermark, @newWatermark, getdate())
;
