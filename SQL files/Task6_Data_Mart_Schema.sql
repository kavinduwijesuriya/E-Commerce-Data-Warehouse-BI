/*
Task 6: Data mart structure
Creates two summary tables in the SalesMart schema:
one row per month and customer state, and one row per month
and product category. Existing mart tables are skipped.
*/
USE Olist_DW;
GO
IF SCHEMA_ID(N'SalesMart') IS NULL EXEC(N'CREATE SCHEMA SalesMart');
GO

IF OBJECT_ID(N'SalesMart.MonthlyRegionalSales', N'U') IS NULL
BEGIN
    CREATE TABLE SalesMart.MonthlyRegionalSales (
        MonthStartDate DATE NOT NULL,
        CustomerState CHAR(2) NOT NULL,
        OrdersCount INT NOT NULL,
        ItemsSold INT NOT NULL,
        ProductRevenue DECIMAL(18,2) NOT NULL,
        FreightTotal DECIMAL(18,2) NOT NULL,
        CONSTRAINT PK_MonthlyRegionalSales PRIMARY KEY (MonthStartDate, CustomerState)
    );
END;
GO

IF OBJECT_ID(N'SalesMart.MonthlyCategorySales', N'U') IS NULL
BEGIN
    CREATE TABLE SalesMart.MonthlyCategorySales (
        MonthStartDate DATE NOT NULL,
        CategoryNamePortuguese NVARCHAR(100) NOT NULL,
        CategoryNameEnglish NVARCHAR(100) NULL,
        OrdersCount INT NOT NULL,
        ItemsSold INT NOT NULL,
        ProductRevenue DECIMAL(18,2) NOT NULL,
        FreightTotal DECIMAL(18,2) NOT NULL,
        CONSTRAINT PK_MonthlyCategorySales PRIMARY KEY (MonthStartDate, CategoryNamePortuguese)
    );
END;
GO

SELECT name AS MartTable
FROM sys.tables WHERE schema_id = SCHEMA_ID(N'SalesMart')
ORDER BY name;
GO
