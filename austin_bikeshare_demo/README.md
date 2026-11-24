Welcome to your new dbt project!

### Using the starter project

Try running the following commands:
- dbt run
- dbt test


### Resources:
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](https://community.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices



# 📌📌📌 SQL Building 📌📌📌

**Both the Snapshot and the Dimension should source from `bikeshare_stations` (the mapping table), NOT the fact table (`bikeshare_trips`).**

### 🧠 The Logic: Why `bikeshare_stations`?

1.  **`bikeshare_trips` (The Fact Table):** This is a transactional log. It records every single bike ride. It has things like `trip_id`, `duration_minutes`, and `start_station_id`. It also has `start_station_name` (which is a denormalized snapshot of the name at the time of the trip). However, it does *not* have the station's `status`, `location`, or `address`.
2.  **`bikeshare_stations` (The Dimension Source):** This is the master lookup table. It has exactly one row per station (usually). It contains the descriptive attributes you need: `name`, `status`, `location`, `address`. **Crucially, it has a `modified_date` column.** This is the perfect column for dbt to use to track changes over time!

If you build your snapshot from the `bikeshare_trips` table, you are only capturing stations at the exact moment a trip happens, and you don't have the `status` or `address` data. 

### 🛠️ How to update your code

Because `bikeshare_stations` is already a clean table with one row per station, your snapshot logic becomes **much simpler**. You don't need the complex `FIRST_VALUE` and `QUALIFY` logic you used for the messy raw sales data.

Here is how you should update all three files:

#### 1. `snapshots/station_snapshot.sql`
Since `bikeshare_stations` already has a `modified_date` timestamp, dbt's built-in timestamp strategy handles all the history tracking for you. You just need to `SELECT` the columns.

```sql
{% snapshot station_snapshot %}

{{
  config(
    target_schema='snapshots',
    unique_key='station_id',
    strategy='timestamp',
    updated_at='modified_date', 
  )
}}

SELECT
    station_id,
    name,
    status,
    location,
    address,
    modified_date
FROM {{ source('austin_bikeshare', 'bikeshare_stations') }}

{% endsnapshot %}
```
*(Note: Notice how much simpler this is! dbt will automatically look at `modified_date` and generate the `dbt_valid_from` and `dbt_valid_to` columns).*

#### 2. `models/star/dim_station.sql`
Now, point your dimension table at the snapshot you just built. 

```sql
SELECT
    station_id,
    name,
    status,
    location,
    address
FROM {{ ref('station_snapshot') }}
WHERE dbt_valid_to IS NULL
```
*(This guarantees you get exactly one row per station: the most current one).*

#### 3. `models/fact_trips.sql`
Your fact table stays exactly the same. It sources from `bikeshare_trips`. You will use `start_station_id` and `end_station_id` to join to your `dim_station` table later if you need to analyze trips by station details.

```sql
SELECT
    trip_id,
    start_station_id,
    end_station_id,
    bike_id,
    duration_minutes,
    start_time
FROM {{ source('austin_bikeshare', 'bikeshare_trips') }}
```

### 💡 Best Practice Takeaway
*   **Fact tables** source from transactional tables (e.g., `bikeshare_trips`).
*   **Dimensions** source from mapping/master tables (e.g., `bikeshare_stations`).
*   **Snapshots** sit in the middle, tracking how the mapping tables change over time.


### 🕵️🕵️ 'sources.yml' 🕵️🕵️

Add 2 tables (fact and dimension) in sources file
```
version: 2

sources:
  - name: austin_bikeshare
    database: bigquery-public-data
    tables:
      - name: bikeshare_trips
      - name: bikeshare_stations    # added a source for bikeshare_stations table
```

<img width="478" height="430" alt="image" src="https://github.com/user-attachments/assets/fc9eaf78-b0b7-4523-b4f6-6bb31e30ced7" />


### 🕵️🕵️ 'dbt_project.yml' 🕵️🕵️

`+materialized` to define `table` or `view` format 
```
models:
  austin_bikeshare_demo:
    # This sets the default for ALL new models in your project to be tables
    +materialized: table
    # Config indicated by + and applies to all files under models/example/
    example:
      +materialized: view
```


### 🕵️🕵️ strategy='timestamp' 🕵️🕵️

When you use strategy='timestamp', you are telling dbt: "To figure out if a row has changed, look at a specific timestamp column in the source data."

Then, the line updated_at='modified_date' tells dbt exactly which column to look at.

How it works in practice:

*   You run dbt snapshot today. dbt reads the bikeshare_stations table and saves it. It looks at the modified_date for every station.
*   Next week, a station changes its status from "active" to "closed", and the modified_date updates to next week's date.
*   You run dbt snapshot again. dbt looks at the new data, sees that modified_date is newer than what it has in its history table, and says: "Aha! This row changed."
*   dbt then automatically closes out the old record (dbt_valid_to = today) and inserts a brand new record (dbt_valid_from = today, dbt_valid_to = NULL).


# 🚨 Critical Rule: Snapshots CANNOT go in the models/ folder
You must keep station_snapshot.sql inside the snapshots/ folder.

Why? dbt has a specific configuration in dbt_project.yml (snapshot-paths: ["snapshots"]). If you put a snapshot file in the models/ folder, dbt will try to run it as a standard model. It will fail because standard models don't understand the {% snapshot %} block. Keep snapshots separate.


<img width="492" height="346" alt="image" src="https://github.com/user-attachments/assets/ce0e110d-57e6-429a-a8e1-4f8332a45983" />

<img width="637" height="382" alt="image" src="https://github.com/user-attachments/assets/7c60e081-92e4-4774-bce3-7263268cd690" />
<img width="651" height="364" alt="image" src="https://github.com/user-attachments/assets/3511caab-e8d7-4aee-96cc-f849d78f66f8" />




