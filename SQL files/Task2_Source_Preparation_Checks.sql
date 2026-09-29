/*
Task 2: Source preparation and quality checks
Checks relationships between the imported CSV tables and identifies
missing or invalid values before data is loaded into the warehouse.
The CSV files were imported into separate Testing1 tables using SSMS.
*/
USE Testing1;
GO

SELECT COUNT(*) AS HeaderRows
FROM dbo.product_category
WHERE product_category_name = 'product_category_name'
   OR product_category_name_english = 'product_category_name_english';
GO

SELECT
    (SELECT COUNT_BIG(*) FROM dbo.order_items AS i LEFT JOIN dbo.orders AS o
     ON i.order_id = o.order_id WHERE o.order_id IS NULL) AS ItemsWithoutOrders,
    (SELECT COUNT_BIG(*) FROM dbo.order_items AS i LEFT JOIN dbo.products AS p
     ON i.product_id = p.product_id WHERE p.product_id IS NULL) AS ItemsWithoutProducts,
    (SELECT COUNT_BIG(*) FROM dbo.orders AS o LEFT JOIN dbo.customers AS c
     ON o.customer_id = c.customer_id WHERE c.customer_id IS NULL) AS OrdersWithoutCustomers,
    (SELECT COUNT_BIG(*) FROM dbo.order_items AS i LEFT JOIN dbo.sellers AS s
     ON i.seller_id = s.seller_id WHERE s.seller_id IS NULL) AS ItemsWithoutSellers;
GO

SELECT
    (SELECT COUNT_BIG(*) FROM dbo.customers WHERE NULLIF(LTRIM(RTRIM(customer_state)), '') IS NULL) AS CustomersMissingState,
    (SELECT COUNT_BIG(*) FROM dbo.customers WHERE NULLIF(LTRIM(RTRIM(customer_city)), '') IS NULL) AS CustomersMissingCity,
    (SELECT COUNT_BIG(*) FROM dbo.sellers WHERE NULLIF(LTRIM(RTRIM(seller_city)), '') IS NULL) AS SellersMissingCity,
    (SELECT COUNT_BIG(*) FROM dbo.products WHERE NULLIF(LTRIM(RTRIM(product_category_name)), '') IS NULL) AS ProductsMissingCategory,
    (SELECT COUNT_BIG(*) FROM dbo.orders WHERE TRY_CONVERT(DATE, order_purchase_timestamp) IS NULL) AS OrdersMissingOrInvalidDate;
GO

SELECT
    COUNT_BIG(*) AS DeliveredItemRows,
    SUM(CASE WHEN TRY_CONVERT(DECIMAL(12,2), i.price) IS NULL THEN 1 ELSE 0 END) AS InvalidItemPrices,
    SUM(CASE WHEN TRY_CONVERT(DECIMAL(12,2), i.freight_value) IS NULL THEN 1 ELSE 0 END) AS InvalidFreightValues,
    SUM(CASE WHEN TRY_CONVERT(DATE, o.order_purchase_timestamp) IS NULL THEN 1 ELSE 0 END) AS InvalidPurchaseDates
FROM dbo.order_items AS i
JOIN dbo.orders AS o ON i.order_id = o.order_id
WHERE o.order_status = 'delivered';
GO
