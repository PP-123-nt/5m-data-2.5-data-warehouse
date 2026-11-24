SELECT
    trip_id,
    start_station_id,
    end_station_id,
    bike_id,
    duration_minutes,
    start_time
FROM {{ source('austin_bikeshare', 'bikeshare_trips') }}