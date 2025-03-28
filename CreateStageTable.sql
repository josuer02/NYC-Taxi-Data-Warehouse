-- --------------------------------------------------------
-- Script para cargar datos en la tabla de staging
-- NYC Yellow Taxi Trip Data - Enero 2019
-- --------------------------------------------------------

USE nyc_taxi_dw;

-- Truncar la tabla de staging si ya contiene datos
TRUNCATE TABLE stage_yellow_taxi_data;

-- Configurar características de importación 
SET SESSION sql_mode = '';  -- Permitir valores NULL o vacíos
SET GLOBAL max_allowed_packet = 1073741824;  -- 1GB para archivos grandes
SET GLOBAL local_infile = 1;  -- Permitir carga local de archivos
SET SESSION group_concat_max_len = 1000000;  -- Para procesamiento de grandes conjuntos

-- Cargar datos desde el archivo CSV
LOAD DATA INFILE '/Users/josuer/Documents/Bi/yellow_tripdata_2019-01.csv'
INTO TABLE stage_yellow_taxi_data
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    VendorID,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,
    RatecodeID,
    store_and_fwd_flag,
    PULocationID,
    DOLocationID,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    congestion_surcharge
)
SET archivo_origen = 'yellow_tripdata_2019-01.csv',
    fecha_carga = NOW();

-- Verificación de datos cargados
SELECT COUNT(*) AS total_registros FROM stage_yellow_taxi_data;

-- Verificación de muestra de datos
SELECT * FROM stage_yellow_taxi_data LIMIT 10;

-- Verificación de valores nulos o problemáticos
SELECT 
    SUM(CASE WHEN VendorID IS NULL THEN 1 ELSE 0 END) AS null_vendor,
    SUM(CASE WHEN tpep_pickup_datetime IS NULL THEN 1 ELSE 0 END) AS null_pickup_time,
    SUM(CASE WHEN PULocationID IS NULL THEN 1 ELSE 0 END) AS null_pickup_location,
    SUM(CASE WHEN trip_distance IS NULL OR trip_distance < 0 THEN 1 ELSE 0 END) AS invalid_distance,
    SUM(CASE WHEN total_amount IS NULL OR total_amount < 0 THEN 1 ELSE 0 END) AS invalid_amount
FROM stage_yellow_taxi_data;

-- Actualizar el estado de procesamiento
UPDATE stage_yellow_taxi_data SET procesado = 0, fecha_procesamiento = NULL;