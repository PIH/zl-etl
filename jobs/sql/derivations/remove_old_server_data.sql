-- Remove rows loaded from servers that are no longer refreshed (e.g. Cange, merged into ZL Central),
-- so their stale data doesn't linger in the warehouse or duplicate patients now loaded from another server.
-- For every warehouse table that has a "server" column, delete rows from the retired servers.
-- Table list is discovered dynamically via catalog views so new tables are covered automatically.
-- NOTE: kept as a single statement (no semicolons) so petl's ";" delimiter split
-- doesn't separate the DECLARE/SELECT/EXEC into independent, variable-less batches
-- (see sql/derivations/force_site_for_hiv_server.sql).
DECLARE @sql NVARCHAR(MAX) = N''

-- generate a DELETE statement for each table that has a "server" column
SELECT @sql = @sql + N'
DELETE FROM ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N'
WHERE server IN (''cange'')
'
FROM sys.tables t
INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE EXISTS (SELECT 1 FROM sys.columns c WHERE c.object_id = t.object_id AND c.name = 'server')

-- execute the generated DELETE statements
EXEC sp_executesql @sql
