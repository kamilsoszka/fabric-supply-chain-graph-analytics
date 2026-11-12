# Operations Guide

This document defines the operating, validation, source-control, deployment, monitoring, and troubleshooting procedures for **Fabric Supply Chain Graph Analytics**.

## Components

| Component | Name |
|---|---|
| Development workspace | `Fabric Supply Chain Graph Analytics - Dev` |
| Test workspace | `Fabric Supply Chain Graph Analytics - Test` |
| Lakehouse | `SupplyChainLakehouse` |
| Graph Model | `SupplyChainGraph` |
| Graph QuerySet | `SupplyChainGraphQueries` |
| Git repository | `fabric-supply-chain-graph-analytics` |
| Git branch | `main` |
| Git folder | `/` |
| Deployment Pipeline | `Fabric Supply Chain Graph Analytics` |
| Deployment stages | `Development → Test` |

## Normal Operating Sequence

Use the following sequence for a source-data or Graph Model change:

1. Load or refresh source data in `SupplyChainLakehouse`.
2. Run `docs/VALIDATION.sql`.
3. Stop if source validation does not match the expected baseline.
4. Verify that Graph node and edge mappings remain compatible.
5. Save `SupplyChainGraph` once when a graph reload is required.
6. Wait for `Data load completed`.
7. Run the required Development GQL validation suite.
8. Review Source Control.
9. Remove nonfunctional layout-only changes.
10. Commit only intentional functional changes.
11. Confirm that Source Control contains no pending changes or updates.
12. Compare Development and Test in the Deployment Pipeline.
13. Select only the reviewed items that must be deployed.
14. Deploy once.
15. Verify environment-specific dependencies in Test.
16. Run the required Test validation queries.
17. Record evidence only after measurable validation succeeds.

Do not repeatedly save, reload, commit, or deploy while an earlier operation is still running.

## Source-Data Refresh

The Graph Model does not automatically materialize every Lakehouse source-data change.

After changing Lakehouse data:

1. confirm that all eight source tables exist;
2. run `docs/VALIDATION.sql`;
3. verify row counts, keys, and graph endpoint coverage;
4. confirm that source column names and data types remain compatible;
5. open `SupplyChainGraph`;
6. verify the existing node and edge mappings;
7. select `Save` once;
8. wait for `Data load completed`;
9. run the Development GQL validation suite.

Do not run GQL validation while Graph data is loading.

Do not repeatedly select `Save`.

Do not modify the Graph Model to conceal an unexpected source-data difference.

## Source Validation Baseline

The validated Lakehouse contains eight Delta tables.

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

Required key-quality results:

```text
Null graph keys: 0
Duplicate graph keys: 0
Duplicate Vendor-Product pairs: 0
```

Run the complete read-only validation from:

```text
docs/VALIDATION.sql
```

## Graph Topology Baseline

The Graph Model contains eight node types:

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

The Graph Model contains six edge types:

```text
Employee → sells → Order
Customer → purchases → Order
Order → contains → Product
Product → isOfType → ProductSubcategory
ProductSubcategory → belongsTo → ProductCategory
Vendor → produces → Product
```

The `VendorProduct` node is present but isolated in the validated topology.

The `adventureworks_vendorproduct` source table is used to derive:

```text
Vendor → produces → Product
```

Do not remove or redesign `VendorProduct` without a separate model decision, complete validation, and a new versioned release.

## Known Vendor-Product Data-Quality Condition

The source contains:

```text
Vendor-Product source rows: 460
Distinct Vendor-Product pairs: 460
Matched Vendor references: 460
Matched Product references: 103
Fully matched produces relationships: 103
Missing Vendor matches: 0
Missing Product matches: 357
Distinct supplied products: 83
```

The 357 missing Product matches are a known source-data condition.

Do not:

- create artificial Product nodes;
- suppress the validation result;
- report 460 valid `produces` edges;
- treat the missing endpoints as a Graph loading defect.

