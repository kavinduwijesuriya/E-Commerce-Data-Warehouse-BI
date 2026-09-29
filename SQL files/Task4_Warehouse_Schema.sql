/*
Task 4: Dimensional warehouse schema
Creates the dimension tables and the FactSales table in Olist_DW.
Primary keys, foreign keys, and unique constraints define the
star schema relationships and protect the order item grain.
Existing tables are skipped, so this script does not replace them.
*/
IF DB_ID(N'Olist_DW') IS NULL CREATE DATABASE Olist_DW;
GO
USE Olist_DW;
GO

IF OBJECT_ID(N'dbo.DimCustomer', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimCustomer (
        CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
        CustomerID CHAR(32) NOT NULL UNIQUE,
        CustomerUniqueID CHAR(32) NOT NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.DimDate', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimDate (
        DateKey INT PRIMARY KEY,
        FullDate DATE NOT NULL UNIQUE,
        CalendarYear SMALLINT NOT NULL,
        CalendarQuarter TINYINT NOT NULL,
        CalendarMonth TINYINT NOT NULL,
        MonthName NVARCHAR(20) NOT NULL,
        DayOfMonth TINYINT NOT NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.DimProduct', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimProduct (
        ProductKey INT IDENTITY(1,1) PRIMARY KEY,
        ProductID CHAR(32) NOT NULL UNIQUE,
        CategoryNamePortuguese NVARCHAR(100) NULL,
        CategoryNameEnglish NVARCHAR(100) NULL,
        ProductWeightGrams INT NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.DimLocation', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimLocation (
        LocationKey INT IDENTITY(1,1) PRIMARY KEY,
        LocationState CHAR(2) NOT NULL,
        LocationCity NVARCHAR(100) NOT NULL,
        CONSTRAINT UQ_DimLocation_StateCity UNIQUE (LocationState, LocationCity)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimSeller', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimSeller (
        SellerKey INT IDENTITY(1,1) PRIMARY KEY,
        SellerID CHAR(32) NOT NULL UNIQUE,
        SellerCity NVARCHAR(100) NOT NULL,
        SellerState CHAR(2) NOT NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.FactSales', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactSales (
        SalesKey BIGINT IDENTITY(1,1) PRIMARY KEY,
        OrderID CHAR(32) NOT NULL,
        OrderItemID INT NOT NULL,
        CustomerKey INT NOT NULL,
        ProductKey INT NOT NULL,
        SellerKey INT NOT NULL,
        LocationKey INT NOT NULL,
        DateKey INT NOT NULL,
        ItemPrice DECIMAL(12,2) NOT NULL,
        FreightValue DECIMAL(12,2) NOT NULL,
        ItemCount TINYINT NOT NULL DEFAULT 1,
        CONSTRAINT UQ_FactSales_OrderItem UNIQUE (OrderID, OrderItemID),
        CONSTRAINT FK_FactSales_Customer FOREIGN KEY (CustomerKey) REFERENCES dbo.DimCustomer(CustomerKey),
        CONSTRAINT FK_FactSales_Product FOREIGN KEY (ProductKey) REFERENCES dbo.DimProduct(ProductKey),
        CONSTRAINT FK_FactSales_Seller FOREIGN KEY (SellerKey) REFERENCES dbo.DimSeller(SellerKey),
        CONSTRAINT FK_FactSales_Location FOREIGN KEY (LocationKey) REFERENCES dbo.DimLocation(LocationKey),
        CONSTRAINT FK_FactSales_Date FOREIGN KEY (DateKey) REFERENCES dbo.DimDate(DateKey)
    );
END;
GO

SELECT s.name AS SchemaName, t.name AS WarehouseTable
FROM sys.tables AS t JOIN sys.schemas AS s ON t.schema_id = s.schema_id
WHERE s.name = N'dbo' AND t.name IN
    (N'DimCustomer', N'DimDate', N'DimProduct', N'DimLocation', N'DimSeller', N'FactSales')
ORDER BY t.name;
GO
