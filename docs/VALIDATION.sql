/*
Fabric Supply Chain Graph Analytics
Source validation for the SupplyChainLakehouse SQL analytics endpoint.

Run each result set and compare it with the documented baseline.
All comments are intentionally written in English.
*/

/* 1. Validate row counts for all source tables. */
SELECT 'adventureworks_customers' AS TableName, COUNT(*) AS RowCount
FROM dbo.adventureworks_customers
UNION ALL
SELECT 'adventureworks_employees', COUNT(*)
FROM dbo.adventureworks_employees
UNION ALL
SELECT 'adventureworks_orders', COUNT(*)
FROM dbo.adventureworks_orders
UNION ALL
SELECT 'adventureworks_productcategories', COUNT(*)
FROM dbo.adventureworks_productcategories
UNION ALL
SELECT 'adventureworks_products', COUNT(*)
FROM dbo.adventureworks_products
UNION ALL
SELECT 'adventureworks_productsubcategories', COUNT(*)
FROM dbo.adventureworks_productsubcategories
UNION ALL
SELECT 'adventureworks_vendorproduct', COUNT(*)
FROM dbo.adventureworks_vendorproduct
UNION ALL
SELECT 'adventureworks_vendors', COUNT(*)
FROM dbo.adventureworks_vendors
ORDER BY TableName;

/* 2. Validate uniqueness and nullability of vendor-product source pairs. */
SELECT
    COUNT(*) AS SourceRowCount,
    COUNT(DISTINCT VendorID_FK, ProductID_FK) AS DistinctVendorProductPairs,
    SUM(CASE WHEN VendorID_FK IS NULL THEN 1 ELSE 0 END) AS NullVendorKeys,
    SUM(CASE WHEN ProductID_FK IS NULL THEN 1 ELSE 0 END) AS NullProductKeys
FROM dbo.adventureworks_vendorproduct;

/* 3. Validate how many vendor-product rows match both endpoint tables. */
SELECT
    COUNT(*) AS SourcePairs,
    SUM(CASE WHEN v.VendorID_K IS NOT NULL THEN 1 ELSE 0 END) AS MatchedVendors,
    SUM(CASE WHEN p.ProductID_K IS NOT NULL THEN 1 ELSE 0 END) AS MatchedProducts,
    SUM(
        CASE
            WHEN v.VendorID_K IS NOT NULL
             AND p.ProductID_K IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS FullyMatchedEdges,
    SUM(CASE WHEN v.VendorID_K IS NULL THEN 1 ELSE 0 END) AS MissingVendorMatches,
    SUM(CASE WHEN p.ProductID_K IS NULL THEN 1 ELSE 0 END) AS MissingProductMatches
FROM dbo.adventureworks_vendorproduct AS vp
LEFT JOIN dbo.adventureworks_vendors AS v
    ON vp.VendorID_FK = v.VendorID_K
LEFT JOIN dbo.adventureworks_products AS p
    ON vp.ProductID_FK = p.ProductID_K;

/* 4. List product keys referenced by vendor-product rows but absent from products. */
SELECT
    vp.ProductID_FK,
    COUNT(*) AS ReferenceCount
FROM dbo.adventureworks_vendorproduct AS vp
LEFT JOIN dbo.adventureworks_products AS p
    ON vp.ProductID_FK = p.ProductID_K
WHERE p.ProductID_K IS NULL
GROUP BY vp.ProductID_FK
ORDER BY vp.ProductID_FK;

/* 5. Validate order-to-customer endpoint coverage. */
SELECT
    COUNT(*) AS OrderRows,
    SUM(CASE WHEN c.CustomerID_K IS NOT NULL THEN 1 ELSE 0 END) AS MatchedCustomerRows,
    SUM(CASE WHEN c.CustomerID_K IS NULL THEN 1 ELSE 0 END) AS MissingCustomerRows
FROM dbo.adventureworks_orders AS o
LEFT JOIN dbo.adventureworks_customers AS c
    ON o.CustomerID_FK = c.CustomerID_K;

/* 6. Validate order-to-product endpoint coverage. */
SELECT
    COUNT(*) AS OrderRows,
    SUM(CASE WHEN p.ProductID_K IS NOT NULL THEN 1 ELSE 0 END) AS MatchedProductRows,
    SUM(CASE WHEN p.ProductID_K IS NULL THEN 1 ELSE 0 END) AS MissingProductRows
FROM dbo.adventureworks_orders AS o
LEFT JOIN dbo.adventureworks_products AS p
    ON o.ProductID_FK = p.ProductID_K;

/* Expected baseline:
   Orders: 60919
   Vendor-product source rows: 460
   Distinct vendor-product pairs: 460
   Fully matched vendor-product edges: 103
   Missing product matches in vendor-product: 357
*/