The expected number of materialized `produces` edges is:

```text
103
```

## Order Node Grain

The Graph node labeled `Order` uses:

```text
SalesOrderDetailID_K
```

as its unique key.

The actual grain is:

```text
One Order node = one sales-order detail line
```

The node does not represent one distinct sales-order header.

Validated values:

```text
Order detail nodes: 60,919
Distinct SalesOrderID values: 3,806
Multi-line orders: 3,218
Maximum lines per order: 72
```

### Line-compatible properties

The following properties can be analyzed at the node grain:

```text
lineTotal
unitPrice
unitPriceDiscount
```

### Repeated order-header properties

The following values are repeated across detail lines belonging to the same `salesOrderID`:

```text
freight
subTotal
taxAmt
totalDue
dueDate
shipDate
```

Do not calculate a simple sum of `freight`, `subTotal`, `taxAmt`, or `totalDue` across all `Order` nodes.

Deduplicate or group by `salesOrderID` before aggregating header-level values.

Validated comparisons:

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

## Required Development GQL Validation

Run the saved validation queries after a source-data, Graph Model, or QuerySet change.

### ValidateOrderCount

Required result:

```text
num_order_lines = 60919
num_orders = 3806
```

### ValidatePurchaseEdges

Required result:

```text
purchase_edge_count = 60919
```

### ValidateContainsEdges

Required result:

```text
contains_edge_count = 60919
```

### ValidateProducesEdges

Required result:

```text
produces_edge_count = 103
```

### ValidateSuppliedProducts

Required result:

```text
supplied_products = 83
```

### CustomerPurchaseHistory

Confirm that the query returns the selected customer and related Order-line and Product data.

Do not interpret each returned `Order` node as a distinct order header.

### TopClothingVendors

The result must contain:

```text
vendorName
subCategoryName
num_products
num_orders
num_order_lines
```

Required rule:

```text
num_orders <= num_order_lines
```

The query must:

- count distinct Product nodes;
- count distinct `salesOrderID` values as orders;
- count `Order` nodes separately as order lines;
- avoid summing repeated header-level monetary properties;
- use deterministic sorting.

### MultiVendorProducts

The result must contain:

```text
productName
vendor_count
```

The query must:

- group by the Product node and product name;
- count distinct Vendor nodes;
- filter to `vendor_count > 1`;
- use deterministic sorting.

The validated result contains products with:

```text
vendor_count = 2
```

## Git Workflow

### Before a Commit

1. confirm the workspace is connected to the intended repository;
2. confirm the branch is `main`;
3. confirm the Git folder is `/`;
4. review every changed Fabric item;
5. inspect the complete exported definition;
6. verify environment-specific dependency identifiers;
7. check files and screenshots for secrets or private data;
8. confirm that no token, password, credential, tenant identifier, or private connection string is present;
9. commit only intentional changes.

### Graph Model Layout Metadata

Opening or navigating the Graph Model can create changes such as:

```text
modelLayout.pan.x
modelLayout.pan.y
modelLayout.zoomLevel
```

These changes affect only the Graph canvas position and zoom.

Do not commit a change that contains only layout metadata.

Review the comparison and use `Undo` for layout-only changes.

### QuerySet Export Format

`SupplyChainGraphQueries` can be exported as one long line in:

```text
exportedDefinition.json
```

A change to one query can therefore appear as one removed and one added line for the entire file.

Before committing:

- search the exported definition for the modified query names;
- confirm the intended GQL changes;
- verify that unchanged queries remain present;
- verify that the Graph dependency remains correct;
- confirm that no unrelated model or workspace identifier was introduced.

### Commit Scope

Use small commits that contain one logical change.

Examples:

```text
Fix graph query grain and deterministic ranking
Expand source and graph validation coverage
Harden graph restoration and environment validation
```

Do not combine:

- GQL logic changes;
- Graph Model redesign;
- documentation rewrites;
- unrelated screenshots;
- environment-specific identifiers;

