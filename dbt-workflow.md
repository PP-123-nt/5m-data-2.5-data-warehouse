## 🕵️🕵️🕵️ dbt Project Workflow & Architecture Guide 🕵️🕵️🕵️

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

## Phase 3: Transformation & Modeling (Building the Star Schema)

*   **`dbt run`**: 
    *   **Action**: Compiles the SQL files in the `models/` folder and executes them in BigQuery.
    *   **Result (Default Routing)**: Models placed directly in the `models/` folder go to the **Default Dataset** (`liquor_demo`).
    *   **Result (Custom Routing)**: Because of the `dbt_project.yml` configuration, files inside `models/star/` (`dim_item.sql`, `dim_store.sql`, `fact_sales.sql`) are pushed to the **Custom Dataset**: **`liquor_demo_star`**. The `+materialized: table` setting ensures they become permanent tables for fast querying.

## Phase 4: Lineage & Documentation

*   **`schema.yml` & `sources.yml`**: Used to define tests (checking for nulls, uniqueness) and document tables.
*   **`dbt docs generate`** followed by **`dbt docs serve`**: Builds a local website showing a visual lineage graph of your data (from sources -> seeds -> models -> final tables).

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
│   ├── star/
│   │   ├── dim_item.sql
│   │   ├── dim_store.sql
│   │   ├── fact_sales.sql
│   │   └── schema.yml
│   ├── schema.yml
│   └── sources.yml
├── seeds/              # Place .csv files here
├── snapshots/
│   └── store_snapshot.sql
├── tests/
├── dbt_project.yml     # Main config (Routing & Materialization)
└── profiles.yml        # Connection config (Default Schema)
```