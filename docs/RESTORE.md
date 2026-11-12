# Restore Guide

This document describes how to safely restore **Fabric Supply Chain Graph Analytics** from GitHub into Microsoft Fabric.

## Scope

Git restores supported Microsoft Fabric item definitions and project metadata.

Git does not restore:

- OneLake table data;
- uploaded source files;
- Graph materialized data;
- query execution history;
- deployment history;
- credentials, tokens, or connections;
- workspace roles and permissions;
- capacity assignments;
- environment-specific Fabric object identifiers.

The restored workspace is not considered operational until source data, Graph data, dependencies, and validation results have been verified.

## Prerequisites

- Microsoft Fabric capacity or an active Fabric Trial;
- a Fabric region where Graph is available;
- permission to create and administer Fabric workspaces;
- permission to use Fabric Git integration;
- permission to use Fabric Deployment Pipelines;
- access to this GitHub repository;
- repository-scoped GitHub authentication;
- the official Microsoft Adventure Works Graph sample archive.

Do not store credentials, token values, tenant identifiers, or private connection information in repository files.

## Repository Items Restored by Git

The repository contains definitions for:

```text
SupplyChainLakehouse.Lakehouse
SupplyChainGraph.GraphModel
SupplyChainGraphQueries.GraphQuerySet
```

The repository also contains:

```text
docs/OPERATIONS.md
docs/RESTORE.md
docs/VALIDATION.sql
docs/screenshots/
README.md
LICENSE
```

## Restoration Order

Use the following order:

```text
Development workspace
→ Git synchronization
→ Lakehouse source data
→ Source validation
→ Graph Model connection and load
→ Graph QuerySet dependency
→ GQL validation
→ Test workspace
→ Deployment Pipeline
→ Test data and Graph validation
```

Do not run Graph queries before the Graph data load has completed.

# Development Restoration

## 1. Create the Development Workspace

Create an empty Fabric workspace named:

```text
Fabric Supply Chain Graph Analytics - Dev
```

Assign the workspace to eligible Microsoft Fabric capacity or Fabric Trial capacity.

Limit workspace access according to the principle of least privilege.

For the portfolio implementation, the validated access model contains one project administrator and no additional users or groups.

## 2. Connect the Workspace to GitHub

Open:

```text
Workspace settings
→ Git integration
→ GitHub
```

Configure:

```text
Repository: fabric-supply-chain-graph-analytics
Branch: main
Git folder: /
```

Update the empty workspace from GitHub.

Do not initialize an unrelated workspace state over the repository.

## 3. Verify Restored Fabric Items

Confirm that the Development workspace contains:

```text
SupplyChainLakehouse
SupplyChainGraph
SupplyChainGraphQueries
```

The Lakehouse SQL analytics endpoint is created as a dependent Lakehouse component and is not a separate project artifact.

Confirm that Source Control contains no unexpected changes.

Opening or navigating the Graph Model can modify layout metadata such as:

```text
modelLayout.pan.x
modelLayout.pan.y
modelLayout.zoomLevel
```

Do not commit changes that contain only Graph canvas position or zoom metadata.

## 4. Restore the Source Files

Download and extract the official Adventure Works Graph sample.

Upload the extracted source folder to the `Files` area of:

```text
SupplyChainLakehouse
```

Load the following datasets as Delta tables in schema `dbo`:

```text
adventureworks_customers
adventureworks_employees
adventureworks_orders
adventureworks_productcategories
adventureworks_products
adventureworks_productsubcategories
adventureworks_vendorproduct
adventureworks_vendors
```

Git synchronization does not restore the contents of these tables.

## 5. Validate the Lakehouse Source Data

Run:

```text
docs/VALIDATION.sql
```

against the `SupplyChainLakehouse` SQL analytics endpoint.

The script is read-only and validates:

- all eight source-table row counts;
- null graph keys;
- duplicate graph keys;
- the composite Vendor-Product source grain;
- graph endpoint coverage;
- customer, employee, product, subcategory, and category relationships;
- the actual grain of the `Order` node source;
- repeated order-header values;
- correct order-level monetary totals.

### Validated source baseline

| Source table | Expected rows |
|---|---:|
| `adventureworks_customers` | 635 |
| `adventureworks_employees` | 17 |
| `adventureworks_orders` | 60,919 |
| `adventureworks_productcategories` | 4 |
| `adventureworks_products` | 295 |
| `adventureworks_productsubcategories` | 37 |
| `adventureworks_vendorproduct` | 460 |
| `adventureworks_vendors` | 104 |

Expected graph-key results:

