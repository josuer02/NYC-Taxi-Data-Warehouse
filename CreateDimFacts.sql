-- --------------------------------------------------------
-- Script para cargar datos en dimensiones y tabla de hechos
-- NYC Yellow Taxi Trip Dataset - Enero 2019
-- --------------------------------------------------------

USE nyc_taxi_dw;

-- --------------------------------------------------------
-- 1. CARGA DE TABLAS DE DIMENSIONES
-- --------------------------------------------------------

-- 1.1 Cargar Dimensión Tiempo
-- Procedimiento para generar datos de tiempo para un rango de fechas
DELIMITER //
DELIMITER //
DROP PROCEDURE IF EXISTS llenar_dim_tiempo;
CREATE PROCEDURE llenar_dim_tiempo(fecha_inicio DATE, fecha_fin DATE)
BEGIN
    DECLARE fecha_actual DATETIME;
    DECLARE anio_val, mes_val, dia_val, hora_val, minuto_val INT;
    DECLARE nombre_dia, nombre_mes VARCHAR(50);
    
    SET fecha_actual = fecha_inicio;
    
    WHILE fecha_actual <= fecha_fin DO
        SET anio_val = YEAR(fecha_actual);
        SET mes_val = MONTH(fecha_actual);
        SET dia_val = DAY(fecha_actual);
        
        -- Generar registros para cada hora y minuto del día
        SET hora_val = 0;
        WHILE hora_val < 24 DO
            SET minuto_val = 0;
            WHILE minuto_val < 60 DO
                -- Verificar si ya existe este registro
                IF NOT EXISTS (SELECT 1 FROM dim_tiempo 
                              WHERE anio = anio_val AND mes = mes_val AND 
                                   dia = dia_val AND hora = hora_val AND 
                                   minuto = minuto_val) THEN
                    
                    -- Preparar valores
                    SET nombre_dia = DAYNAME(fecha_actual);
                    SET nombre_mes = MONTHNAME(fecha_actual);
                    
                    -- Insertar registro con sintaxis corregida
                    INSERT INTO dim_tiempo (
                        fecha_completa, anio, mes, dia, hora, minuto,
                        dia_semana, nombre_dia_semana, es_fin_semana,
                        trimestre, nombre_mes, anio_mes, semana_anio
                    )
                    VALUES (
                        -- Opción 1: Anidar las funciones DATE_ADD
                        DATE_ADD(DATE_ADD(DATE(fecha_actual), INTERVAL hora_val HOUR), INTERVAL minuto_val MINUTE),
                        
                        -- Resto de los valores permanecen iguales
                        anio_val, mes_val, dia_val, hora_val, minuto_val,
                        WEEKDAY(fecha_actual) + 1, nombre_dia, 
                        IF(WEEKDAY(fecha_actual) >= 5, 1, 0),
                        QUARTER(fecha_actual), nombre_mes, 
                        CONCAT(anio_val, '-', LPAD(mes_val, 2, '0')),
                        WEEK(fecha_actual, 1)
                    );
                END IF;
                
                SET minuto_val = minuto_val + 1;
            END WHILE;
            SET hora_val = hora_val + 1;
        END WHILE;
        
        -- Avanzar al día siguiente
        SET fecha_actual = DATE_ADD(fecha_actual, INTERVAL 1 DAY);
    END WHILE;
END //
DELIMITER ;

-- Ejecutar el procedimiento con el rango de fechas de enero 2019
CALL llenar_dim_tiempo('2019-01-01', '2019-01-31');

-- 1.2 Cargar Dimensión Ubicación
-- Primero creamos una tabla temporal con el mapeo de zonas de taxi
CREATE TEMPORARY TABLE taxi_zone_lookup (
    LocationID SMALLINT PRIMARY KEY,
    Borough VARCHAR(50),
    Zone VARCHAR(100),
    service_zone VARCHAR(50)
);

-- Cargamos datos desde el archivo de zonas de taxi (si está disponible)
-- Si no se tiene acceso al archivo, insertamos algunas zonas conocidas
INSERT INTO taxi_zone_lookup VALUES
    (1, 'EWR', 'Newark Airport', 'EWR'),
    (2, 'Queens', 'Jamaica Bay', 'Boro Zone'),
    (3, 'Bronx', 'Allerton/Pelham Gardens', 'Boro Zone'),
    (4, 'Manhattan', 'Alphabet City', 'Yellow Zone'),
    (5, 'Staten Island', 'Arden Heights', 'Boro Zone'),
    (6, 'Staten Island', 'Arrochar/Fort Wadsworth', 'Boro Zone'),
    (7, 'Queens', 'Astoria', 'Boro Zone'),
    -- Continuar con más zonas según sea necesario
    (262, 'Manhattan', 'JFK Airport', 'Airports'),
    (263, 'Manhattan', 'LaGuardia Airport', 'Airports');

