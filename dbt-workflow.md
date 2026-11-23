# 🕵️🕵️🕵️ dbt Project Workflow & Architecture Guide 🕵️🕵️🕵️

This document outlines the end-to-end data pipeline workflow for the **`liquor_sales`** dbt project, detailing how configuration, ingestion, and transformation map to the Google BigQuery data warehouse.

## Phase 1: Configuration (The Blueprint)

Before executing any commands, dbt relies on two main configuration files to establish connections and route data.

*   **`profiles.yml` (Hidden in `~/.dbt/`)**: Defines the connection to BigQuery (Project ID, credentials) and sets the **Default Dataset/Schema** name (e.g., `liquor_demo`).
*   **`dbt_project.yml`**: The main configuration file for the repository.
    *   Defines directory paths (e.g., `model-paths: ["models"]`).
    *   **Crucial Step (Custom Schema Routing)**: Routes specific models to specific datasets in BigQuery. 

```yaml
# Snippet from dbt_project.yml
models:
  liquor_sales:      # Project Name
    star:            # Folder Name inside models/
      +materialized: table  # Save as physical table, not a view
      +schema: star         # Append "_star" to the default dataset
```

## Phase 2: Ingestion & History (Getting Data In)

*   **`dbt seed`**: 
    *   **Action**: Looks inside the `seeds/` folder for `.csv` files.
    *   **Result**: Loads the CSV data into the **Default Dataset** (`liquor_demo`) as tables. *(Note: If the folder is empty, dbt will complete successfully but ingest nothing).*
*   **`dbt snapshot`**: 
    *   **Action**: Looks inside the `snapshots/` folder (e.g., `store_snapshot.sql`) and runs the logic to track historical changes (Type 2 Slowly Changing Dimensions).
    *   **Result**: Creates the **`snapshots` Dataset** in BigQuery. Includes system columns like `dbt_valid_from` and `dbt_valid_to` to track active vs. historical records.

### Phase 3: Transformation & Modeling (`dbt run`)

*   **Action**: Compiles the SQL files in the `models/` folder and executes them in BigQuery.
*   **Result (Default Routing)**: Models placed directly in the `models/` folder (e.g., `fact_sales.sql`) go to the **Default Dataset** (`liquor_demo`).
*   **Result (Custom Routing)**: Because of the `dbt_project.yml` configuration, files located inside the `models/star/` directory (`dim_item.sql`, `dim_store.sql`) are pushed to the **Custom Dataset**: `liquor_demo_star`.
*   **Materialization**: The `+materialized: table` setting applied to the `star` folder ensures these models become permanent physical tables in BigQuery for fast querying, rather than standard views.

<img width="819" height="501" alt="image" src="https://github.com/user-attachments/assets/2b3e430c-6035-401e-9e91-1bda206f8f31" />




## Phase 4: Lineage & Documentation

*   **`schema.yml` & `sources.yml`**: Used to define tests (checking for nulls, uniqueness) and document tables.
*   **`dbt docs generate`** followed by **`dbt docs serve`** (run in terminal): Builds a local website showing a visual lineage graph of your data (from sources -> seeds -> models -> final tables).


<img width="1321" height="863" alt="image" src="https://github.com/user-attachments/assets/21d028dd-5534-4793-8dde-907b4091a945" />


---

## 🗺️ Summary Mapping: Code to BigQuery

Here is how the VS Code file structure maps to the BigQuery UI:

| VS Code Location | dbt Command | BigQuery Dataset | Type |
| :--- | :--- | :--- | :--- |
| `seeds/*.csv` | `dbt seed` | `liquor_demo` | Table |
| `snapshots/store_snapshot.sql` | `dbt snapshot` | `snapshots` | Table |
| `models/star/*.sql` | `dbt run` | `liquor_demo_star` | Table |
| `models/*.sql` (root) | `dbt run` | `liquor_demo` | View/Table |

---

## 📁 Project Directory Structure

```text
liquor_sales/
├── analyses/
├── logs/
├── macros/
├── models/
│   ├── star/                 # Custom Routing -> liquor_demo_star
│   │   ├── dim_item.sql      # use SQL query to extract data from item_snapshot
│   │   ├── dim_store.sql     # use SQL query to extract data from store_snapshot
│   │   └── schema.yml        
│   ├── fact_sales.sql        # Default Routing -> liquor_demo | use SQL query to extract data from liquor sales dataset -> sales table
│   ├── schema.yml
│   └── sources.yml           # Define data source name, database and table name
├── seeds/                    # Place .csv files here
├── snapshots/
│   ├── item_snapshot.sql     # Generates the 'snapshots' dataset
│   └── store_snapshot.sql    # Generates the 'snapshots' dataset
├── tests/
├── dbt_project.yml           # Main config (Routing & Materialization)
└── profiles.yml              # Connection config (Default Schema)
```





# 📌📌 dbt Configuration: Mastering `.yml` Files  📌📌

In dbt, `.yml` files (`schema.yml`, `sources.yml`) are the **control center for Documentation, Testing, and Data Lineage**. 

While `.sql` files contain the actual data transformation logic, `.yml` files describe *what* the data is, *how* to validate it, and *how* models connect to each other.

## 1. `sources.yml` (Defining Raw Data)
This file tells dbt where your raw, unmigrated data lives (e.g., data loaded by external tools like Fivetran or Airbyte, or public datasets).

