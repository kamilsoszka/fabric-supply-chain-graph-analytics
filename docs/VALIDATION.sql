/*
Fabric Supply Chain Graph Analytics
Source validation for the SupplyChainLakehouse SQL analytics endpoint.

The script is read-only.
Run every result set and compare it with the documented baseline.
All comments and output names are intentionally written in English.
*/

/* 1. Validate row counts for all eight source tables. */
SELECT
    'adventureworks_customers' AS [Table_Name],
    COUNT_BIG(*) AS [Row_Count]
FROM dbo.adventureworks_customers

UNION ALL

SELECT
    'adventureworks_employees',
    COUNT_BIG(*)
FROM dbo.adventureworks_employees

UNION ALL

SELECT
    'adventureworks_orders',
    COUNT_BIG(*)
FROM dbo.adventureworks_orders

UNION ALL

SELECT
    'adventureworks_productcategories',
    COUNT_BIG(*)
FROM dbo.adventureworks_productcategories

UNION ALL

SELECT
    'adventureworks_products',
    COUNT_BIG(*)
FROM dbo.adventureworks_products

UNION ALL

SELECT
    'adventureworks_productsubcategories',
    COUNT_BIG(*)
FROM dbo.adventureworks_productsubcategories

UNION ALL

SELECT
    'adventureworks_vendorproduct',
    COUNT_BIG(*)
FROM dbo.adventureworks_vendorproduct

UNION ALL

SELECT
    'adventureworks_vendors',
    COUNT_BIG(*)
FROM dbo.adventureworks_vendors

ORDER BY [Table_Name];


/* 2. Validate null and duplicate keys for all graph-source entities. */
SELECT
    'Customer' AS [Entity_Name],
    COUNT_BIG(*) AS [Row_Count],
    SUM(
        CASE
            WHEN CustomerID_K IS NULL THEN 1
            ELSE 0
        END
    ) AS [Null_Key_Count],
    COUNT_BIG(*) - COUNT_BIG(DISTINCT CustomerID_K)
        AS [Duplicate_Key_Count]
FROM dbo.adventureworks_customers

UNION ALL

SELECT
    'Employee',
    COUNT_BIG(*),
    SUM(
        CASE
            WHEN EmployeeID_K IS NULL THEN 1
            ELSE 0
        END
    ),
    COUNT_BIG(*) - COUNT_BIG(DISTINCT EmployeeID_K)
FROM dbo.adventureworks_employees

UNION ALL

SELECT
    'Order',
    COUNT_BIG(*),
    SUM(
        CASE
            WHEN SalesOrderDetailID_K IS NULL THEN 1
            ELSE 0
        END
    ),
    COUNT_BIG(*) - COUNT_BIG(DISTINCT SalesOrderDetailID_K)
FROM dbo.adventureworks_orders

UNION ALL

SELECT
    'ProductCategory',
    COUNT_BIG(*),
    SUM(
        CASE
            WHEN CategoryID_K IS NULL THEN 1
            ELSE 0
        END
    ),
    COUNT_BIG(*) - COUNT_BIG(DISTINCT CategoryID_K)
FROM dbo.adventureworks_productcategories

UNION ALL

SELECT
    'Product',
    COUNT_BIG(*),
    SUM(
        CASE
            WHEN ProductID_K IS NULL THEN 1
            ELSE 0
        END
    ),
    COUNT_BIG(*) - COUNT_BIG(DISTINCT ProductID_K)
FROM dbo.adventureworks_products

UNION ALL

SELECT
    'ProductSubcategory',
    COUNT_BIG(*),
    SUM(
        CASE
            WHEN SubcategoryID_K IS NULL THEN 1
            ELSE 0
        END
    ),
    COUNT_BIG(*) - COUNT_BIG(DISTINCT SubcategoryID_K)
FROM dbo.adventureworks_productsubcategories

UNION ALL

SELECT
    'VendorProduct',
    COUNT_BIG(*),
    SUM(
        CASE
            WHEN VendorID_FK IS NULL
              OR ProductID_FK IS NULL
            THEN 1
            ELSE 0
        END
    ),
    COUNT_BIG(*) -
        COUNT_BIG(
            DISTINCT CONCAT(
                CAST(VendorID_FK AS VARCHAR(50)),
                '|',
                CAST(ProductID_FK AS VARCHAR(50))
            )
        )
FROM dbo.adventureworks_vendorproduct

UNION ALL

SELECT
    'Vendor',
    COUNT_BIG(*),
    SUM(
        CASE
            WHEN VendorID_K IS NULL THEN 1
            ELSE 0
        END
    ),
    COUNT_BIG(*) - COUNT_BIG(DISTINCT VendorID_K)