-- Cargar la dimensión ubicación usando el mapeo de zonas
INSERT INTO dim_ubicacion (
    location_id, zona, distrito, servicio_zona, es_aeropuerto
)
SELECT 
    l.LocationID,
    l.Zone,
    l.Borough,
    l.service_zone,
    CASE WHEN l.Zone LIKE '%Airport%' THEN 1 ELSE 0 END
FROM taxi_zone_lookup l
ON DUPLICATE KEY UPDATE
    zona = l.Zone,
    distrito = l.Borough;

-- Asegurarse de tener al menos todas las ubicaciones que aparecen en los datos de staging
INSERT IGNORE INTO dim_ubicacion (location_id, zona, distrito)
SELECT DISTINCT 
    PULocationID, 
    CONCAT('Zona ', PULocationID), 
    'Desconocido'
FROM 
    stage_yellow_taxi_data 
WHERE 
    PULocationID IS NOT NULL;

INSERT IGNORE INTO dim_ubicacion (location_id, zona, distrito)
SELECT DISTINCT 
    DOLocationID, 
    CONCAT('Zona ', DOLocationID), 
    'Desconocido'
FROM 
    stage_yellow_taxi_data 
WHERE 
    DOLocationID IS NOT NULL;

-- 1.3 Cargar Dimensión Pago
INSERT INTO dim_pago (payment_type, metodo_pago_nombre, es_electronico)
VALUES 
    (1, 'Tarjeta de crédito', 1),
    (2, 'Efectivo', 0),
    (3, 'Sin cargo', 0),
    (4, 'Disputa', 0),
    (5, 'Desconocido', 0),
    (6, 'Viaje anulado', 0)
ON DUPLICATE KEY UPDATE metodo_pago_nombre = VALUES(metodo_pago_nombre);

-- 1.4 Cargar Dimensión Proveedor
INSERT INTO dim_proveedor (vendor_id, proveedor_nombre)
VALUES 
    (1, 'Creative Mobile Technologies, LLC'),
    (2, 'VeriFone Inc.')
ON DUPLICATE KEY UPDATE proveedor_nombre = VALUES(proveedor_nombre);

-- 1.5 Cargar Dimensión Tarifa
INSERT INTO dim_tarifa (rate_code_id, tarifa_tipo, tarifa_descripcion)
VALUES 
    (1, 'Estándar', 'Tarifa regular'),
    (2, 'JFK', 'Tarifa fija para JFK'),
    (3, 'Newark', 'Tarifa Newark'),
    (4, 'Nassau o Westchester', 'Fuera de la ciudad'),
    (5, 'Tarifa negociada', 'Precio acordado'),
    (6, 'Viaje compartido', 'Múltiples pasajeros')
ON DUPLICATE KEY UPDATE tarifa_tipo = VALUES(tarifa_tipo);

-- --------------------------------------------------------
-- 2. CARGA DE TABLA DE HECHOS
-- --------------------------------------------------------

