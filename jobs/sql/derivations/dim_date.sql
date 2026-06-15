
SET NOCOUNT ON;

DROP TABLE IF EXISTS dim_date_staging;

CREATE TABLE [dim_date_staging]
	(	[DateKey] INT primary key,
		[Date] DATETIME,
		[FullDateUK] CHAR(10), -- Date in dd-MM-yyyy format
		[FullDateUSA] CHAR(10),-- Date in MM-dd-yyyy format
		[DayOfMonth] VARCHAR(2), -- Field will hold day number of Month
		[DaySuffix] VARCHAR(4), -- Apply suffix as 1st, 2nd ,3rd etc
		[DayName] VARCHAR(9), -- Contains name of the day, Sunday, Monday
		[DayOfWeekUSA] CHAR(1),-- First Day Sunday=1 and Saturday=7
		[DayOfWeekUK] CHAR(1),-- First Day Monday=1 and Sunday=7
		[DayOfWeekInMonth] VARCHAR(2), --1st Monday or 2nd Monday in Month
		[DayOfWeekInYear] VARCHAR(2),
		[DayOfQuarter] VARCHAR(3),
		[DayOfYear] VARCHAR(3),
		[WeekOfMonth] VARCHAR(1),-- Week Number of Month
		[WeekOfQuarter] VARCHAR(2), --Week Number of the Quarter
		[WeekOfYear] VARCHAR(2),--Week Number of the Year
		[Month] VARCHAR(2), --Number of the Month 1 to 12
		[MonthName] VARCHAR(9),--January, February etc
		[MonthOfQuarter] VARCHAR(2),-- Month Number belongs to Quarter
		[Quarter] CHAR(2),
		[QuarterName] VARCHAR(9),--First,Second..
		[Fiscal_Quarter] CHAR(2),
		[Year] CHAR(4),-- Year value of Date stored in Row
		[YearName] CHAR(7), --CY 2012,CY 2013
		[MonthYear] CHAR(10), --Jan-2013,Feb-2013
		[MMYYYY] CHAR(6),
		[FirstDayOfMonth] DATE,
		[LastDayOfMonth] DATE,
		[FirstDayOfQuarter] DATE,
		[LastDayOfQuarter] DATE,
		[FirstDayOfYear] DATE,
		[LastDayOfYear] DATE,
		[IsHolidayUSA] BIT,-- Flag 1=National Holiday, 0-No National Holiday
		[IsWeekday] BIT,-- 0=Week End ,1=Week Day
		[HolidayUSA] VARCHAR(50),--Name of Holiday in US
		[IsHolidayUK] BIT Null,-- Flag 1=National Holiday, 0-No National Holiday
		[HolidayUK] VARCHAR(50) Null --Name of Holiday in UK
	);

-- ------------------------------------------------------------------------------------

