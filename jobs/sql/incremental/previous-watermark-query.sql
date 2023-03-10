select  max(l.ending_watermark)
from    petl_incremental_update_log l
where   l.table_name = '${tableName}'
and     l.partition_num = ${partitionNum}
;