unless the changes are inseparable and reviewed together.

### What Git Stores

Git stores supported Fabric item definitions and repository documentation.

Git does not store:

- OneLake table data;
- Graph materialized data;
- query execution history;
- Deployment Pipeline history;
- workspace roles;
- capacity assignments;
- credentials or tokens;
- a complete environment backup.

## Deployment Procedure

### Before Deployment

1. confirm Development validation succeeded;
2. confirm the intended commit is on `main`;
3. confirm Source Control contains no changes or updates;
4. open the Deployment Pipeline;
5. compare Development with Test;
6. identify the exact changed item;
7. inspect whether differences are functional or environment-specific.

### Selective Deployment

Do not automatically deploy all three Fabric items.

Select only reviewed items.

Examples:

- a QuerySet-only change: deploy `SupplyChainGraphQueries`;
- a Graph Model change: deploy `SupplyChainGraph` and only required dependent items;
- a Lakehouse definition change: deploy `SupplyChainLakehouse` and required dependencies after reviewing the effect.

Do not choose `Select related` without reviewing the additional items.

Deployment copies metadata. It does not copy OneLake table data.

### After Deployment

1. wait for a successful deployment status;
2. verify that the intended number of items was deployed;
3. do not treat deployment success as end-to-end validation;
4. open the Test QuerySet;
5. confirm that the QuerySet uses the local Test Graph Model;
6. run the changed and critical Test queries;
7. verify the expected results;
8. record deployment and validation evidence.

## Environment-Specific QuerySet Dependency

Development and Test contain separate Graph Model objects.

The QuerySet dependency can therefore differ through fields such as:

```text
ArtifactObjectId
modelReference.itemId
workspaceId
```

The Deployment Pipeline can continue to display:

```text
Different from source
```

when the only difference is the local Test Graph dependency.

This is expected.

Do not repeatedly deploy the QuerySet solely to make the comparison display `Same as source`.

Do not replace a working Test Graph dependency with the Development Graph object identifier.

After an intentional QuerySet deployment, validate that the Test QuerySet still runs against the Test Graph Model.

## Required Test Validation

After a Graph Model or initial full deployment, run:

```text
ValidateOrderCount
ValidatePurchaseEdges
ValidateContainsEdges
ValidateProducesEdges
ValidateSuppliedProducts
```

After a QuerySet-only change, run the changed queries and at least one dependency validation query.

For the hardened QuerySet deployment, the required Test checks are:

### ValidateOrderCount

```text
num_order_lines = 60919
num_orders = 3806
```

### TopClothingVendors

Confirm:

- five result rows;
- columns `vendorName`, `subCategoryName`, `num_products`, `num_orders`, and `num_order_lines`;
- `num_orders <= num_order_lines` for every row.

### MultiVendorProducts

Confirm:

- columns `productName` and `vendor_count`;
- all returned products have more than one Vendor;
- the validated results use `vendor_count = 2`.

Do not edit or save Test queries merely to execute validation.

## Monitoring

Monitor:

- Graph save and data-load completion messages;
- failed Graph loads;
- Fabric capacity utilization;
- Git synchronization failures;
- unexpected Source Control changes;
- Deployment Pipeline status;
- changed validation results;
- Test QuerySet dependency failures;
- Trial expiration date.

For every incident, record:

- time;
- workspace;
- affected item;
- operation;
- error message;
- activity or correlation identifier, if available;
- last successful operation;
- corrective action;
- validation result after correction.

Do not commit diagnostic logs that contain tenant, workspace, item, session, request, or connection identifiers.

## Troubleshooting

### Graph Query Returns an Unexpected Count

1. do not rerun immediately;
2. compare Graph results with `docs/VALIDATION.sql`;
3. verify source row counts;
4. inspect null and duplicate keys;
5. check whether both edge endpoints exist;
6. confirm node keys and edge mappings;
7. confirm whether Graph loading completed;
8. reload only after identifying the cause.

