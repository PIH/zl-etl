
DROP TABLE IF EXISTS Dim_Date;

CREATE TABLE [Dim_Date]
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
		[Quarter] CHAR(1),
		[QuarterName] VARCHAR(9),--First,Second..
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
	)

-- ------------------------------------------------------------------------------------

DECLARE @StartDate DATETIME = '01/01/2013'
DECLARE @EndDate DATETIME = '01/01/2050'

DECLARE
@DayOfWeekInMonth INT,
	@DayOfWeekInYear INT,
	@DayOfQuarter INT,
	@WeekOfMonth INT,
	@CurrentYear INT,
	@CurrentMonth INT,
	@CurrentQuarter INT


DECLARE @DayOfWeek TABLE (DOW INT, MonthCount INT, QuarterCount INT, YearCount INT)

INSERT INTO @DayOfWeek VALUES (1, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (2, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (3, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (4, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (5, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (6, 0, 0, 0)
INSERT INTO @DayOfWeek VALUES (7, 0, 0, 0)


DECLARE @CurrentDate AS DATETIME = @StartDate
SET @CurrentMonth = DATEPART(MM, @CurrentDate)
SET @CurrentYear = DATEPART(YY, @CurrentDate)
SET @CurrentQuarter = DATEPART(QQ, @CurrentDate)

-- --------------------------------------------------------------------------------

WHILE @CurrentDate < @EndDate
BEGIN


	IF @CurrentMonth != DATEPART(MM, @CurrentDate)
BEGIN
UPDATE @DayOfWeek
SET MonthCount = 0
    SET @CurrentMonth = DATEPART(MM, @CurrentDate)
END

	IF @CurrentQuarter != DATEPART(QQ, @CurrentDate)
BEGIN
UPDATE @DayOfWeek
SET QuarterCount = 0
    SET @CurrentQuarter = DATEPART(QQ, @CurrentDate)
END


	IF @CurrentYear != DATEPART(YY, @CurrentDate)
BEGIN
UPDATE @DayOfWeek
SET YearCount = 0
    SET @CurrentYear = DATEPART(YY, @CurrentDate)
END


UPDATE @DayOfWeek
SET
    MonthCount = MonthCount + 1,
    QuarterCount = QuarterCount + 1,
    YearCount = YearCount + 1
WHERE DOW = DATEPART(DW, @CurrentDate)

SELECT
        @DayOfWeekInMonth = MonthCount,
        @DayOfQuarter = QuarterCount,
        @DayOfWeekInYear = YearCount
FROM @DayOfWeek
WHERE DOW = DATEPART(DW, @CurrentDate)


    INSERT INTO Dim_Date
SELECT

    CONVERT (char(8),@CurrentDate,112) as DateKey,
    @CurrentDate AS Date,
		CONVERT (char(10),@CurrentDate,103) as FullDateUK,
		CONVERT (char(10),@CurrentDate,101) as FullDateUSA,
		DATEPART(DD, @CurrentDate) AS DayOfMonth,
		CASE
			WHEN DATEPART(DD,@CurrentDate) IN (11,12,13)
			THEN CAST(DATEPART(DD,@CurrentDate) AS VARCHAR) + 'th'
			WHEN RIGHT(DATEPART(DD,@CurrentDate),1) = 1
			THEN CAST(DATEPART(DD,@CurrentDate) AS VARCHAR) + 'st'
			WHEN RIGHT(DATEPART(DD,@CurrentDate),1) = 2
			THEN CAST(DATEPART(DD,@CurrentDate) AS VARCHAR) + 'nd'
			WHEN RIGHT(DATEPART(DD,@CurrentDate),1) = 3
			THEN CAST(DATEPART(DD,@CurrentDate) AS VARCHAR) + 'rd'
			ELSE CAST(DATEPART(DD,@CurrentDate) AS VARCHAR) + 'th'
END AS DaySuffix,

		DATENAME(DW, @CurrentDate) AS DayName,
		DATEPART(DW, @CurrentDate) AS DayOfWeekUSA,

		CASE DATEPART(DW, @CurrentDate)
			WHEN 1 THEN 7
			WHEN 2 THEN 1
			WHEN 3 THEN 2
			WHEN 4 THEN 3
			WHEN 5 THEN 4
			WHEN 6 THEN 5
			WHEN 7 THEN 6
END
AS DayOfWeekUK,

		@DayOfWeekInMonth AS DayOfWeekInMonth,
		@DayOfWeekInYear AS DayOfWeekInYear,
		@DayOfQuarter AS DayOfQuarter,
		DATEPART(DY, @CurrentDate) AS DayOfYear,
		DATEPART(WW, @CurrentDate) + 1 - DATEPART(WW, CONVERT(VARCHAR,DATEPART(MM, @CurrentDate)) + '/1/' + CONVERT(VARCHAR,DATEPART(YY, @CurrentDate))) AS WeekOfMonth,
		(DATEDIFF(DD, DATEADD(QQ, DATEDIFF(QQ, 0, @CurrentDate), 0), @CurrentDate) / 7) + 1 AS WeekOfQuarter,
		DATEPART(WW, @CurrentDate) AS WeekOfYear,
		DATEPART(MM, @CurrentDate) AS Month,
		DATENAME(MM, @CurrentDate) AS MonthName,
		CASE
			WHEN DATEPART(MM, @CurrentDate) IN (1, 4, 7, 10) THEN 1
			WHEN DATEPART(MM, @CurrentDate) IN (2, 5, 8, 11) THEN 2
			WHEN DATEPART(MM, @CurrentDate) IN (3, 6, 9, 12) THEN 3
END AS MonthOfQuarter,
		DATEPART(QQ, @CurrentDate) AS Quarter,
		CASE DATEPART(QQ, @CurrentDate)
			WHEN 1 THEN 'First'
			WHEN 2 THEN 'Second'
			WHEN 3 THEN 'Third'
			WHEN 4 THEN 'Fourth'
END AS QuarterName,
		DATEPART(YEAR, @CurrentDate) AS Year,
		'CY ' + CONVERT(VARCHAR, DATEPART(YEAR, @CurrentDate)) AS YearName,
		LEFT(DATENAME(MM, @CurrentDate), 3) + '-' + CONVERT(VARCHAR, DATEPART(YY, @CurrentDate)) AS MonthYear,
		RIGHT('0' + CONVERT(VARCHAR, DATEPART(MM, @CurrentDate)),2) + CONVERT(VARCHAR, DATEPART(YY, @CurrentDate)) AS MMYYYY,
		CONVERT(DATETIME, CONVERT(DATE, DATEADD(DD, - (DATEPART(DD, @CurrentDate) - 1), @CurrentDate))) AS FirstDayOfMonth,
		CONVERT(DATETIME, CONVERT(DATE, DATEADD(DD, - (DATEPART(DD, (DATEADD(MM, 1, @CurrentDate)))), DATEADD(MM, 1, @CurrentDate)))) AS LastDayOfMonth,
		DATEADD(QQ, DATEDIFF(QQ, 0, @CurrentDate), 0) AS FirstDayOfQuarter,
		DATEADD(QQ, DATEDIFF(QQ, -1, @CurrentDate), -1) AS LastDayOfQuarter,
		CONVERT(DATETIME, '01/01/' + CONVERT(VARCHAR, DATEPART(YY, @CurrentDate))) AS FirstDayOfYear,
		CONVERT(DATETIME, '12/31/' + CONVERT(VARCHAR, DATEPART(YY, @CurrentDate))) AS LastDayOfYear,
		NULL AS IsHolidayUSA,
		CASE DATEPART(DW, @CurrentDate)
			WHEN 1 THEN 0
			WHEN 2 THEN 1
			WHEN 3 THEN 1
			WHEN 4 THEN 1
			WHEN 5 THEN 1
			WHEN 6 THEN 1
			WHEN 7 THEN 0
END AS IsWeekday,
		NULL AS HolidayUSA, Null, Null

	SET @CurrentDate = DATEADD(DD, 1, @CurrentDate)
END

-- ------------------------------------------------------------------

-- Good Friday  April 18
UPDATE Dim_Date
SET HolidayUK = 'Good Friday'
WHERE [Month] = 4 AND [DayOfMonth]  = 18

-- Easter Monday  April 21
UPDATE Dim_Date
SET HolidayUK = 'Easter Monday'
WHERE [Month] = 4 AND [DayOfMonth]  = 21

-- Early May Bank Holiday   May 5
UPDATE Dim_Date
SET HolidayUK = 'Early May Bank Holiday'
WHERE [Month] = 5 AND [DayOfMonth]  = 5

-- Spring Bank Holiday  May 26
UPDATE Dim_Date
SET HolidayUK = 'Spring Bank Holiday'
WHERE [Month] = 5 AND [DayOfMonth]  = 26

-- Summer Bank Holiday  August 25
UPDATE Dim_Date
SET HolidayUK = 'Summer Bank Holiday'
WHERE [Month] = 8 AND [DayOfMonth]  = 25

-- Boxing Day  December 26
UPDATE Dim_Date
SET HolidayUK = 'Boxing Day'
WHERE [Month] = 12 AND [DayOfMonth]  = 26

--CHRISTMAS
UPDATE Dim_Date
SET HolidayUK = 'Christmas Day'
WHERE [Month] = 12 AND [DayOfMonth]  = 25

--New Years Day
UPDATE Dim_Date
SET HolidayUK  = 'New Year''s Day'
WHERE [Month] = 1 AND [DayOfMonth] = 1

-- Update flag for UK Holidays 1= Holiday, 0=No Holiday

UPDATE Dim_Date
SET IsHolidayUK  = CASE WHEN HolidayUK   IS NULL THEN 0 WHEN HolidayUK   IS NOT NULL THEN 1 END


-- -----------------------------------------------------------

UPDATE Dim_Date
SET HolidayUSA = 'Thanksgiving Day'
WHERE
    [Month] = 11
  AND [DayOfWeekUSA] = 'Thursday'
  AND DayOfWeekInMonth = 4

-- ------ CHRISTMAS -----------------
UPDATE Dim_Date
SET HolidayUSA = 'Christmas Day'

WHERE [Month] = 12 AND [DayOfMonth]  = 25

-- ---------- 4th of July ---------------
UPDATE Dim_Date
SET HolidayUSA = 'Independance Day'
WHERE [Month] = 7 AND [DayOfMonth] = 4

-- ------------ New Years Day ---------
UPDATE Dim_Date
SET HolidayUSA = 'New Year''s Day'
WHERE [Month] = 1 AND [DayOfMonth] = 1

-- ----------------------------
UPDATE Dim_Date
SET HolidayUSA = 'Memorial Day'
    FROM Dim_Date
WHERE DateKey IN
    (
    SELECT
    MAX(DateKey)
    FROM Dim_Date
    WHERE
    [MonthName] = 'May'
  AND [DayOfWeekUSA]  = 'Monday'
    GROUP BY
    [Year],
    [Month]
    )

-- --------- Labor Day - First Monday in September ----------
UPDATE Dim_Date
SET HolidayUSA = 'Labor Day'
    FROM Dim_Date
WHERE DateKey IN
    (
    SELECT
    MIN(DateKey)
    FROM Dim_Date
    WHERE
    [MonthName] = 'September'
  AND [DayOfWeekUSA] = 'Monday'
    GROUP BY
    [Year],
    [Month]
    )

-- --------------- Valentine's Day ----------------
UPDATE Dim_Date
SET HolidayUSA = 'Valentine''s Day'
WHERE
    [Month] = 2
  AND [DayOfMonth] = 14

-- ------------ Saint Patrick's Day ------------
UPDATE Dim_Date
SET HolidayUSA = 'Saint Patrick''s Day'
WHERE
    [Month] = 3
  AND [DayOfMonth] = 17

-- ------------ Martin Luthor King Day - Third Monday in January starting in 1983*/
UPDATE Dim_Date
SET HolidayUSA = 'Martin Luthor King Jr Day'
WHERE
    [Month] = 1
  AND [DayOfWeekUSA]  = 'Monday'
  AND [Year] >= 1983
  AND DayOfWeekInMonth = 3

-- ------------- President's Day - Third Monday in February ----------
UPDATE Dim_Date
SET HolidayUSA = 'President''s Day'
WHERE
    [Month] = 2
  AND [DayOfWeekUSA] = 'Monday'
  AND DayOfWeekInMonth = 3

-- --------------- Mother's Day - Second Sunday of May -------------------
UPDATE Dim_Date
SET HolidayUSA = 'Mother''s Day'
WHERE
    [Month] = 5
  AND [DayOfWeekUSA] = 'Sunday'
  AND DayOfWeekInMonth = 2

-- -------------- Father's Day - Third Sunday of June -------------
UPDATE Dim_Date
SET HolidayUSA = 'Father''s Day'
WHERE
    [Month] = 6
  AND [DayOfWeekUSA] = 'Sunday'
  AND DayOfWeekInMonth = 3

-- ------------------- Halloween 10/31 ---------------------
UPDATE Dim_Date
SET HolidayUSA = 'Halloween'
WHERE
    [Month] = 10
  AND [DayOfMonth] = 31

-- ------------ Election Day - The first Tuesday after the first Monday in November -------------
BEGIN
	DECLARE @Holidays TABLE (ID INT IDENTITY(1,1), DateID int, Week TINYINT, YEAR CHAR(4), DAY CHAR(2))

		INSERT INTO @Holidays(DateID, [Year],[Day])
SELECT
    DateKey,
    [Year],
    [DayOfMonth]
FROM Dim_Date
WHERE
    [Month] = 11
  AND [DayOfWeekUSA] = 'Monday'
ORDER BY
    YEAR,
    DayOfMonth

DECLARE @CNTR INT, @POS INT, @STARTYEAR INT, @ENDYEAR INT, @MINDAY INT

SELECT
        @CURRENTYEAR = MIN([Year])
     , @STARTYEAR = MIN([Year])
     , @ENDYEAR = MAX([Year])
FROM @Holidays

         WHILE @CURRENTYEAR <= @ENDYEAR
BEGIN
SELECT @CNTR = COUNT([Year])
FROM @Holidays
WHERE [Year] = @CURRENTYEAR

SET @POS = 1

    WHILE @POS <= @CNTR
BEGIN
SELECT @MINDAY = MIN(DAY)
FROM @Holidays
WHERE
    [Year] = @CURRENTYEAR
  AND [Week] IS NULL

UPDATE @Holidays
SET [Week] = @POS
WHERE
    [Year] = @CURRENTYEAR
  AND [Day] = @MINDAY

SELECT @POS = @POS + 1
END

SELECT @CURRENTYEAR = @CURRENTYEAR + 1
END

UPDATE Dim_Date
SET HolidayUSA  = 'Election Day'
    FROM Dim_Date DT
			JOIN @Holidays HL ON (HL.DateID + 1) = DT.DateKey
WHERE
    [Week] = 1
END
	--set flag for USA holidays in Dimension
UPDATE Dim_Date
SET IsHolidayUSA = CASE WHEN HolidayUSA  IS NULL THEN 0 WHEN HolidayUSA  IS NOT NULL THEN 1 END