-- Replace the original WHILE loop with a single set-based INSERT.
-- A tally CTE (L0-L4) generates integers 0..65535 without looping;
-- ROW_NUMBER() window functions compute the per-weekday-in-month/quarter/year
-- counts that previously required the @DayOfWeek table variable and ~54k DML ops.
-- Date literals are inlined (not declared as variables) so petl can execute
-- this as a single self-contained statement.
WITH
L0   AS (SELECT 1 AS c UNION ALL SELECT 1),
L1   AS (SELECT 1 AS c FROM L0   A CROSS JOIN L0   B),
L2   AS (SELECT 1 AS c FROM L1   A CROSS JOIN L1   B),
L3   AS (SELECT 1 AS c FROM L2   A CROSS JOIN L2   B),
L4   AS (SELECT 1 AS c FROM L3   A CROSS JOIN L3   B),
nums AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n FROM L4),
dates AS (
    SELECT CAST(DATEADD(DAY, n, CAST('20130101' AS DATE)) AS DATE) AS dt
    FROM nums
    WHERE n < DATEDIFF(DAY, CAST('20130101' AS DATE), CAST('20500101' AS DATE))
),
base AS (
    SELECT
        dt,
        DATEPART(DW,   dt) AS dow,
        DATEPART(DD,   dt) AS dom,
        DATEPART(MM,   dt) AS mo,
        DATEPART(QQ,   dt) AS qtr,
        DATEPART(YEAR, dt) AS yr
    FROM dates
),
counted AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY yr, mo,  dow ORDER BY dt) AS dow_in_month,
        ROW_NUMBER() OVER (PARTITION BY yr, qtr, dow ORDER BY dt) AS dow_in_quarter,
        ROW_NUMBER() OVER (PARTITION BY yr,      dow ORDER BY dt) AS dow_in_year
    FROM base
)
INSERT INTO dim_date_staging (
    [DateKey], [Date], [FullDateUK], [FullDateUSA],
    [DayOfMonth], [DaySuffix], [DayName], [DayOfWeekUSA], [DayOfWeekUK],
    [DayOfWeekInMonth], [DayOfWeekInYear], [DayOfQuarter],
    [DayOfYear], [WeekOfMonth], [WeekOfQuarter], [WeekOfYear],
    [Month], [MonthName], [MonthOfQuarter], [Quarter], [QuarterName], [Fiscal_Quarter],
    [Year], [YearName], [MonthYear], [MMYYYY],
    [FirstDayOfMonth], [LastDayOfMonth],
    [FirstDayOfQuarter], [LastDayOfQuarter],
    [FirstDayOfYear], [LastDayOfYear],
    [IsHolidayUSA], [IsWeekday], [HolidayUSA], [IsHolidayUK], [HolidayUK]
)
SELECT
    CONVERT(char(8),  dt, 112)     AS DateKey,
    CAST(dt AS DATETIME)           AS [Date],
    CONVERT(char(10), dt, 103)     AS FullDateUK,
    CONVERT(char(10), dt, 101)     AS FullDateUSA,
    CAST(dom AS VARCHAR(2))        AS DayOfMonth,
    CASE
        WHEN dom IN (11,12,13)     THEN CAST(dom AS VARCHAR) + 'th'
        WHEN dom % 10 = 1          THEN CAST(dom AS VARCHAR) + 'st'
        WHEN dom % 10 = 2          THEN CAST(dom AS VARCHAR) + 'nd'
        WHEN dom % 10 = 3          THEN CAST(dom AS VARCHAR) + 'rd'
        ELSE                            CAST(dom AS VARCHAR) + 'th'
    END                            AS DaySuffix,
    DATENAME(DW, dt)               AS DayName,
    CAST(dow AS CHAR(1))           AS DayOfWeekUSA,
    CAST(CASE dow
        WHEN 1 THEN 7 WHEN 2 THEN 1 WHEN 3 THEN 2
        WHEN 4 THEN 3 WHEN 5 THEN 4 WHEN 6 THEN 5 WHEN 7 THEN 6
    END AS CHAR(1))                AS DayOfWeekUK,
    CAST(dow_in_month    AS VARCHAR(2)) AS DayOfWeekInMonth,
    CAST(dow_in_year     AS VARCHAR(2)) AS DayOfWeekInYear,
    CAST(dow_in_quarter  AS VARCHAR(3)) AS DayOfQuarter,
    CAST(DATEPART(DY, dt) AS VARCHAR(3))                                         AS DayOfYear,
    CAST(DATEPART(WW, dt) + 1 - DATEPART(WW, DATEFROMPARTS(yr, mo, 1))
         AS VARCHAR(1))            AS WeekOfMonth,
    CAST((DATEDIFF(DAY, DATEADD(QQ, DATEDIFF(QQ, 0, dt), 0), dt) / 7) + 1
         AS VARCHAR(2))            AS WeekOfQuarter,
    CAST(DATEPART(WW, dt) AS VARCHAR(2))                                         AS WeekOfYear,
    CAST(mo  AS VARCHAR(2))        AS [Month],
    DATENAME(MM, dt)               AS MonthName,
    CAST(CASE
        WHEN mo IN (1, 4, 7, 10)   THEN 1
        WHEN mo IN (2, 5, 8, 11)   THEN 2
        WHEN mo IN (3, 6, 9, 12)   THEN 3
    END AS VARCHAR(2))             AS MonthOfQuarter,
    'Q' + CAST(qtr AS CHAR(1))    AS Quarter,
    CASE qtr
        WHEN 1 THEN 'First'  WHEN 2 THEN 'Second'
        WHEN 3 THEN 'Third'  WHEN 4 THEN 'Fourth'
    END                            AS QuarterName,
    CASE
        WHEN mo BETWEEN 1  AND 3   THEN 'Q3'
        WHEN mo BETWEEN 4  AND 6   THEN 'Q4'
        WHEN mo BETWEEN 7  AND 9   THEN 'Q1'
        WHEN mo BETWEEN 10 AND 12  THEN 'Q2'
    END                            AS Fiscal_Quarter,
    CAST(yr AS CHAR(4))            AS [Year],
    'CY ' + CAST(yr AS VARCHAR)   AS YearName,
    LEFT(DATENAME(MM, dt), 3) + '-' + CAST(yr AS VARCHAR) AS MonthYear,
    RIGHT('0' + CAST(mo AS VARCHAR), 2) + CAST(yr AS VARCHAR) AS MMYYYY,
    DATEFROMPARTS(yr, mo, 1)       AS FirstDayOfMonth,
    EOMONTH(dt)                    AS LastDayOfMonth,
    CAST(DATEADD(QQ, DATEDIFF(QQ, 0,  dt), 0)  AS DATE) AS FirstDayOfQuarter,
    CAST(DATEADD(QQ, DATEDIFF(QQ, -1, dt), -1) AS DATE) AS LastDayOfQuarter,
    DATEFROMPARTS(yr, 1,  1)       AS FirstDayOfYear,
    DATEFROMPARTS(yr, 12, 31)      AS LastDayOfYear,
    NULL                           AS IsHolidayUSA,
    CAST(CASE dow WHEN 1 THEN 0 WHEN 7 THEN 0 ELSE 1 END AS BIT) AS IsWeekday,
    NULL                           AS HolidayUSA,
    NULL                           AS IsHolidayUK,
    NULL                           AS HolidayUK