```text
Null graph keys: 0
Duplicate graph keys: 0
Duplicate Vendor-Product pairs: 0
```

Stop restoration if the source values differ unexpectedly.

Determine whether:

- the Microsoft sample changed;
- the wrong source archive was loaded;
- only part of a source folder was loaded;
- a table was loaded more than once;
- the schema or key columns changed.

Do not modify the Graph Model to conceal unexpected source differences.

## 6. Validate the Vendor-Product Source Limitation

Expected values:

```text
Vendor-Product source rows: 460
Distinct Vendor-Product pairs: 460
Rows with a matching Vendor: 460
Rows with a matching Product: 103
Fully matched Vendor-to-Product relationships: 103
Missing Vendor matches: 0
Missing Product matches: 357
Distinct supplied products: 83
```

The 357 missing Product matches are a known source-data limitation.

Do not create artificial Product nodes to force all 460 source pairs into the graph.

The Graph should materialize only the 103 relationships for which both endpoint nodes exist.

## 7. Reconnect Graph Data if Required

Open:

```text
SupplyChainGraph
```

Verify that all eight Lakehouse tables are available in the Data pane.

If the restored Graph Model does not have an active Lakehouse connection:

1. select `Get data`;
2. select `SupplyChainLakehouse`;
3. add all eight tables;
4. verify the existing node definitions;
5. verify the existing edge definitions;
6. save only after confirming that the restored mappings are correct.

Do not recreate nodes or edges if the Git-restored definitions are already present.

## 8. Verify Graph Topology

The Graph Model must contain eight node types:

```text
Customer
Employee
Order
ProductCategory
Product
ProductSubcategory
VendorProduct
Vendor
```

The Graph Model must contain six edge types:

```text
Employee → sells → Order
Customer → purchases → Order
Order → contains → Product
Product → isOfType → ProductSubcategory
ProductSubcategory → belongsTo → ProductCategory
Vendor → produces → Product
```

The `VendorProduct` node is present but is not connected by an edge in the validated topology.

The source table is used to derive the direct relationship:

```text
Vendor → produces → Product
```

Do not remove the `VendorProduct` node during restoration without a separate model-design decision and a new validated release.

## 9. Understand the `Order` Node Grain

The node labeled `Order` uses:

```text
SalesOrderDetailID_K
```

as its unique key.

Therefore:

```text
One Order node = one sales-order detail line
```

The node does not represent a distinct sales-order header.

Validated grain:

```text
Order detail nodes: 60,919
Distinct SalesOrderID values: 3,806
Multi-line orders: 3,218
Maximum lines per order: 72
```

The following properties are line-level or compatible with line-level analysis:

```text
lineTotal
unitPrice
unitPriceDiscount
```

The following properties originate from the order header and are repeated for every detail line belonging to the same `SalesOrderID`:

```text
freight
subTotal
taxAmt
totalDue
dueDate
shipDate
```

Do not calculate simple sums of `freight`, `subTotal`, `taxAmt`, or `totalDue` across all `Order` nodes.

Deduplicate or group by `salesOrderID` before aggregating header-level values.

Validated monetary comparison:

| Metric | Naive line-level sum | Correct order-level sum |
|---|---:|---:|
| Freight | 77,209,717.21 | 2,449,462.58 |
| SubTotal | 2,537,243,275.76 | 80,487,704.18 |
| Tax | 247,071,094.63 | 7,838,280.23 |
| Total Due | 2,861,524,087.61 | 90,775,446.99 |

Expected orders with inconsistent repeated header values:

```text
0
```

## 10. Load the Graph Model

Open `SupplyChainGraph` and confirm:

```text
Node types: 8
Edge types: 6
```

Save the Graph Model only when necessary and wait for:

```text
Data load completed
```

Do not run GQL queries while Graph data is loading.

If saving creates only pan or zoom changes in Source Control, review and undo those nonfunctional changes instead of committing them.

## 11. Verify the Graph QuerySet Dependency

Open:

```text
SupplyChainGraphQueries
```

Confirm that the QuerySet is connected to the `SupplyChainGraph` object in the same Development workspace.

A Graph QuerySet stores an environment-specific Graph dependency identifier.

Do not manually copy an object identifier from another workspace.

## 12. Validate Development GQL Results

Run the saved validation queries.

### ValidateOrderCount

Expected result:

```text
num_order_lines = 60919
num_orders = 3806
```

### ValidatePurchaseEdges

Expected result:

```text
purchase_edge_count = 60919
```

### ValidateContainsEdges

Expected result:

```text
contains_edge_count = 60919
```

### ValidateProducesEdges

Expected result:

