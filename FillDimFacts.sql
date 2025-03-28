-- --------------------------------------------------------
-- Script ultra simplificado para cargar datos en el data warehouse
-- NYC Yellow Taxi Trip Data - Enero 2019
-- --------------------------------------------------------

USE nyc_taxi_dw;
-- --------------------------------------------------------
-- 1. ASEGURAR QUE TODOS LOS VENDOR_IDs ESTÉN EN LA DIMENSIÓN
-- --------------------------------------------------------

-- Añadir proveedor desconocido y faltantes (incluido el ID 4)
INSERT IGNORE INTO dim_proveedor (vendor_id, proveedor_nombre)
VALUES
    (0, 'Proveedor Desconocido'),
    (4, 'Otro Proveedor');

-- --------------------------------------------------------
-- 2. CREAR TABLA TEMPORAL PARA IDs ESPECÍFICOS (ultra pequeña)
-- --------------------------------------------------------

DROP TEMPORARY TABLE IF EXISTS temp_stage_ids;
CREATE TEMPORARY TABLE temp_stage_ids AS
SELECT stage_id 
FROM stage_yellow_taxi_data 
WHERE procesado = 0
AND VendorID IS NOT NULL
AND tpep_pickup_datetime IS NOT NULL
AND tpep_dropoff_datetime IS NOT NULL
AND PULocationID IS NOT NULL
AND DOLocationID IS NOT NULL
AND tpep_pickup_datetime >= '2019-01-01'  
AND tpep_pickup_datetime < '2019-01-02'
LIMIT 20;

-- --------------------------------------------------------
-- 3. ASEGURAR QUE TENEMOS LAS UBICACIONES NECESARIAS
-- --------------------------------------------------------

-- Añadir las ubicaciones de origen y destino para nuestros 20 registros
INSERT IGNORE INTO dim_ubicacion (location_id, zona, distrito)
SELECT DISTINCT PULocationID, CONCAT('Zona ', PULocationID), 'Desconocido'
FROM stage_yellow_taxi_data
WHERE stage_id IN (SELECT stage_id FROM temp_stage_ids);

INSERT IGNORE INTO dim_ubicacion (location_id, zona, distrito)
SELECT DISTINCT DOLocationID, CONCAT('Zona ', DOLocationID), 'Desconocido'
FROM stage_yellow_taxi_data
WHERE stage_id IN (SELECT stage_id FROM temp_stage_ids);

-- --------------------------------------------------------
-- 4. INSERTAR DIRECTAMENTE EN FACT_TAXI_TRIPS (ultra minimal)
-- --------------------------------------------------------

INSERT INTO fact_taxi_trips (
    tiempo_recogida_id,
    tiempo_destino_id,
    ubicacion_recogida_id,
    ubicacion_destino_id,
    proveedor_id,
    pago_id,
    tarifa_id,
    distancia_millas,
    duracion_minutos,
    tarifa_base_usd,
    recargo_usd,
    impuesto_mta_usd,
    propina_usd,
    peaje_usd,
    mejora_recargo_usd,
    monto_total_usd,
    pasajeros_cantidad,
    store_and_fwd_flag
)
SELECT 
    -- Dimensión tiempo
    (SELECT MIN(tiempo_id) FROM dim_tiempo 
     WHERE HOUR(fecha_completa) = HOUR(s.tpep_pickup_datetime) 
     AND DATE(fecha_completa) = DATE(s.tpep_pickup_datetime)),
    
    (SELECT MIN(tiempo_id) FROM dim_tiempo 
     WHERE HOUR(fecha_completa) = HOUR(s.tpep_dropoff_datetime) 
     AND DATE(fecha_completa) = DATE(s.tpep_dropoff_datetime)),
    
    -- Dimensión ubicación
    (SELECT MIN(ubicacion_id) FROM dim_ubicacion WHERE location_id = s.PULocationID),
    (SELECT MIN(ubicacion_id) FROM dim_ubicacion WHERE location_id = s.DOLocationID),
    
    -- Dimensión proveedor
    (SELECT MIN(proveedor_id) FROM dim_proveedor WHERE vendor_id = s.VendorID),
    
    -- Dimensión pago
    (SELECT MIN(pago_id) FROM dim_pago WHERE payment_type = IFNULL(s.payment_type, 5)),
    
    -- Dimensión tarifa
    (SELECT MIN(tarifa_id) FROM dim_tarifa WHERE rate_code_id = IFNULL(s.RatecodeID, 99)),
    
    -- Métricas
    IFNULL(s.trip_distance, 0),
    TIMESTAMPDIFF(MINUTE, s.tpep_pickup_datetime, s.tpep_dropoff_datetime),
    IFNULL(s.fare_amount, 0),
    IFNULL(s.extra, 0),
    IFNULL(s.mta_tax, 0),
    IFNULL(s.tip_amount, 0),
    IFNULL(s.tolls_amount, 0),
    IFNULL(s.improvement_surcharge, 0),
    IFNULL(s.total_amount, 0),
    IFNULL(s.passenger_count, 1),
    IFNULL(s.store_and_fwd_flag, 'N')
FROM 
    stage_yellow_taxi_data s
JOIN 
    temp_stage_ids t ON s.stage_id = t.stage_id
WHERE
    s.procesado = 0;

-- --------------------------------------------------------
-- 5. LIMPIAR TABLA TEMPORAL
-- --------------------------------------------------------

DROP TEMPORARY TABLE IF EXISTS temp_stage_ids;

-- --------------------------------------------------------
-- 6. VERIFICACIÓN DE LA CARGA
-- --------------------------------------------------------

-- Ver los registros cargados en la tabla de hechos
SELECT * FROM fact_taxi_trips LIMIT 5;

-- --------------------------------------------------------
-- 7. EJEMPLO DE ANÁLISIS
-- --------------------------------------------------------

-- Un ejemplo sencillo para mostrar el promedio de tarifa por proveedor
SELECT 
    p.proveedor_nombre,
    COUNT(*) AS total_viajes,
    ROUND(AVG(f.monto_total_usd), 2) AS tarifa_promedio
FROM 
    fact_taxi_trips f
JOIN 
    dim_proveedor p ON f.proveedor_id = p.proveedor_id
GROUP BY 
    p.proveedor_nombre
ORDER BY 
    total_viajes DESC;
    