FROM dbo.adventureworks_vendors

ORDER BY [Entity_Name];


/* 3. Validate vendor-product graph endpoint coverage. */
SELECT
    COUNT_BIG(*) AS [VendorProduct_Rows],
    COUNT_BIG(
        DISTINCT CONCAT(
            CAST(vp.VendorID_FK AS VARCHAR(50)),
            '|',
            CAST(vp.ProductID_FK AS VARCHAR(50))
        )
    ) AS [Distinct_Vendor_Product_Pairs],
    SUM(
        CASE
            WHEN v.VendorID_K IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS [Rows_With_Matched_Vendor],
    SUM(
        CASE
            WHEN p.ProductID_K IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS [Rows_With_Matched_Product],
    SUM(
        CASE
            WHEN v.VendorID_K IS NOT NULL
             AND p.ProductID_K IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS [Fully_Matched_Relationships],
    SUM(
        CASE
            WHEN v.VendorID_K IS NULL THEN 1
            ELSE 0
        END
    ) AS [Missing_Vendor_Matches],
    SUM(
        CASE
            WHEN p.ProductID_K IS NULL THEN 1
            ELSE 0
        END
    ) AS [Missing_Product_Matches],
    COUNT_BIG(DISTINCT p.ProductID_K)
        AS [Distinct_Supplied_Products]
FROM dbo.adventureworks_vendorproduct AS vp
LEFT JOIN dbo.adventureworks_vendors AS v
    ON v.VendorID_K = vp.VendorID_FK
LEFT JOIN dbo.adventureworks_products AS p
    ON p.ProductID_K = vp.ProductID_FK;


/* 4. List product keys referenced by VendorProduct but absent from Product. */
SELECT
    vp.ProductID_FK AS [Missing_Product_ID],
    COUNT_BIG(*) AS [Reference_Count]
FROM dbo.adventureworks_vendorproduct AS vp
LEFT JOIN dbo.adventureworks_products AS p
    ON p.ProductID_K = vp.ProductID_FK
WHERE p.ProductID_K IS NULL
GROUP BY
    vp.ProductID_FK
ORDER BY
    vp.ProductID_FK;


/* 5. Validate graph endpoint coverage for Order relationships. */
SELECT
    COUNT_BIG(*) AS [Order_Line_Rows],
    SUM(
        CASE
            WHEN c.CustomerID_K IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS [Matched_Customer_Rows],
    SUM(
        CASE
            WHEN c.CustomerID_K IS NULL THEN 1
            ELSE 0
        END
    ) AS [Missing_Customer_Rows],
    SUM(
        CASE
            WHEN e.EmployeeID_K IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS [Matched_Employee_Rows],
    SUM(
        CASE
            WHEN e.EmployeeID_K IS NULL THEN 1
            ELSE 0
        END
    ) AS [Missing_Employee_Rows],
    SUM(
        CASE
            WHEN p.ProductID_K IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS [Matched_Product_Rows],
    SUM(
        CASE
            WHEN p.ProductID_K IS NULL THEN 1
            ELSE 0
        END
    ) AS [Missing_Product_Rows]
FROM dbo.adventureworks_orders AS o
LEFT JOIN dbo.adventureworks_customers AS c
    ON c.CustomerID_K = o.CustomerID_FK
LEFT JOIN dbo.adventureworks_employees AS e
    ON e.EmployeeID_K = o.EmployeeID_FK
LEFT JOIN dbo.adventureworks_products AS p
    ON p.ProductID_K = o.ProductID_FK;


/* 6. Validate Product to ProductSubcategory relationships. */
SELECT
    COUNT_BIG(*) AS [Product_Rows],
    SUM(
        CASE
            WHEN s.SubcategoryID_K IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS [Matched_Subcategory_Rows],
    SUM(
        CASE
            WHEN s.SubcategoryID_K IS NULL THEN 1
            ELSE 0
        END
    ) AS [Missing_Subcategory_Rows]
FROM dbo.adventureworks_products AS p
LEFT JOIN dbo.adventureworks_productsubcategories AS s
    ON s.SubcategoryID_K = p.SubcategoryID_FK;


/* 7. Validate ProductSubcategory to ProductCategory relationships. */
SELECT
    COUNT_BIG(*) AS [Product_Subcategory_Rows],
    SUM(
        CASE
            WHEN c.CategoryID_K IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS [Matched_Category_Rows],
    SUM(
        CASE
            WHEN c.CategoryID_K IS NULL THEN 1
            ELSE 0
        END
    ) AS [Missing_Category_Rows]
FROM dbo.adventureworks_productsubcategories AS s
LEFT JOIN dbo.adventureworks_productcategories AS c
    ON c.CategoryID_K = s.CategoryID_FK;


/* 8. Validate the actual grain of the Order graph node. */
WITH OrderLevelValues AS
(
    SELECT
        SalesOrderID,
        COUNT_BIG(*) AS [Line_Count],
        MAX(Freight) AS [Order_Freight],
        MAX(SubTotal) AS [Order_SubTotal],
        MAX(TaxAmt) AS [Order_Tax_Amount],
        MAX(TotalDue) AS [Order_Total_Due],
        COUNT(DISTINCT Freight) AS [Distinct_Freight_Values],
        COUNT(DISTINCT SubTotal) AS [Distinct_SubTotal_Values],
        COUNT(DISTINCT TaxAmt) AS [Distinct_Tax_Values],
        COUNT(DISTINCT TotalDue) AS [Distinct_Total_Due_Values]
    FROM dbo.adventureworks_orders
    GROUP BY
        SalesOrderID
)
SELECT
    (
        SELECT COUNT_BIG(*)
        FROM dbo.adventureworks_orders
    ) AS [Detail_Row_Count],
    COUNT_BIG(*) AS [Distinct_Order_Count],
    SUM(
        CASE
            WHEN Line_Count > 1 THEN 1
            ELSE 0
        END
    ) AS [Multi_Line_Order_Count],
    MAX(Line_Count) AS [Maximum_Lines_Per_Order],
    SUM(
        CASE
            WHEN Distinct_Freight_Values > 1
              OR Distinct_SubTotal_Values > 1
              OR Distinct_Tax_Values > 1
              OR Distinct_Total_Due_Values > 1
            THEN 1
            ELSE 0
        END
    ) AS [Orders_With_Inconsistent_Header_Values],
    CAST(
        (
            SELECT SUM(CAST(Freight AS DECIMAL(38, 2)))
            FROM dbo.adventureworks_orders
        )
        AS DECIMAL(38, 2)
    ) AS [Naive_Line_Level_Freight],
    CAST(
        SUM(CAST(Order_Freight AS DECIMAL(38, 2)))
        AS DECIMAL(38, 2)
    ) AS [Correct_Order_Level_Freight],
    CAST(
        (
            SELECT SUM(CAST(SubTotal AS DECIMAL(38, 2)))
            FROM dbo.adventureworks_orders
        )
        AS DECIMAL(38, 2)
    ) AS [Naive_Line_Level_SubTotal],
    CAST(
        SUM(CAST(Order_SubTotal AS DECIMAL(38, 2)))
        AS DECIMAL(38, 2)
    ) AS [Correct_Order_Level_SubTotal],
    CAST(
        (
            SELECT SUM(CAST(TaxAmt AS DECIMAL(38, 2)))
            FROM dbo.adventureworks_orders
        )
        AS DECIMAL(38, 2)
    ) AS [Naive_Line_Level_Tax],
    CAST(
        SUM(CAST(Order_Tax_Amount AS DECIMAL(38, 2)))
        AS DECIMAL(38, 2)
    ) AS [Correct_Order_Level_Tax],
    CAST(
        (
            SELECT SUM(CAST(TotalDue AS DECIMAL(38, 2)))
            FROM dbo.adventureworks_orders
        )
        AS DECIMAL(38, 2)
    ) AS [Naive_Line_Level_Total_Due],
    CAST(
        SUM(CAST(Order_Total_Due AS DECIMAL(38, 2)))
        AS DECIMAL(38, 2)
    ) AS [Correct_Order_Level_Total_Due]
FROM OrderLevelValues;


/*
Validated baseline

Source rows:
- Customers: 635
- Employees: 17
- Order detail rows: 60,919
- Distinct SalesOrderID values: 3,806
- Multi-line orders: 3,218
- Maximum lines per order: 72
- Product categories: 4
- Products: 295
- Product subcategories: 37
- Vendor-product rows: 460
- Vendors: 104

Key quality:
- Null graph keys: 0
- Duplicate graph keys: 0
- Duplicate vendor-product pairs: 0

Vendor-product relationships:
- Matched vendors: 460
- Matched products: 103
- Fully matched Vendor to Product relationships: 103
- Missing vendor matches: 0
- Missing product matches: 357
- Distinct supplied products: 83

Order header values:
- Orders with inconsistent repeated header values: 0
- Naive line-level freight: 77,209,717.21
- Correct order-level freight: 2,449,462.58
- Naive line-level subtotal: 2,537,243,275.76
- Correct order-level subtotal: 80,487,704.18
- Naive line-level tax: 247,071,094.63
- Correct order-level tax: 7,838,280.23
- Naive line-level total due: 2,861,524,087.61
- Correct order-level total due: 90,775,446.99
*/
