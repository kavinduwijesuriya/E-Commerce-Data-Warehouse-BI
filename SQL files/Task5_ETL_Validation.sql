/*
Task 5: ETL validation
Compares delivered source data with FactSales using row counts,
distinct orders, product revenue, and freight totals. It also
checks dimension matches, duplicate source keys, and category labels.
*/
USE Olist_DW;
GO

SELECT N'DimCustomer' AS WarehouseTable, COUNT_BIG(*) AS RowCountValue FROM dbo.DimCustomer
UNION ALL SELECT N'DimProduct', COUNT_BIG(*) FROM dbo.DimProduct
UNION ALL SELECT N'DimSeller', COUNT_BIG(*) FROM dbo.DimSeller
UNION ALL SELECT N'DimLocation', COUNT_BIG(*) FROM dbo.DimLocation
UNION ALL SELECT N'DimDate', COUNT_BIG(*) FROM dbo.DimDate
UNION ALL SELECT N'FactSales', COUNT_BIG(*) FROM dbo.FactSales;
GO

SELECT N'Delivered source' AS DataSet,
       COUNT_BIG(*) AS ItemRows,
       COUNT(DISTINCT i.order_id) AS DistinctOrders,
       SUM(TRY_CONVERT(DECIMAL(18,2), i.price)) AS ProductRevenue,
       SUM(TRY_CONVERT(DECIMAL(18,2), i.freight_value)) AS FreightTotal
FROM Testing1.dbo.order_items AS i
JOIN Testing1.dbo.orders AS o ON i.order_id = o.order_id
WHERE o.order_status = 'delivered'
UNION ALL
SELECT N'FactSales', COUNT_BIG(*), COUNT(DISTINCT OrderID),
       SUM(CONVERT(DECIMAL(18,2), ItemPrice)),
       SUM(CONVERT(DECIMAL(18,2), FreightValue))
FROM dbo.FactSales;
GO

SELECT COUNT_BIG(*) AS FactRows,
       SUM(CONVERT(BIGINT, ItemCount)) AS ItemsSold,
       SUM(CASE WHEN dc.CustomerKey IS NULL THEN 1 ELSE 0 END) AS MissingCustomer,
       SUM(CASE WHEN dp.ProductKey IS NULL THEN 1 ELSE 0 END) AS MissingProduct,
       SUM(CASE WHEN ds.SellerKey IS NULL THEN 1 ELSE 0 END) AS MissingSeller,
       SUM(CASE WHEN dl.LocationKey IS NULL THEN 1 ELSE 0 END) AS MissingLocation,
       SUM(CASE WHEN dd.DateKey IS NULL THEN 1 ELSE 0 END) AS MissingDate
FROM dbo.FactSales AS f
LEFT JOIN dbo.DimCustomer AS dc ON f.CustomerKey = dc.CustomerKey
LEFT JOIN dbo.DimProduct AS dp ON f.ProductKey = dp.ProductKey
LEFT JOIN dbo.DimSeller AS ds ON f.SellerKey = ds.SellerKey
LEFT JOIN dbo.DimLocation AS dl ON f.LocationKey = dl.LocationKey
LEFT JOIN dbo.DimDate AS dd ON f.DateKey = dd.DateKey;
GO

/* Source-key duplicate groups. Each count should be zero before loading. */
SELECT N'customers.customer_id' AS CheckedKey, COUNT_BIG(*) AS DuplicateGroups
FROM (SELECT customer_id FROM Testing1.dbo.customers
      GROUP BY customer_id HAVING COUNT_BIG(*) > 1) AS x
UNION ALL
SELECT N'products.product_id', COUNT_BIG(*)
FROM (SELECT product_id FROM Testing1.dbo.products
      GROUP BY product_id HAVING COUNT_BIG(*) > 1) AS x
UNION ALL
SELECT N'sellers.seller_id', COUNT_BIG(*)
FROM (SELECT seller_id FROM Testing1.dbo.sellers
      GROUP BY seller_id HAVING COUNT_BIG(*) > 1) AS x
UNION ALL
SELECT N'orders.order_id', COUNT_BIG(*)
FROM (SELECT order_id FROM Testing1.dbo.orders
      GROUP BY order_id HAVING COUNT_BIG(*) > 1) AS x
UNION ALL
SELECT N'order_items(order_id,order_item_id)', COUNT_BIG(*)
FROM (SELECT order_id, order_item_id FROM Testing1.dbo.order_items
      GROUP BY order_id, order_item_id HAVING COUNT_BIG(*) > 1) AS x
UNION ALL
SELECT N'product_category.product_category_name', COUNT_BIG(*)
FROM (SELECT product_category_name FROM Testing1.dbo.product_category
      GROUP BY product_category_name HAVING COUNT_BIG(*) > 1) AS x;
GO

SELECT COUNT_BIG(*) AS ProductsWithoutPortugueseCategory
FROM dbo.DimProduct WHERE CategoryNamePortuguese IS NULL;
SELECT COUNT_BIG(*) AS ProductsWithUntranslatedEnglishCategory
FROM dbo.DimProduct WHERE CategoryNameEnglish LIKE N'Untranslated:%';
GO