-- Procedimiento para cargar la tabla de hechos en lotes
DELIMITER //
CREATE PROCEDURE cargar_fact_taxi_trips(IN batch_size INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_stage_id BIGINT;
    DECLARE v_tiempo_recogida_id, v_tiempo_destino_id INT;
    DECLARE v_ubicacion_recogida_id, v_ubicacion_destino_id INT;
    DECLARE v_proveedor_id, v_pago_id, v_tarifa_id INT;
    DECLARE counter INT DEFAULT 0;
    
    -- Declare cursor for staging data
    DECLARE cur CURSOR FOR 
        SELECT 
            stage_id
        FROM 
            stage_yellow_taxi_data
        WHERE 
            procesado = 0 AND
            tpep_pickup_datetime IS NOT NULL AND
            tpep_dropoff_datetime IS NOT NULL AND
            PULocationID IS NOT NULL AND
            DOLocationID IS NOT NULL
        LIMIT batch_size;
            
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Temporalmente desactivar las verificaciones de clave foránea para mejorar rendimiento
    SET FOREIGN_KEY_CHECKS = 0;
    
    OPEN cur;
    
    insert_loop: LOOP
        FETCH cur INTO v_stage_id;
        
        IF done THEN
            LEAVE insert_loop;
        END IF;
        
        -- Insertar en fact_taxi_trips
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
            dt_pickup.tiempo_id,
            dt_dropoff.tiempo_id,
            du_pickup.ubicacion_id,
            du_dropoff.ubicacion_id,
            dp.proveedor_id,
            dpay.pago_id,
            dtarifa.tarifa_id,
            COALESCE(stage.trip_distance, 0),
            TIMESTAMPDIFF(MINUTE, stage.tpep_pickup_datetime, stage.tpep_dropoff_datetime),
            COALESCE(stage.fare_amount, 0),
            COALESCE(stage.extra, 0) + COALESCE(stage.congestion_surcharge, 0),
            COALESCE(stage.mta_tax, 0),
            COALESCE(stage.tip_amount, 0),
            COALESCE(stage.tolls_amount, 0),
            COALESCE(stage.improvement_surcharge, 0),
            COALESCE(stage.total_amount, 0),
            COALESCE(stage.passenger_count, 1),
            stage.store_and_fwd_flag
        FROM 
            stage_yellow_taxi_data stage
        JOIN 
            dim_tiempo dt_pickup ON 
            dt_pickup.fecha_completa = DATE_FORMAT(stage.tpep_pickup_datetime, '%Y-%m-%d %H:%i:00')
        JOIN 
            dim_tiempo dt_dropoff ON 
            dt_dropoff.fecha_completa = DATE_FORMAT(stage.tpep_dropoff_datetime, '%Y-%m-%d %H:%i:00')
        JOIN 
            dim_ubicacion du_pickup ON 
            du_pickup.location_id = stage.PULocationID
        JOIN 
            dim_ubicacion du_dropoff ON 
            du_dropoff.location_id = stage.DOLocationID
        JOIN 
            dim_proveedor dp ON 
            dp.vendor_id = stage.VendorID
        JOIN 
            dim_pago dpay ON 
            dpay.payment_type = stage.payment_type
        JOIN 
            dim_tarifa dtarifa ON 
            dtarifa.rate_code_id = stage.RatecodeID
        WHERE 
            stage.stage_id = v_stage_id;
        
        -- Marcar registro como procesado
        UPDATE stage_yellow_taxi_data 
        SET procesado = 1, fecha_procesamiento = NOW()
        WHERE stage_id = v_stage_id;
        
        SET counter = counter + 1;
        
        -- Checkpoint periódico para confirmar transacciones
        IF counter % 1000 = 0 THEN
            COMMIT;
        END IF;
    
    END LOOP;
    
    CLOSE cur;
    
    -- Reactivar verificaciones de clave foránea
    SET FOREIGN_KEY_CHECKS = 1;
    COMMIT;
END //
DELIMITER ;

-- Ejecutar el procedimiento en lotes para evitar bloqueos de memoria
-- por el gran volumen de datos
CALL cargar_fact_taxi_trips(10000);  -- Procesar primeros 10,000 registros
-- Repetir llamada según sea necesario hasta procesar todos los datos

-- Verificación de la carga
SELECT COUNT(*) FROM fact_taxi_trips;

-- Verificar registros con errores (no se pudieron cargar)
SELECT COUNT(*) 
FROM stage_yellow_taxi_data 
WHERE procesado = 0 AND 
      tpep_pickup_datetime IS NOT NULL AND 
      tpep_dropoff_datetime IS NOT NULL;

-- --------------------------------------------------------
-- 3. LIMPIEZA Y VALIDACIÓN
-- --------------------------------------------------------

-- Verificar integridad referencial
SELECT 'Viajes sin tiempo de recogida válido:' AS mensaje, COUNT(*) AS cantidad
FROM fact_taxi_trips f
LEFT JOIN dim_tiempo t ON f.tiempo_recogida_id = t.tiempo_id
WHERE t.tiempo_id IS NULL
UNION
SELECT 'Viajes sin ubicación de recogida válida:', COUNT(*)
FROM fact_taxi_trips f
LEFT JOIN dim_ubicacion u ON f.ubicacion_recogida_id = u.ubicacion_id
WHERE u.ubicacion_id IS NULL;

-- Verificar métricas
SELECT 
    'Distancia promedio (millas):' AS metrica, 
    AVG(distancia_millas) AS valor
FROM fact_taxi_trips
UNION
SELECT 'Duración promedio (minutos):', AVG(duracion_minutos)
FROM fact_taxi_trips
UNION
SELECT 'Monto total promedio ($):', AVG(monto_total_usd)
FROM fact_taxi_trips;

-- Reporte de registros cargados por dimensión
SELECT 'Dimensión tiempo:' AS dimension, COUNT(*) AS registros FROM dim_tiempo
UNION
SELECT 'Dimensión ubicación:', COUNT(*) FROM dim_ubicacion
UNION
SELECT 'Dimensión pago:', COUNT(*) FROM dim_pago
UNION
SELECT 'Dimensión proveedor:', COUNT(*) FROM dim_proveedor
UNION
SELECT 'Dimensión tarifa:', COUNT(*) FROM dim_tarifa
UNION
SELECT 'Tabla de hechos:', COUNT(*) FROM fact_taxi_trips;