FROM counted;

-- ------------------------------------------------------------------

-- Good Friday  April 18
UPDATE dim_date_staging
SET HolidayUK = 'Good Friday'
WHERE [Month] = 4 AND [DayOfMonth]  = 18

-- Easter Monday  April 21
UPDATE dim_date_staging
SET HolidayUK = 'Easter Monday'
WHERE [Month] = 4 AND [DayOfMonth]  = 21

-- Early May Bank Holiday   May 5
UPDATE dim_date_staging
SET HolidayUK = 'Early May Bank Holiday'
WHERE [Month] = 5 AND [DayOfMonth]  = 5

-- Spring Bank Holiday  May 26
UPDATE dim_date_staging
SET HolidayUK = 'Spring Bank Holiday'
WHERE [Month] = 5 AND [DayOfMonth]  = 26

-- Summer Bank Holiday  August 25
UPDATE dim_date_staging
SET HolidayUK = 'Summer Bank Holiday'
WHERE [Month] = 8 AND [DayOfMonth]  = 25

-- Boxing Day  December 26
UPDATE dim_date_staging
SET HolidayUK = 'Christmas Day'
WHERE [Month] = 12 AND [DayOfMonth]  = 25

--CHRISTMAS
UPDATE dim_date_staging
SET HolidayUK = 'Boxing Day'
WHERE [Month] = 12 AND [DayOfMonth]  = 26

--New Years Day
UPDATE dim_date_staging
SET HolidayUK  = 'New Year''s Day'
WHERE [Month] = 1 AND [DayOfMonth] = 1

-- Update flag for UK Holidays 1= Holiday, 0=No Holiday

UPDATE dim_date_staging
SET IsHolidayUK  = CASE WHEN HolidayUK   IS NULL THEN 0 WHEN HolidayUK   IS NOT NULL THEN 1 END


-- -----------------------------------------------------------

UPDATE dim_date_staging
SET HolidayUSA = 'Thanksgiving Day'
WHERE
    [Month] = 11
  AND [DayOfWeekUSA] = '5'
  AND DayOfWeekInMonth = 4

-- ------ CHRISTMAS -----------------
UPDATE dim_date_staging
SET HolidayUSA = 'Christmas Day'

