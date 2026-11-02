# Restore Guide

This document describes how to safely restore **Fabric Supply Chain Graph Analytics** from GitHub into Microsoft Fabric.

## Scope

Git restores supported Fabric item definitions only. It does not restore:

- OneLake table data;
- uploaded source files;
- execution or deployment history;
- credentials, tokens, or connections;
- workspace roles and permissions;
- capacity assignments;
- environment-specific object identifiers.

## Prerequisites

- Microsoft Fabric capacity or active Fabric Trial.
- A Fabric region where Graph is available.
- Permission to create and administer Fabric workspaces.
- GitHub access to this repository.
- A fine-grained GitHub personal access token scoped to this repository with `Contents: Read and write`.
- The official Microsoft Adventure Works Graph sample archive.

## Repository contents restored by Git

- `SupplyChainGraph.GraphModel`
- `SupplyChainGraphQueries.GraphQuerySet`
- `SupplyChainLakehouse.Lakehouse`

## Safe restoration procedure

### 1. Create the Development workspace

Create an empty Fabric workspace named:

`Fabric Supply Chain Graph Analytics - Dev`

Assign the workspace to an eligible Fabric capacity or Fabric Trial.

### 2. Connect the workspace to GitHub

Open:

`Workspace settings -> Git integration -> GitHub`

Configure:

- Repository: `fabric-supply-chain-graph-analytics`
- Branch: `main`
- Git folder: empty

Select the direction that updates the empty workspace from GitHub.

### 3. Verify restored item definitions

Confirm that the workspace contains:

- `SupplyChainLakehouse`
- `SupplyChainGraph`
- `SupplyChainGraphQueries`

Do not assume that data was restored. Git contains definitions, not OneLake data.

### 4. Restore source files

Download and extract the official Adventure Works Graph sample.

Upload the extracted source folder to the `Files` section of `SupplyChainLakehouse`.

Load the following folders as Parquet tables in schema `dbo`:

- `adventureworks_customers`
- `adventureworks_employees`
- `adventureworks_orders`
- `adventureworks_productcategories`
- `adventureworks_products`
- `adventureworks_productsubcategories`
- `adventureworks_vendorproduct`
- `adventureworks_vendors`

### 5. Validate Lakehouse data

Run `docs/VALIDATION.sql` against the Lakehouse SQL analytics endpoint.

Required baseline results:

- 8 non-empty source tables;
- 60,919 rows in `adventureworks_orders`;
- 460 rows in `adventureworks_vendorproduct`;
- 103 fully matched vendor-product relationships;
- 357 vendor-product rows without a matching Product node source row.

Stop restoration if these values differ unexpectedly. Determine whether the sample dataset changed before modifying the graph.

### 6. Reconnect Graph data if required

Open `SupplyChainGraph` and verify that all eight Lakehouse tables are available in the Data pane.

If the restored Graph Model does not have an active data connection:

1. Select `Get data`.
2. Select `SupplyChainLakehouse`.
3. Add all eight tables.
4. Verify the existing node and edge mappings before saving.

Do not recreate nodes or edges unless the restored definitions are missing.

### 7. Reload the Graph Model

Open `SupplyChainGraph` and confirm:

- Nodes: 8
- Edges: 6

Select `Save` once and wait for `Data load completed`.

Do not run queries while the graph is loading.

### 8. Validate Graph results

Run these saved queries in `SupplyChainGraphQueries`:

- `ValidateOrderCount` -> 60,919
- `ValidatePurchaseEdges` -> 60,919
- `ValidateContainsEdges` -> 60,919
- `ValidateProducesEdges` -> 103
- `ValidateSuppliedProducts` -> 83

Also run:

- `CustomerPurchaseHistory`
- `TopClothingVendors`
- `MultiVendorProducts`

Confirm that each query is linked to the restored `SupplyChainGraph` object.

### 9. Restore the Test environment

Create an empty workspace named:

`Fabric Supply Chain Graph Analytics - Test`

Create or reopen the two-stage Deployment Pipeline:

1. Development
2. Test

Assign the Development and Test workspaces and deploy:

- `SupplyChainLakehouse`
- `SupplyChainGraph`
- `SupplyChainGraphQueries`

### 10. Validate Test

Run in the Test QuerySet:

- `ValidateOrderCount` -> 60,919
- `ValidateProducesEdges` -> 103
- `ValidateSuppliedProducts` -> 83

A different Graph dependency object ID between Development and Test is expected because each workspace contains its own Graph Model object.

## Failure handling

- Do not repeat a failed load or deployment before identifying its cause.
- Do not delete a working item to resolve an environment-specific dependency ID.
- Do not assume a successful preview means data was materialized.
- Validate target objects with measurable queries.
- Never commit credentials or token values.

## Recovery completion criteria

Restoration is complete only when:

- all three Fabric items exist;
- all eight source tables are non-empty;
- Graph reports 8 nodes and 6 edge types;
- the Graph data load completes;
- validation counts match the documented baseline;
- Test deployment succeeds;
- Test validation returns the expected values.