```text
produces_edge_count = 103
```

### ValidateSuppliedProducts

Expected result:

```text
supplied_products = 83
```

Also execute:

```text
CustomerPurchaseHistory
TopClothingVendors
MultiVendorProducts
```

### TopClothingVendors validation

The result must contain:

```text
vendorName
subCategoryName
num_products
num_orders
num_order_lines
```

For every row:

```text
num_orders <= num_order_lines
```

The query must count distinct `salesOrderID` values as orders and must not treat the 60,919 line-level nodes as 60,919 distinct orders.

### MultiVendorProducts validation

The result must contain:

```text
productName
vendor_count
```

The validated results contain products with:

```text
vendor_count = 2
```

# Test Restoration

## 13. Create the Test Workspace

Create an empty Fabric workspace named:

```text
Fabric Supply Chain Graph Analytics - Test
```

Assign the workspace to eligible capacity.

Apply the required access model separately from Development.

Git and Deployment Pipelines do not restore workspace roles.

## 14. Configure the Deployment Pipeline

Create or reopen the Deployment Pipeline:

```text
Fabric Supply Chain Graph Analytics
```

Use two stages:

```text
Development → Test
```

Assign:

- `Fabric Supply Chain Graph Analytics - Dev` to Development;
- `Fabric Supply Chain Graph Analytics - Test` to Test.

## 15. Deploy the Fabric Items

Review the comparison before deployment.

The initial deployment can include:

```text
SupplyChainLakehouse
SupplyChainGraph
SupplyChainGraphQueries
```

Only metadata is deployed. OneLake table data is not copied to Test.

After deployment:

1. restore or verify the Test Lakehouse source data;
2. verify all eight Test tables;
3. validate Test row counts;
4. verify the Test Graph data connection;
5. reload the Test Graph when required;
6. verify the Test QuerySet dependency.

## 16. Preserve the Environment-Specific QuerySet Dependency

Development and Test contain separate `SupplyChainGraph` objects.

Therefore, `SupplyChainGraphQueries` can remain marked:

```text
Different from source
```

when the only difference is the environment-specific Graph dependency identifier, such as:

```text
ArtifactObjectId
modelReference.itemId
workspaceId
```

This difference is expected.

Do not repeatedly deploy the QuerySet only to make the comparison display `Same as source`.

Do not overwrite a working Test dependency with the Development Graph object identifier.

After deploying a deliberate QuerySet code change, verify that the Test QuerySet still executes against the local Test Graph Model.

## 17. Validate Test

Run the changed or critical Test queries.

### ValidateOrderCount

Expected:

```text
num_order_lines = 60919
num_orders = 3806
```

### ValidateProducesEdges

Expected:

```text
produces_edge_count = 103
```

### ValidateSuppliedProducts

Expected:

```text
supplied_products = 83
```

### TopClothingVendors

Confirm:

- five result rows;
- columns `vendorName`, `subCategoryName`, `num_products`, `num_orders`, and `num_order_lines`;
- `num_orders <= num_order_lines` in every row.

### MultiVendorProducts

Confirm:

- columns `productName` and `vendor_count`;
- returned products have more than one supplier;
- the validated result uses `vendor_count = 2`.

A successful query execution confirms that the QuerySet is connected to a working Graph Model in the Test workspace.

# Failure Handling

- Do not repeat a failed Graph load or deployment before identifying the cause.
- Do not delete a working item to resolve an environment-specific dependency identifier.
- Do not manually copy Development object identifiers into Test.
- Do not assume a successful metadata deployment restored OneLake data.
- Do not assume a successful Graph preview means the complete graph was materialized.
- Do not commit Graph canvas pan or zoom changes as functional updates.
- Do not create artificial Product nodes to hide the 357 missing Product matches.
- Do not aggregate repeated order-header values at the line-node grain.
- Validate target objects through measurable SQL and GQL queries.
- Never commit credentials, tokens, tenant identifiers, private connection details, or diagnostic logs.

# Recovery Completion Criteria

Restoration is complete only when:

- all three Fabric items exist in Development;
- all eight source tables are present and non-empty;
- source row counts match the documented baseline;
- all graph-source keys contain zero nulls and zero duplicates;
- the Graph Model contains eight node types and six edge types;
- the Graph data load completes successfully;
- Development GQL validation matches the documented baseline;
- the Test workspace and Deployment Pipeline are configured;
- the required item definitions are deployed successfully;
- Test contains or can access the required source data;
- the Test Graph data load completes;
- the Test QuerySet points to the local Test Graph Model;
- Test validation returns the expected results;
- Source Control contains no unintended changes.