WHERE [Month] = 12 AND [DayOfMonth]  = 25

-- ---------- 4th of July ---------------
UPDATE dim_date_staging
SET HolidayUSA = 'Independance Day'
WHERE [Month] = 7 AND [DayOfMonth] = 4

-- ------------ New Years Day ---------
UPDATE dim_date_staging
SET HolidayUSA = 'New Year''s Day'
WHERE [Month] = 1 AND [DayOfMonth] = 1

-- ----------------------------
UPDATE dim_date_staging
SET HolidayUSA = 'Memorial Day'
    FROM dim_date_staging
WHERE DateKey IN
    (
    SELECT
    MAX(DateKey)
    FROM dim_date_staging
    WHERE
    [MonthName] = 'May'
  AND [DayOfWeekUSA]  = '2'
    GROUP BY
    [Year],
    [Month]
    )

-- --------- Labor Day - First Monday in September ----------
UPDATE dim_date_staging
SET HolidayUSA = 'Labor Day'
    FROM dim_date_staging
WHERE DateKey IN
    (
    SELECT
    MIN(DateKey)
    FROM dim_date_staging
    WHERE
    [MonthName] = 'September'
  AND [DayOfWeekUSA] = '2'
    GROUP BY
    [Year],
    [Month]
    )

-- --------------- Valentine's Day ----------------
UPDATE dim_date_staging
SET HolidayUSA = 'Valentine''s Day'
WHERE
    [Month] = 2
  AND [DayOfMonth] = 14

-- ------------ Saint Patrick's Day ------------
UPDATE dim_date_staging
SET HolidayUSA = 'Saint Patrick''s Day'
WHERE
    [Month] = 3
  AND [DayOfMonth] = 17

-- ------------ Martin Luthor King Day - Third Monday in January starting in 1983*/
UPDATE dim_date_staging
SET HolidayUSA = 'Martin Luthor King Jr Day'
WHERE
    [Month] = 1
  AND [DayOfWeekUSA]  = '2'
  AND [Year] >= 1983
  AND DayOfWeekInMonth = 3

-- ------------- President's Day - Third Monday in February ----------
UPDATE dim_date_staging
SET HolidayUSA = 'President''s Day'
WHERE
    [Month] = 2
  AND [DayOfWeekUSA] = '2'
  AND DayOfWeekInMonth = 3

-- --------------- Mother's Day - Second Sunday of May -------------------
UPDATE dim_date_staging
SET HolidayUSA = 'Mother''s Day'
WHERE
    [Month] = 5
  AND [DayOfWeekUSA] = '1'
  AND DayOfWeekInMonth = 2

-- -------------- Father's Day - Third Sunday of June -------------
UPDATE dim_date_staging
SET HolidayUSA = 'Father''s Day'
WHERE
    [Month] = 6
  AND [DayOfWeekUSA] = '1'
  AND DayOfWeekInMonth = 3

-- ------------------- Halloween 10/31 ---------------------
UPDATE dim_date_staging
SET HolidayUSA = 'Halloween'
WHERE
    [Month] = 10
  AND [DayOfMonth] = 31

-- ------------ Election Day - The first Tuesday after the first Monday in November -------------
UPDATE dim_date_staging
SET HolidayUSA = 'Election Day'
WHERE DateKey IN (
    SELECT CONVERT(char(8), DATEADD(DAY, 1,
        -- first Monday of November for each year
        DATEADD(DAY, (9 - DATEPART(DW, DATEFROMPARTS(CAST([Year] AS INT), 11, 1))) % 7,
                DATEFROMPARTS(CAST([Year] AS INT), 11, 1))
    ), 112)
    FROM dim_date_staging
    GROUP BY [Year]
)

--set flag for USA holidays in Dimension
UPDATE dim_date_staging
SET IsHolidayUSA = CASE WHEN HolidayUSA  IS NULL THEN 0 WHEN HolidayUSA  IS NOT NULL THEN 1 END

-- ------------------------------------------------------------------------------------

DROP TABLE IF EXISTS dim_date;
EXEC sp_rename 'dim_date_staging', 'dim_date';
