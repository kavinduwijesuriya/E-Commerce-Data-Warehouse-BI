
/*
Task 1: Dataset overview
Shows the number of records in each imported Olist source table,
the purchase date range, and the number of orders by status.
These results describe the dataset selected for the project.
*/
USE Testing1;
GO

SELECT N'customers' AS SourceTable, COUNT_BIG(*) AS RecordCount FROM dbo.customers
UNION ALL SELECT N'orders', COUNT_BIG(*) FROM dbo.orders
UNION ALL SELECT N'order_items', COUNT_BIG(*) FROM dbo.order_items
UNION ALL SELECT N'products', COUNT_BIG(*) FROM dbo.products
UNION ALL SELECT N'sellers', COUNT_BIG(*) FROM dbo.sellers
UNION ALL SELECT N'product_category', COUNT_BIG(*) FROM dbo.product_category;
GO

SELECT MIN(TRY_CONVERT(DATE, order_purchase_timestamp)) AS FirstPurchaseDate,
       MAX(TRY_CONVERT(DATE, order_purchase_timestamp)) AS LastPurchaseDate,
       COUNT_BIG(*) AS SourceOrders
FROM dbo.orders;
GO

SELECT order_status AS OrderStatus, COUNT_BIG(*) AS Orders
FROM dbo.orders
GROUP BY order_status
ORDER BY Orders DESC;
GO
