USE [SiriusSQL_Reporting]
GO
/****** Object:  StoredProcedure [dbo].[_ss_SalesPerfByPeriod_ModSSPerfReport]    Script Date: 8/28/2018 3:40:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[_ss_SalesPerfByPeriod_ModSSPerfReport]
-- =============================================
-- Create date: 2018-08-28 SJP
-- Original create date: 2012-02-27
-- Modify date: 
-- Description: Returns data for Sales Performance By Period Report
--    modified for Snowsports performance report
-- =============================================
(
  @pdtStart	  DATETIME,
  @pdtEnd		  DATETIME,
  @pvcPeriod	VARCHAR(16),
  @pvcItem    VARCHAR(MAX),
  @pvcSalespointFilter VARCHAR(10),
  @pvcSalespointIndex  VARCHAR(MAX),
  @pvcOperatorFilter   VARCHAR(10),
  @pvcOperatorIndex    VARCHAR(MAX)
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @dtEnd DATETIME
SET @dtEnd = CASE WHEN DATEPART(HOUR, @pdtEnd) = 0 
						       AND DATEPART(MINUTE, @pdtEnd) = 0
						       AND DATEPART(SECOND, @pdtEnd) = 0
					        THEN @pdtEnd + ' 23:59:59.997' 
					        ELSE @pdtEnd 
             END
--==============================================
IF OBJECT_ID('tempdb..#DCI') IS NOT NULL DROP TABLE #DCI
CREATE TABLE #DCI
(
  Department CHAR(10) COLLATE DATABASE_DEFAULT,
  Category   CHAR(10) COLLATE DATABASE_DEFAULT,
  Item       CHAR(10) COLLATE DATABASE_DEFAULT
)
INSERT INTO #DCI
SELECT LEFT(Item,10), 
       SUBSTRING(Item,11,10), 
       SUBSTRING(Item,21,10) -- TG(23981)
  FROM SiriusSQL.dbo.siriusfn_SplitMultiValue(@pvcItem, ',')
--==============================================
IF OBJECT_ID('tempdb..#Salespoints') IS NOT NULL DROP TABLE #Salespoints
CREATE TABLE #Salespoints (salespoint CHAR(6) COLLATE DATABASE_DEFAULT)

INSERT INTO #Salespoints
SELECT sp.salespoint		                    
	FROM SiriusSQL.dbo.sales_pt sp
 WHERE @pvcSalespointFilter = 'salespoint'
   AND sp.salespoint IN (SELECT item FROM SiriusSQL.dbo.siriusfn_SplitMultiValue(@pvcSalespointIndex, ','))
 UNION
SELECT DISTINCT sl.salespoint
	FROM SiriusSQL.dbo.sp_link sl
 WHERE @pvcSalespointFilter = 'sp_group'
   AND sl.group_no IN (SELECT CAST(item AS VARCHAR) AS group_no FROM SiriusSQL.dbo.siriusfn_SplitMultiValue(@pvcSalespointIndex, ','))
--==============================================
IF OBJECT_ID('tempdb..#Operators') IS NOT NULL DROP TABLE #Operators
CREATE TABLE #Operators (operator CHAR(6) COLLATE DATABASE_DEFAULT) 
     
INSERT INTO #Operators
SELECT o.op_code		                  
  FROM SiriusSQL.dbo.operator o
 WHERE @pvcOperatorFilter = 'operator'
   AND o.op_code IN (SELECT item FROM SiriusSQL.dbo.siriusfn_SplitMultiValue(@pvcOperatorIndex, ','))
 UNION
SELECT DISTINCT ol.op_code
  FROM SiriusSQL.dbo.op_link ol
 WHERE @pvcOperatorFilter = 'op_group'
   AND ol.group_no IN (SELECT CAST(item AS VARCHAR) AS group_no FROM SiriusSQL.dbo.siriusfn_SplitMultiValue(@pvcOperatorIndex, ','))			  
--==============================================	
DECLARE @iWeekStart INT, 
        @vcNewLine VARCHAR(2)
SELECT @iWeekStart = MAX(weekstarts) FROM SiriusSQL.dbo.prefs
SET @vcNewLine = CHAR(13) + CHAR(10)	  
--==============================================					 
DECLARE @vcSQL NVARCHAR(MAX)
SET @vcSQL = 'SELECT' + /*CASE @pvcPeriod
                              WHEN 'HOUR'  THEN 'DATEPART(HOUR, t.date_time)'
                              WHEN 'DATE'  THEN 'CAST(CONVERT(CHAR(8), t.date_time, 112) AS INT)'
                              WHEN 'DAY'   THEN 'DATEPART(WEEKDAY, t.date_time) + CASE WHEN DATEPART(WEEKDAY, t.date_time) < @iWeekStart THEN 7 ELSE 0 END - @iWeekStart + 1'
                              WHEN 'MONTH' THEN 'CAST(CONVERT(CHAR(6), t.date_time, 112) AS INT)'
                              WHEN 'WEEK'  THEN */'CAST(CONVERT(CHAR(8), DATEADD(DAY, @iWeekStart - 1, DATEADD(WEEK, DATEDIFF(WEEK, 6, t.date_time), 6)), 112) AS INT)'
                         END + ' AS PeriodSort,' + @vcNewLine
           + '       ' + /*CASE @pvcPeriod
                              WHEN 'HOUR'  THEN 'REPLACE(LTRIM(RIGHT(CONVERT(VARCHAR(20), DATEADD(MINUTE, -1 * DATEPART(MINUTE, t.date_time), t.date_time), 100), 7)), '':00'', '' '')'
                              WHEN 'DATE'  THEN 'LEFT(DATENAME(MONTH, t.date_time), 3) + '' '' + CAST(DATEPART(DAY, t.date_time) AS VARCHAR)'
                              WHEN 'DAY'   THEN 'LEFT(DATENAME(WEEKDAY, t.date_time), 3)'
                              WHEN 'MONTH' THEN 'RIGHT(CONVERT(CHAR(11), t.date_time, 106), 8)'
                              WHEN 'WEEK'  THEN */'CONVERT(CHAR(6), DATEADD(DAY, @iWeekStart - 1, DATEADD(WEEK, DATEDIFF(WEEK, 6, t.date_time), 6)), 107)'
                         END + ' AS Period,' + @vcNewLine
           + '       ' + /*CASE @pvcPeriod
                              WHEN 'HOUR'  THEN 'REPLACE(LTRIM(RIGHT(CONVERT(VARCHAR(20), DATEADD(MINUTE, -1 * DATEPART(MINUTE, t.date_time), t.date_time), 100), 7)), ''00'', ''00 '')'
                              WHEN 'DATE'  THEN 'CONVERT(CHAR(10), t.date_time, 120)'
                              WHEN 'DAY'   THEN 'DATENAME(WEEKDAY, t.date_time)'
                              WHEN 'MONTH' THEN 'DATENAME(MONTH, t.date_time) + '' '' + DATENAME(YEAR, t.date_time)'
                              WHEN 'WEEK'  THEN */'CONVERT(CHAR(10), DATEADD(DAY, @iWeekStart - 1, DATEADD(WEEK, DATEDIFF(WEEK, 6, t.date_time), 6)), 120) + '' to '' + CONVERT(CHAR(10), DATEADD(DAY, @iWeekStart - 1, DATEADD(WEEK, DATEDIFF(WEEK, 5, t.date_time), 5)), 120)'
                         END + ' AS PeriodDescription,' + @vcNewLine
           + '       COUNT(DISTINCT t.sale_no) AS Transactions,' + @vcNewLine
           + '       SUM(t.quantity) AS Quantity,' + @vcNewLine
           + '       SUM(t.quantity * t.admissions) AS Admissions,' + @vcNewLine
           + '       SUM(t.extension - t.tax_amount - t.tax_amt2 - t.fee_amount) AS Revenue,' + @vcNewLine
           + '       SUM(t.disc_amt) AS Discount' + @vcNewLine
           + '  FROM SiriusSQL.dbo.transact t' + @vcNewLine
           + '  JOIN #Operators o ON o.operator = t.operator' + @vcNewLine
           + '  JOIN #Salespoints s ON s.salespoint = t.salespoint' + @vcNewLine
           + '  JOIN #DCI dci ON dci.department = t.department' + @vcNewLine
           + '               AND dci.category = t.category ' + @vcNewLine
           + '               AND dci.item = t.item' + @vcNewLine
           + ' WHERE t.date_time BETWEEN @pdtStart AND @dtEnd' + @vcNewLine
           + ' GROUP BY' + @vcNewLine
           + '       ' + /*CASE @pvcPeriod
                              WHEN 'HOUR'  THEN 'DATEPART(HOUR, t.date_time)'
                              WHEN 'DATE'  THEN 'CAST(CONVERT(CHAR(8), t.date_time, 112) AS INT)'
                              WHEN 'DAY'   THEN 'DATEPART(WEEKDAY, t.date_time) + CASE WHEN DATEPART(WEEKDAY, t.date_time) < @iWeekStart THEN 7 ELSE 0 END - @iWeekStart + 1'
                              WHEN 'MONTH' THEN 'CAST(CONVERT(CHAR(6), t.date_time, 112) AS INT)'
                              WHEN 'WEEK'  THEN */'CAST(CONVERT(CHAR(8), DATEADD(DAY, @iWeekStart - 1, DATEADD(WEEK, DATEDIFF(WEEK, 6, t.date_time), 6)), 112) AS INT)'
                         END + ',' + @vcNewLine
           + '       ' + /*CASE @pvcPeriod
                              WHEN 'HOUR'  THEN 'REPLACE(LTRIM(RIGHT(CONVERT(VARCHAR(20), DATEADD(MINUTE, -1 * DATEPART(MINUTE, t.date_time), t.date_time), 100), 7)), '':00'', '' '')'
                              WHEN 'DATE'  THEN 'LEFT(DATENAME(MONTH, t.date_time), 3) + '' '' + CAST(DATEPART(DAY, t.date_time) AS VARCHAR)'
                              WHEN 'DAY'   THEN 'LEFT(DATENAME(WEEKDAY, t.date_time), 3)'
                              WHEN 'MONTH' THEN 'RIGHT(CONVERT(CHAR(11), t.date_time, 106), 8)'
                              WHEN 'WEEK'  THEN */'CONVERT(CHAR(6), DATEADD(DAY, @iWeekStart - 1, DATEADD(WEEK, DATEDIFF(WEEK, 6, t.date_time), 6)), 107)'
                         END + ',' + @vcNewLine
           + '       ' + /*CASE @pvcPeriod
                              WHEN 'HOUR'  THEN 'REPLACE(LTRIM(RIGHT(CONVERT(VARCHAR(20), DATEADD(MINUTE, -1 * DATEPART(MINUTE, t.date_time), t.date_time), 100), 7)), ''00'', ''00 '')'
                              WHEN 'DATE'  THEN 'CONVERT(CHAR(10), t.date_time, 120)'
                              WHEN 'DAY'   THEN 'DATENAME(WEEKDAY, t.date_time)'
                              WHEN 'MONTH' THEN 'DATENAME(MONTH, t.date_time) + '' '' + DATENAME(YEAR, t.date_time)'
                              WHEN 'WEEK'  THEN */'CONVERT(CHAR(10), DATEADD(DAY, @iWeekStart - 1, DATEADD(WEEK, DATEDIFF(WEEK, 6, t.date_time), 6)), 120) + '' to '' + CONVERT(CHAR(10), DATEADD(DAY, @iWeekStart - 1, DATEADD(WEEK, DATEDIFF(WEEK, 5, t.date_time), 5)), 120)'
                         END + @vcNewLine                        
           + ' ORDER BY PeriodSort'
