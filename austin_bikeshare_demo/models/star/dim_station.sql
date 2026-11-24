WITH trip_stats AS (
    SELECT
        start_station_id AS station_id,
        AVG(duration_minutes * 60) AS avg_duration -- Multiplied by 60 to convert minutes to seconds
    FROM {{ source('austin_bikeshare', 'bikeshare_trips') }}
    GROUP BY start_station_id
)

SELECT
    s.station_id,
    s.name,
    s.status,
    s.location,
    s.address,
    t.avg_duration
FROM {{ ref('station_snapshot') }} s
LEFT JOIN trip_stats t 
    ON s.station_id = t.station_id
WHERE s.dbt_valid_to IS NULL