-- Hack: for every warehouse table that has both a "site" and a "server" column,
-- force site = 'hiv' wherever server = 'hiv', overriding whatever the table's own
-- extraction/derivation logic computed for site. Table list is discovered dynamically
-- via catalog views so new tables are covered automatically.
-- NOTE: kept as a single statement (no semicolons) so petl's ";" delimiter split
-- doesn't separate the DECLARE/SELECT/EXEC into independent, variable-less batches
-- (see the equivalent constraint documented in sql/derivations/dim_date.sql).
DECLARE @sql NVARCHAR(MAX) = N''

-- generate an UPDATE statement for each table that has both a "site" and a "server" column
SELECT @sql = @sql + N'
UPDATE ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N'
SET site = ''hiv''
WHERE server = ''hiv''
'
FROM sys.tables t
INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE EXISTS (SELECT 1 FROM sys.columns c WHERE c.object_id = t.object_id AND c.name = 'site')
  AND EXISTS (SELECT 1 FROM sys.columns c WHERE c.object_id = t.object_id AND c.name = 'server')

-- execute the generated UPDATE statements
EXEC sp_executesql @sql
