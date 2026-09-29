/*
Task 6: Data mart refresh
Rebuilds the monthly regional and category summaries from FactSales.
For each group it calculates distinct orders, items sold, product
revenue, and freight. The refresh uses a transaction and checks
that item, revenue, and freight totals match FactSales.
*/
USE Olist_DW;
GO
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'SalesMart.MonthlyRegionalSales', N'U') IS NULL
    THROW 51100, 'Create the monthly regional mart table first.', 1;
IF OBJECT_ID(N'SalesMart.MonthlyCategorySales', N'U') IS NULL
    THROW 51101, 'Create the monthly category mart table first.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.FactSales)
    THROW 51104, 'Load FactSales before refreshing the marts.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM SalesMart.MonthlyRegionalSales;
    INSERT INTO SalesMart.MonthlyRegionalSales (
        MonthStartDate, CustomerState, OrdersCount, ItemsSold,
        ProductRevenue, FreightTotal
    )
    SELECT DATEFROMPARTS(d.CalendarYear, d.CalendarMonth, 1),
           l.LocationState,
           COUNT(DISTINCT f.OrderID),
           SUM(CONVERT(INT, f.ItemCount)),
           SUM(CONVERT(DECIMAL(18,2), f.ItemPrice)),
           SUM(CONVERT(DECIMAL(18,2), f.FreightValue))
    FROM dbo.FactSales AS f
    JOIN dbo.DimDate AS d ON f.DateKey = d.DateKey
    JOIN dbo.DimLocation AS l ON f.LocationKey = l.LocationKey
    GROUP BY DATEFROMPARTS(d.CalendarYear, d.CalendarMonth, 1),
             l.LocationState;

    DELETE FROM SalesMart.MonthlyCategorySales;
    INSERT INTO SalesMart.MonthlyCategorySales (
        MonthStartDate, CategoryNamePortuguese, CategoryNameEnglish,
        OrdersCount, ItemsSold, ProductRevenue, FreightTotal
    )
    SELECT DATEFROMPARTS(d.CalendarYear, d.CalendarMonth, 1),
           COALESCE(p.CategoryNamePortuguese, N'[Uncategorised]'),
           MAX(p.CategoryNameEnglish),
           COUNT(DISTINCT f.OrderID),
           SUM(CONVERT(INT, f.ItemCount)),
           SUM(CONVERT(DECIMAL(18,2), f.ItemPrice)),
           SUM(CONVERT(DECIMAL(18,2), f.FreightValue))
    FROM dbo.FactSales AS f
    JOIN dbo.DimDate AS d ON f.DateKey = d.DateKey
    JOIN dbo.DimProduct AS p ON f.ProductKey = p.ProductKey
    GROUP BY DATEFROMPARTS(d.CalendarYear, d.CalendarMonth, 1),
             COALESCE(p.CategoryNamePortuguese, N'[Uncategorised]');

    IF (SELECT SUM(ProductRevenue) FROM SalesMart.MonthlyRegionalSales)
       <> (SELECT SUM(CONVERT(DECIMAL(18,2), ItemPrice)) FROM dbo.FactSales)
        THROW 51102, 'Regional mart revenue differs from FactSales.', 1;
    IF (SELECT SUM(ProductRevenue) FROM SalesMart.MonthlyCategorySales)
       <> (SELECT SUM(CONVERT(DECIMAL(18,2), ItemPrice)) FROM dbo.FactSales)
        THROW 51103, 'Category mart revenue differs from FactSales.', 1;
    IF (SELECT SUM(CONVERT(BIGINT, ItemsSold)) FROM SalesMart.MonthlyRegionalSales)
       <> (SELECT SUM(CONVERT(BIGINT, ItemCount)) FROM dbo.FactSales)
        THROW 51105, 'Regional mart item count differs from FactSales.', 1;
    IF (SELECT SUM(CONVERT(BIGINT, ItemsSold)) FROM SalesMart.MonthlyCategorySales)
       <> (SELECT SUM(CONVERT(BIGINT, ItemCount)) FROM dbo.FactSales)
        THROW 51106, 'Category mart item count differs from FactSales.', 1;
    IF (SELECT SUM(FreightTotal) FROM SalesMart.MonthlyRegionalSales)
       <> (SELECT SUM(CONVERT(DECIMAL(18,2), FreightValue)) FROM dbo.FactSales)
        THROW 51107, 'Regional mart freight differs from FactSales.', 1;
    IF (SELECT SUM(FreightTotal) FROM SalesMart.MonthlyCategorySales)
       <> (SELECT SUM(CONVERT(DECIMAL(18,2), FreightValue)) FROM dbo.FactSales)
        THROW 51108, 'Category mart freight differs from FactSales.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT 'FactSales' AS DataSet, COUNT_BIG(*) AS GroupRows,
       SUM(CONVERT(BIGINT, ItemCount)) AS ItemsSold,
       SUM(CONVERT(DECIMAL(18,2), ItemPrice)) AS ProductRevenue,
       SUM(CONVERT(DECIMAL(18,2), FreightValue)) AS FreightTotal
FROM dbo.FactSales
UNION ALL
SELECT 'Regional mart', COUNT_BIG(*) AS GroupRows,
       SUM(ItemsSold) AS ItemsSold, SUM(ProductRevenue) AS ProductRevenue,
       SUM(FreightTotal) AS FreightTotal
FROM SalesMart.MonthlyRegionalSales
UNION ALL
SELECT 'Category mart', COUNT_BIG(*), SUM(ItemsSold),
       SUM(ProductRevenue), SUM(FreightTotal)
FROM SalesMart.MonthlyCategorySales;

/* Category OrdersCount cannot be summed into one global order count:
   a single order may include items from more than one product category. */
