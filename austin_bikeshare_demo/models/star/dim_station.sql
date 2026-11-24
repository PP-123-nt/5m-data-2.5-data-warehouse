SELECT
        station_id,
        name,
        status,
        location,
        address,
FROM {{ ref('station_snapshot') }}
WHERE dbt_valid_to IS NULL