### ValidateOrderCount Returns 60,919 as num_orders

The alias is incorrect if `count(o)` is labeled as the number of distinct orders.

Use:

```gql
MATCH (o:`Order`)
RETURN
    count(o) AS num_order_lines,
    count(DISTINCT o.salesOrderID) AS num_orders
```

Expected:

```text
num_order_lines = 60919
num_orders = 3806
```

### A Monetary Total Is Approximately 31 Times Too High

Check whether an order-header value was summed across line-level `Order` nodes.

Do not sum:

```text
freight
subTotal
taxAmt
totalDue
```

without grouping or deduplicating by `salesOrderID`.

### QuerySet Shows No Edges in Query Builder

1. verify that Graph loading completed;
2. refresh the browser once;
3. reopen the QuerySet;
4. reopen the Components pane;
5. confirm that all six edge types appear;
6. verify the local Graph dependency.

Do not recreate the Graph Model to fix a stale panel.

Do not save an unchanged QuerySet unless a save operation is specifically required.

### Deployment Succeeds but QuerySet Is Different from Source

1. open Compare;
2. inspect `ArtifactObjectId`, `modelReference.itemId`, and `workspaceId`;
3. confirm that Test references the Test Graph Model;
4. run the Test validation queries;
5. do not redeploy if only the environment-specific dependency differs and validation passes.

### Deployment Completes but Test Queries Fail

1. confirm that Test has the required Lakehouse source data;
2. verify the Test Graph data connection;
3. confirm Graph loading completed;
4. verify the QuerySet dependency;
5. compare the Test source counts with the baseline;
6. inspect the changed query definition;
7. do not delete or recreate working items before locating the failed dependency.

### Source Control Shows Graph Model Changes After Viewing the Model

Open the comparison.

If the differences contain only:

```text
modelLayout.pan.x
modelLayout.pan.y
modelLayout.zoomLevel
```

use `Undo`.

Do not create a layout-only commit.

### Git Branch Is Unavailable

A completely empty GitHub repository has no branch.

Create a non-secret initial file such as:

```text
README.md
```

Commit the file to `main`, then reconnect Fabric.

## Security Operations

- use repository-scoped GitHub authentication;
- grant only the minimum required repository permissions;
- never place tokens in documentation, screenshots, Fabric definitions, or commit messages;
- rotate or revoke credentials when they expire or are no longer required;
- review public commits for data disclosure;
- restrict workspace access according to least privilege;
- verify Development and Test access independently;
- do not publish tenant, workspace, object, session, request, or connection identifiers.

## Change Management

Before changing nodes, edges, keys, properties, query logic, or table mappings:

1. capture the current validation results;
2. define the business and technical purpose;
3. identify the affected grain;
4. check key compatibility and data types;
5. apply the change in Development only;
6. reload Graph data only when required;
7. run the complete relevant validation suite;
8. inspect Source Control;
9. commit only reviewed changes;
10. confirm a clean synchronized state;
11. compare Development and Test;
12. deploy only the required items;
13. validate Test;
14. update documentation and evidence;
15. create a new semantic version when the project milestone warrants a release.

## Project Evidence

Retain the following evidence in:

```text
docs/screenshots/
```

Required files:

```text
graph-model-nodes-edges.png
top-clothing-vendors-results.png
validate-produces-edges.png
deployment-history-success.png
```

Evidence must not expose:

- tokens;
- credentials;
- private connection information;
- tenant identifiers;
- personal data that is not required for the project;
- diagnostic identifiers that are not necessary for public documentation.

## Operational Completion Criteria

A change is operationally complete only when:

- the intended Development change is measurable;
- source and Graph validation pass;
- Source Control contains only reviewed changes;
- the commit exists on `main`;
- Development is synchronized;
- the Deployment Pipeline scope contains only intended items;
- deployment succeeds;
- environment-specific dependencies remain correct;
- required Test queries pass;
- documentation reflects the implemented behavior;
- public evidence contains no secrets or private information.