--==============================================
-- For debugging:                                         
 PRINT @vcSQL
--==============================================
IF OBJECT_ID('tempdb..#SalesByPeriod') IS NOT NULL DROP TABLE #SalesByPeriod

CREATE TABLE #SalesByPeriod
(
	  PeriodSort   INT,
	  Period       VARCHAR(20),
	  PeriodDescription VARCHAR(50),
	  Transactions INT,
	  Quantity     INT,
	  Admissions   INT,
	  Revenue      MONEY,
	  Discount     MONEY
)
INSERT INTO #SalesByPeriod
  EXEC sp_executesql @statement  = @vcSQL,
                     @params     = N'@pdtStart DATETIME, @dtEnd DATETIME, @iWeekStart INT',
                     @pdtStart   = @pdtStart,
                     @dtEnd      = @dtEnd,
                     @iWeekStart = @iWeekStart
--==============================================
SELECT sbp.PeriodSort,
       sbp.Period,
       sbp.PeriodDescription,
       sbp.Transactions,
       sbp.Quantity,
       sbp.Admissions,
       sbp.Discount,
       sbp.Revenue,
       tr.TotalRevenue
  FROM #SalesByPeriod sbp
 CROSS JOIN (SELECT SUM(Revenue) AS TotalRevenue FROM #SalesByPeriod) tr
--==============================================
/* 
EXEC _rs_SalesPerformanceByPeriod '2011-01-01', 
                                  '2011-12-31', 
                                  'HOUR',  
                                  'TICKETS   ADULT     1DAY      ,TICKETS   ADULT     2DAY      ,TICKETS   YOUTH     1DAY      ',
                                  'salespoint',
                                  'TICKET,RESERV,RENTAL',
                                  'op_group',
                                  '9,6,2,12'
*/
