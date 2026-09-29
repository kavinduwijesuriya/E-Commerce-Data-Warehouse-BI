/*
Task 5: Extract, transform, and load
Reads operational data from Testing1, cleans and converts values,
loads missing dimension members, and loads delivered order items
into FactSales. Missing product categories receive the reporting
label 'Uncategorised'. The transaction rolls back if a load check fails.
*/
USE Olist_DW;
GO
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (
        SELECT 1 FROM Testing1.dbo.order_items AS i
        JOIN Testing1.dbo.orders AS o ON i.order_id = o.order_id
        WHERE o.order_status = 'delivered'
          AND (TRY_CONVERT(DECIMAL(12,2), i.price) IS NULL
            OR TRY_CONVERT(DECIMAL(12,2), i.freight_value) IS NULL
            OR TRY_CONVERT(DECIMAL(12,2), i.price) < 0
            OR TRY_CONVERT(DECIMAL(12,2), i.freight_value) < 0
            OR TRY_CONVERT(DATE, o.order_purchase_timestamp) IS NULL)
    )
        THROW 51000, 'Invalid delivered sale date, price, or freight: review source before loading.', 1;

    INSERT INTO dbo.DimCustomer (CustomerID, CustomerUniqueID)
    SELECT LTRIM(RTRIM(c.customer_id)), LTRIM(RTRIM(c.customer_unique_id))
    FROM Testing1.dbo.customers AS c
    WHERE NULLIF(LTRIM(RTRIM(c.customer_id)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(c.customer_unique_id)), '') IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dbo.DimCustomer AS d
          WHERE d.CustomerID = LTRIM(RTRIM(c.customer_id))
      );

    INSERT INTO dbo.DimSeller (SellerID, SellerCity, SellerState)
    SELECT LTRIM(RTRIM(s.seller_id)), LTRIM(RTRIM(s.seller_city)),
           UPPER(LTRIM(RTRIM(s.seller_state)))
    FROM Testing1.dbo.sellers AS s
    WHERE NULLIF(LTRIM(RTRIM(s.seller_id)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(s.seller_city)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(s.seller_state)), '') IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dbo.DimSeller AS d
          WHERE d.SellerID = LTRIM(RTRIM(s.seller_id))
      );

    INSERT INTO dbo.DimLocation (LocationState, LocationCity)
    SELECT DISTINCT UPPER(LTRIM(RTRIM(c.customer_state))),
                    LTRIM(RTRIM(c.customer_city))
    FROM Testing1.dbo.customers AS c
    WHERE NULLIF(LTRIM(RTRIM(c.customer_state)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(c.customer_city)), '') IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dbo.DimLocation AS d
          WHERE d.LocationState = UPPER(LTRIM(RTRIM(c.customer_state)))
            AND d.LocationCity = LTRIM(RTRIM(c.customer_city))
      );

    INSERT INTO dbo.DimProduct (
        ProductID, CategoryNamePortuguese,
        CategoryNameEnglish, ProductWeightGrams
    )
    SELECT LTRIM(RTRIM(p.product_id)),
           NULLIF(LTRIM(RTRIM(p.product_category_name)), ''),
           CASE
               WHEN NULLIF(LTRIM(RTRIM(p.product_category_name)), '') IS NULL
                   THEN N'Uncategorised'
               WHEN NULLIF(LTRIM(RTRIM(t.product_category_name_english)), '') IS NULL
                   THEN N'Untranslated: ' + LTRIM(RTRIM(p.product_category_name))
               ELSE LTRIM(RTRIM(t.product_category_name_english))
           END,
           TRY_CONVERT(INT, p.product_weight_g)
    FROM Testing1.dbo.products AS p
    LEFT JOIN Testing1.dbo.product_category AS t
        ON p.product_category_name = t.product_category_name
    WHERE NULLIF(LTRIM(RTRIM(p.product_id)), '') IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dbo.DimProduct AS d
          WHERE d.ProductID = LTRIM(RTRIM(p.product_id))
      );

    /* Also bring category labels in the existing dimension up to date. */
    UPDATE d
    SET d.CategoryNamePortuguese = NULLIF(LTRIM(RTRIM(p.product_category_name)), ''),
        d.CategoryNameEnglish = CASE
            WHEN NULLIF(LTRIM(RTRIM(p.product_category_name)), '') IS NULL
                THEN N'Uncategorised'
            WHEN NULLIF(LTRIM(RTRIM(t.product_category_name_english)), '') IS NULL
                THEN N'Untranslated: ' + LTRIM(RTRIM(p.product_category_name))
            ELSE LTRIM(RTRIM(t.product_category_name_english))
        END
    FROM dbo.DimProduct AS d
    JOIN Testing1.dbo.products AS p ON d.ProductID = LTRIM(RTRIM(p.product_id))
    LEFT JOIN Testing1.dbo.product_category AS t
        ON p.product_category_name = t.product_category_name;

    DECLARE @FirstDate DATE, @LastDate DATE;
    SELECT @FirstDate = MIN(TRY_CONVERT(DATE, order_purchase_timestamp)),
           @LastDate = MAX(TRY_CONVERT(DATE, order_purchase_timestamp))
    FROM Testing1.dbo.orders;

    IF @FirstDate IS NULL OR @LastDate IS NULL
        THROW 51001, 'No valid purchase dates were found.', 1;

    ;WITH CalendarDates AS (
        SELECT @FirstDate AS FullDate
        UNION ALL
        SELECT DATEADD(DAY, 1, FullDate)
        FROM CalendarDates WHERE FullDate < @LastDate
    )
    INSERT INTO dbo.DimDate (
        DateKey, FullDate, CalendarYear, CalendarQuarter,
        CalendarMonth, MonthName, DayOfMonth
    )
    SELECT YEAR(d.FullDate) * 10000 + MONTH(d.FullDate) * 100 + DAY(d.FullDate),
           d.FullDate, YEAR(d.FullDate), DATEPART(QUARTER, d.FullDate),
           MONTH(d.FullDate), DATENAME(MONTH, d.FullDate), DAY(d.FullDate)
    FROM CalendarDates AS d
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate AS x WHERE x.FullDate = d.FullDate)
    OPTION (MAXRECURSION 0);

    IF EXISTS (
        SELECT 1
        FROM Testing1.dbo.order_items AS i
        JOIN Testing1.dbo.orders AS o ON i.order_id = o.order_id
        LEFT JOIN Testing1.dbo.customers AS c ON o.customer_id = c.customer_id
        LEFT JOIN dbo.DimCustomer AS dc ON c.customer_id = dc.CustomerID
        LEFT JOIN dbo.DimProduct AS dp ON i.product_id = dp.ProductID
        LEFT JOIN dbo.DimSeller AS ds ON i.seller_id = ds.SellerID
        LEFT JOIN dbo.DimLocation AS dl
            ON UPPER(LTRIM(RTRIM(c.customer_state))) = dl.LocationState
           AND LTRIM(RTRIM(c.customer_city)) = dl.LocationCity
        LEFT JOIN dbo.DimDate AS dd
            ON TRY_CONVERT(DATE, o.order_purchase_timestamp) = dd.FullDate
        WHERE o.order_status = 'delivered'
          AND (dc.CustomerKey IS NULL OR dp.ProductKey IS NULL
            OR ds.SellerKey IS NULL OR dl.LocationKey IS NULL
            OR dd.DateKey IS NULL)
    )
        THROW 51002, 'A delivered item lacks a required dimension; investigate before loading.', 1;

    INSERT INTO dbo.FactSales (
        OrderID, OrderItemID, CustomerKey, ProductKey, SellerKey,
        LocationKey, DateKey, ItemPrice, FreightValue
    )
    SELECT i.order_id, i.order_item_id, dc.CustomerKey, dp.ProductKey,
           ds.SellerKey, dl.LocationKey, dd.DateKey,
           TRY_CONVERT(DECIMAL(12,2), i.price),
           TRY_CONVERT(DECIMAL(12,2), i.freight_value)
    FROM Testing1.dbo.order_items AS i
    JOIN Testing1.dbo.orders AS o ON i.order_id = o.order_id
    JOIN Testing1.dbo.customers AS c ON o.customer_id = c.customer_id
    JOIN dbo.DimCustomer AS dc ON c.customer_id = dc.CustomerID
    JOIN dbo.DimProduct AS dp ON i.product_id = dp.ProductID
    JOIN dbo.DimSeller AS ds ON i.seller_id = ds.SellerID
    JOIN dbo.DimLocation AS dl
        ON UPPER(LTRIM(RTRIM(c.customer_state))) = dl.LocationState
       AND LTRIM(RTRIM(c.customer_city)) = dl.LocationCity
    JOIN dbo.DimDate AS dd
        ON TRY_CONVERT(DATE, o.order_purchase_timestamp) = dd.FullDate
    WHERE o.order_status = 'delivered'
      AND NOT EXISTS (
          SELECT 1 FROM dbo.FactSales AS f
          WHERE f.OrderID = i.order_id AND f.OrderItemID = i.order_item_id
      );

    DECLARE @DeliveredCount BIGINT = (
        SELECT COUNT_BIG(*)
        FROM Testing1.dbo.order_items AS i
        JOIN Testing1.dbo.orders AS o ON i.order_id = o.order_id
        WHERE o.order_status = 'delivered'
    );
    IF @DeliveredCount <> (SELECT COUNT_BIG(*) FROM dbo.FactSales)
        THROW 51003, 'Fact count differs from delivered source count.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT 'DimCustomer' AS WarehouseTable, COUNT_BIG(*) AS RowsLoaded FROM dbo.DimCustomer
UNION ALL SELECT 'DimSeller', COUNT_BIG(*) FROM dbo.DimSeller
UNION ALL SELECT 'DimLocation', COUNT_BIG(*) FROM dbo.DimLocation
UNION ALL SELECT 'DimProduct', COUNT_BIG(*) FROM dbo.DimProduct
UNION ALL SELECT 'DimDate', COUNT_BIG(*) FROM dbo.DimDate
UNION ALL SELECT 'FactSales', COUNT_BIG(*) FROM dbo.FactSales;