*   **Purpose:** To map database schemas and tables so they can be referenced in dbt models.
*   **Example:** Mapping the public Iowa Liquor Sales dataset in BigQuery.
    ```yaml
    version: 2
    sources:
      - name: iowa_liquor_sales
        database: bigquery-public-data
        tables:
          - name: sales
    ```
*   **Benefit:** Allows you to use `{{ source('iowa_liquor_sales', 'sales') }}` in your SQL instead of hardcoding the full table path. It also creates the very first node in your Lineage Graph.

## 2. `schema.yml` (Documentation & Data Quality)
You can have multiple `schema.yml` files (e.g., one for staging, one for marts). dbt uses them to document and test your models.

### A. Documentation
*   Add `description:` tags to your models and columns.
*   **Result:** When you run `dbt docs generate`, these descriptions populate a searchable data dictionary for your team.

### B. Data Quality Tests
Instead of writing manual SQL checks, you define rules in YAML. When you run `dbt test`, dbt runs the underlying SQL to verify them.

*   **Primary Key Testing:** 
    ```yaml
    tests:
      - unique
      - not_null
    ```
*   **Foreign Key Testing (Relationships):** Ensures referential integrity in your Star Schema.
    ```yaml
    tests:
      - relationships:
          arguments:
            to: ref('dim_store')
            field: store_number
    ```
    *This tells dbt: "Check that every `store_number` in `fact_sales` actually exists in `dim_store`."*

### C. Dependencies & Lineage
By using `ref('dim_store')` inside your YAML tests, dbt automatically knows that `fact_sales` depends on `dim_store`. When running `dbt run`, it will build the dimensions **before** the fact tables.

---

## 🚀 Execution Commands
Once your `.yml` files are configured, run:
*   **`dbt test`** -> Runs all `unique`, `not_null`, and `relationships` checks. (e.g., Output: `PASS=6 WARN=0 ERROR=0`).
*   **`dbt docs generate`** -> Builds the documentation site with all your descriptions and lineage graphs.

## 💡 Best Practice: Test Severity
You can configure how dbt reacts when a test fails:
```yaml
tests:
  - unique:
      arguments:
        severity: error # Options: 'error' or 'warn'
```
*   **`severity: error` (Default):** Crashes the pipeline to prevent bad data from flowing downstream.
*   **`severity: warn`:** Prints a yellow warning but allows the pipeline to continue (useful for non-critical checks).




# ⚠️⚠️ dbt Dimension Tables & Snapshots: A Summary ⚠️⚠️

## 1. Core Concept: What is a Dimension Table?
*   **Yes, a dimension table is always a lookup table.** Its primary purpose is to provide descriptive context (attributes) to the facts in a fact table.
*   **The Golden Rule:** A standard dimension table must have **exactly one row per unique business key** (e.g., `item_number` or `store_number`). 
*   If a dimension table contains duplicates, any downstream query joining facts to this dimension will result in inflated/incorrect metrics (the "fan-out" problem).

## 2. The Problem: Why Raw Data Fails the `unique` Test
Imagine a raw `sales` table containing transaction-level data. A single product appears thousands of times. If an item's description changes over time, a simple `SELECT DISTINCT` is not enough.

**The "Jack Daniels" Example:**
*   Row 1: Item #123, "Jack Daniels", 750ml (Jan 1)
*   Row 2: Item #123, "Jack Daniels", 750ml (Jan 2)
*   Row 3: Item #123, "Jack Daniels 750ml", 750ml (Jan 4) *<-- Description changed!*

If we run `SELECT DISTINCT`, we get **two rows** for Item #123. This breaks the `unique` test.

## 3. The Solution: dbt Snapshots (SCD Type 2)
Snapshots are used to track historical changes (Slowly Changing Dimensions Type 2). They read the raw data and generate a clean history table with `dbt_valid_from` and `dbt_valid_to` columns.

**The Snapshot Output (`item_snapshot`):**
*   Row 1: Item #123, "Jack Daniels", `dbt_valid_from` = Jan 1, `dbt_valid_to` = Jan 4
*   Row 2: Item #123, "Jack Daniels 750ml", `dbt_valid_from` = Jan 4, `dbt_valid_to` = **NULL**

*Note: The snapshot does not make the table unique by itself, but it isolates the "current" version by leaving `dbt_valid_to` as `NULL`.*

## 4. The "Magic Filter" in `dim_item.sql`
To get exactly one row per item for your dimension table, you read from the snapshot and apply this filter:
```sql
WHERE dbt_valid_to IS NULL
```

### 🚨🚨  Why NOT to use `CURRENT_TIMESTAMP > dbt_valid_from`
If you add `CURRENT_TIMESTAMP > dbt_valid_from` to your `WHERE` clause, **you will break your dimension table.** 
*   If a record was updated 5 minutes ago, `dbt_valid_from` is set to 5 minutes ago. 
*   Due to clock skew or execution time, `CURRENT_TIMESTAMP` might be equal to or slightly less than `dbt_valid_from`, causing you to accidentally filter out the most recent, active version of that item.

## 5. Best Practices & FAQs
*   **Do all lookup tables need a snapshot?** No. Snapshots are only needed if you want to track historical changes (Type 2). If you just want the current state (Type 1), you can use `ROW_NUMBER()` or `SELECT DISTINCT` in your model.
*   **Best Practice:** Always snapshot your **raw source data**, not your final dimension tables. This allows you to rebuild your entire warehouse from immutable history if your modeling logic changes later.
