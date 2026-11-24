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

### Phase 3.5: Data Quality Validation (`dbt test`)

*   **Action**: Executes the tests defined in your `schema.yml` files against the materialized tables in BigQuery.
*   **`schema.yml`**: Used to define tests (checking for nulls, uniqueness) and document tables.
*   **Result**: Validates that primary keys are unique (`unique`), not missing (`not_null`), and that foreign keys match (`relationships`)


## Phase 4: Lineage & Documentation


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

Here is a Markdown summary formatted for your GitHub notes, capturing the differences between standard models and snapshots regarding the `{{ config() }}` block.

***

# 🚨🚨  dbt: Why Do Snapshots Need a `config` Block but Standard Models Don't? 🚨🚨 

When writing dbt models, you might notice that standard models (like `dim_item.sql`) often don't have a configuration block, while snapshots (`item_snapshot.sql`) strictly require one. 

Here is the breakdown of why this happens.

## 1. Standard Models (`dim_item.sql`, `fact_sales.sql`)
**Standard models are implicit by default.** 

When dbt runs a standard model, it simply wraps your `SELECT` statement in a `CREATE VIEW` or `CREATE TABLE` command. Because it doesn't need to do anything complicated, it looks for default settings in your `dbt_project.yml` file. If it doesn't find any, it defaults to creating a **View**.

*   **The Rule:** You *can* add a config block to a standard model, but you don't *have* to. You only add it if you want to override the default behavior.
*   **Example of Optional Override:** 
    ```sql
    {{ config(materialized='table') }} -- Forces this model to be a Table instead of a View
    SELECT * FROM ...
    ```

## 2. Snapshots (`item_snapshot.sql`)
**Snapshots are explicit and mandatory.** 

A snapshot is not a simple `SELECT` query. It is a complex **Slowly Changing Dimension (SCD Type 2)** operation. dbt cannot just run `CREATE TABLE AS...`; it has to perform a multi-step background process:
1.  Read your new `SELECT` query.
2.  Compare it to the existing snapshot table in your database.
3.  Find matches using the `unique_key`.
4.  Check the `updated_at` column to see if data changed.
5.  **Update** the old row (setting `dbt_valid_to`).
6.  **Insert** a brand new row (setting `dbt_valid_from` to today, `dbt_valid_to` to `NULL`).

Because of this complexity, **dbt requires instructions to know exactly how to execute this logic.**

### Breakdown of the Snapshot Config Block:
```sql
{{
  config(
    target_schema='snapshots',       -- 1. WHERE to save the historical table
    unique_key='item_number',        -- 2. WHAT unique identifier to track
    strategy='timestamp',            -- 3. HOW to detect changes (timestamp vs check)
    updated_at='updated_at',         -- 4. WHICH column holds the update time
  )
}}
```
*Without this block, dbt would have no idea what the primary key is, how to detect changes, or where to store the history.*

## 💡 Key Takeaway
*   **Standard Models** are simple transformations. dbt can figure them out automatically. `config` is optional.
*   **Snapshots** are stateful, complex tracking operations. dbt needs explicit rules to build the history logic. `config` is mandatory.


Here is the explanation formatted in Markdown, ready for your GitHub notes.

***

# ⚡⚡ dbt Tests: Validating the Main & Star Schemas ⚡⚡

When we run `dbt test`, it is not just validating one file. It is validating the **entire Star Schema architecture** across multiple `schema.yml` files. 

Here is a breakdown of how the tests validate both the Main (Fact) schema and the Star (Dimension) schema based on your project structure.

## 1. Validating the Main Schema (`models/schema.yml`)
This file contains the tests for `fact_sales`, which is routed to your default dataset (`liquor_demo`). These tests ensure the fact table is structurally sound and can connect to the dimensions.

*   **Primary Key Integrity (`invoice_and_item_number`)**: 
    *   Tests `unique` and `not_null` to ensure the fact table's primary key is flawless.
*   **Foreign Key Integrity (Referential Integrity)**:
    *   **`store_number`**: Uses the `relationships` test to check that every store in the fact table actually exists in the `dim_store` table.
    *   **`item_number`**: Uses the `relationships` test to check that every item in the fact table actually exists in the `dim_item` table.
    *   *Note: These `relationships` tests act like SQL foreign key constraints.*

```yaml
# Example snippet from models/schema.yml
models:
  - name: fact_sales
    columns:
      - name: store_number
        tests:
          - relationships:
              arguments:
                to: ref('dim_store')
                field: store_number
```

## 2. Validating the Star Schema (`models/star/schema.yml`)
This file contains the tests for `dim_store` and `dim_item`, which are routed to your custom dataset (`liquor_demo_star`). These tests ensure the dimensions are clean for lookups.

*   **`dim_store.store_number`**: Tests `unique` and `not_null` to ensure the dimension's primary key has exactly one row per store.
*   **`dim_item.item_number`**: Tests `unique` and `not_null`. 
    *   *Note: The comment in your file shows how to add a `severity` argument (e.g., `severity: error`) to the `unique` test. This is the exact test that will intentionally fail if `dim_item` hasn't been fixed to read from the snapshot yet!*

```yaml
# Example snippet from models/star/schema.yml
models:
  - name: dim_item
    columns:
      - name: item_number
        tests:
          - unique:
              arguments:
                severity: error
          - not_null
```

## 💡 Summary
The tests work together to prove the **Star Schema** is perfectly connected:
1.  **Dimensions:** Are the primary keys unique and not null? (Tested in `models/star/schema.yml`).
2.  **Facts:** Do the foreign keys successfully link back to those unique dimension keys? (Tested in `models/schema.yml`).
