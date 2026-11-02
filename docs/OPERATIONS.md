# Operations Guide

This document defines the operating procedure for **Fabric Supply Chain Graph Analytics**.

## Components

- Development workspace: `Fabric Supply Chain Graph Analytics - Dev`
- Test workspace: `Fabric Supply Chain Graph Analytics - Test`
- Lakehouse: `SupplyChainLakehouse`
- Graph Model: `SupplyChainGraph`
- Graph QuerySet: `SupplyChainGraphQueries`
- Git branch: `main`
- Deployment stages: Development and Test

## Normal operating sequence

1. Load or refresh source data in `SupplyChainLakehouse`.
2. Validate source tables with `docs/VALIDATION.sql`.
3. Open `SupplyChainGraph` and select `Save` to reload graph data.
4. Wait for `Data load completed`.
5. Run all saved validation queries in Development.
6. Commit supported item-definition changes to GitHub.
7. Review the Deployment Pipeline comparison.
8. Deploy the three Fabric items to Test.
9. Run the required Test queries.
10. Record evidence only after measurable validation succeeds.

## Source-data refresh

The Graph Model does not apply structural or source-data changes automatically.

After changing Lakehouse data:

1. Validate the new source state.
2. Confirm that key columns and data types remain compatible.
3. Open `SupplyChainGraph`.
4. Select `Save` once.
5. Wait for the graph reload to finish.
6. Run the validation query suite.

Do not repeatedly select `Save` while a graph load is running.

## Required Development validation

Run these saved GQL queries:

| Query | Required result |
|---|---:|
| `ValidateOrderCount` | 60,919 |
| `ValidatePurchaseEdges` | 60,919 |
| `ValidateContainsEdges` | 60,919 |
| `ValidateProducesEdges` | 103 |
| `ValidateSuppliedProducts` | 83 |

Also verify that:

- `CustomerPurchaseHistory` returns `Carla Adams` with related orders and products;
- `TopClothingVendors` returns five ranked rows;
- `MultiVendorProducts` returns products with `vendor_count > 1`.

## Known data-quality condition

`adventureworks_vendorproduct` contains:

- 460 distinct vendor-product source pairs;
- 460 valid vendor references;
- 103 valid product references;
- 103 fully matched Graph edges;
- 357 product references without a matching Product source row.

This is a documented sample-data condition. Do not manufacture missing Product nodes or suppress the validation result.

## Git workflow

### Before a commit

1. Confirm the workspace is connected to the intended repository and `main` branch.
2. Review every changed Fabric item.
3. Check screenshots and definitions for secrets or private data.
4. Confirm that no token, password, or credential is present.
5. Commit only intentional changes.

### What Git stores

Git stores supported Fabric item definitions. Git does not store:

- OneLake table data;
- execution history;
- Deployment Pipeline history;
- workspace permissions;
- credentials or tokens;
- a complete environment backup.

### Recommended commit prefixes

- `feat:` functional addition
- `fix:` defect correction
- `docs:` documentation
- `test:` validation change
- `chore:` repository maintenance

## Deployment procedure

1. Confirm all Development validation checks pass.
2. Open the Deployment Pipeline.
3. Compare Development with Test.
4. Select:
   - `SupplyChainLakehouse`
   - `SupplyChainGraph`
   - `SupplyChainGraphQueries`
5. Deploy once.
6. Wait for a successful deployment status.
7. Do not treat successful deployment alone as end-to-end validation.
8. Run the required Test queries.

## Required Test validation

Minimum post-deployment checks:

- `ValidateOrderCount` -> 60,919
- `ValidateProducesEdges` -> 103
- `ValidateSuppliedProducts` -> 83

The QuerySet can appear different from Development because the Test QuerySet references the Test Graph Model object ID. This environment-specific dependency is expected when the query definitions remain unchanged and Test validation passes.

## Monitoring

Monitor:

- Graph save and load completion messages;
- Fabric capacity utilization;
- failed Git synchronization operations;
- Deployment Pipeline status;
- validation result changes;
- Trial expiration date.

Record the time, affected item, error message, and last successful operation for every incident.

## Troubleshooting

### Graph query returns an unexpected count

1. Do not rerun immediately.
2. Compare the Graph count with the Lakehouse SQL validation.
3. Check whether both edge endpoint keys match existing node source rows.
4. Inspect null keys and unmatched foreign keys.
5. Verify the Graph Model mapping.
6. Reload only after identifying the cause.

### QuerySet shows no edges in Query Builder

1. Save the QuerySet.
2. Refresh the browser once.
3. Reopen the Components pane.
4. Confirm that all six edge types appear.

Do not recreate the Graph Model to resolve a stale Query Builder panel.

### Deployment succeeds but QuerySet is different from source

1. Open Compare.
2. Check whether only the Graph dependency object ID differs.
3. Run the Test validation queries.
4. Do not redeploy if the difference is environment-specific and validation passes.

### Git branch is unavailable

A completely empty GitHub repository has no branch. Create an initial non-secret file, such as `README.md`, commit it to `main`, and then reconnect Fabric.

## Security operations

- Use a repository-scoped fine-grained token.
- Grant only `Contents: Read and write` unless additional permissions are demonstrably required.
- Never place tokens in README files, screenshots, Fabric definitions, or commit messages.
- Rotate or revoke the token when it expires or is no longer needed.
- Review every public commit for data disclosure.

## Change management

Before changing nodes, edges, keys, properties, or table mappings:

1. Capture the current validation results.
2. Confirm the business purpose of the change.
3. Check key compatibility and data types.
4. Apply the change in Development only.
5. Reload the graph.
6. Run the complete validation suite.
7. Commit to Git.
8. Deploy to Test.
9. Repeat Test validation.

## Project completion evidence

Retain these screenshots in `docs/screenshots`:

- `graph-model-nodes-edges.png`
- `top-clothing-vendors-results.png`
- `validate-produces-edges.png`
- `deployment-history-success.png`
