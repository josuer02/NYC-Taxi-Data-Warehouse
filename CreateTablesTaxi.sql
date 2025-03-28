-- --------------------------------------------------------
-- Script de creación de esquema para NYC Yellow Taxi Data Warehouse
-- Modelo Estrella
-- --------------------------------------------------------

DROP DATABASE IF EXISTS nyc_taxi_dw;
CREATE DATABASE nyc_taxi_dw;
USE nyc_taxi_dw;

-- --------------------------------------------------------
-- 1. TABLAS DE DIMENSIONES
-- --------------------------------------------------------

-- Dimensión Tiempo
CREATE TABLE dim_tiempo (
    tiempo_id INT UNSIGNED AUTO_INCREMENT,
    fecha_completa DATE NOT NULL,
    anio SMALLINT UNSIGNED NOT NULL,
    mes TINYINT UNSIGNED NOT NULL,
    dia TINYINT UNSIGNED NOT NULL,
    hora TINYINT UNSIGNED NOT NULL,
    minuto TINYINT UNSIGNED NOT NULL,
    dia_semana TINYINT UNSIGNED NOT NULL,
    nombre_dia_semana VARCHAR(10) NOT NULL,
    es_fin_semana TINYINT(1) NOT NULL,
    trimestre TINYINT UNSIGNED NOT NULL,
    nombre_mes VARCHAR(10) NOT NULL,
    anio_mes VARCHAR(7) NOT NULL,
    semana_anio TINYINT UNSIGNED NOT NULL,
    es_feriado TINYINT(1) DEFAULT 0,
    nombre_feriado VARCHAR(50) DEFAULT NULL,
    creacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    actualizacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (tiempo_id),
    UNIQUE KEY uq_dim_tiempo_fecha_completa_hora_minuto (fecha_completa, hora, minuto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dimensión temporal para análisis de viajes';

-- Dimensión Ubicación
CREATE TABLE dim_ubicacion (
    ubicacion_id INT UNSIGNED AUTO_INCREMENT,
    location_id SMALLINT UNSIGNED NOT NULL COMMENT 'TLC Taxi Zone ID',
    zona VARCHAR(100) NOT NULL,
    distrito VARCHAR(50) NOT NULL,
    servicio_zona VARCHAR(50) DEFAULT NULL,
    es_aeropuerto TINYINT(1) DEFAULT 0,
    creacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    actualizacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (ubicacion_id),
    UNIQUE KEY uq_dim_ubicacion_location_id (location_id),
    INDEX idx_dim_ubicacion_zona (zona),
    INDEX idx_dim_ubicacion_distrito (distrito)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dimensión geográfica para zonas de NYC';

-- Dimensión Pago
CREATE TABLE dim_pago (
    pago_id INT UNSIGNED AUTO_INCREMENT,
    payment_type SMALLINT UNSIGNED NOT NULL,
    metodo_pago_nombre VARCHAR(50) NOT NULL,
    es_electronico TINYINT(1) NOT NULL,
    creacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    actualizacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (pago_id),
    UNIQUE KEY uq_dim_pago_payment_type (payment_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dimensión para métodos de pago';

-- Dimensión Proveedor
CREATE TABLE dim_proveedor (
    proveedor_id INT UNSIGNED AUTO_INCREMENT,
    vendor_id TINYINT UNSIGNED NOT NULL,
    proveedor_nombre VARCHAR(100) NOT NULL,
    creacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    actualizacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (proveedor_id),
    UNIQUE KEY uq_dim_proveedor_vendor_id (vendor_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dimensión para proveedores de servicio de taxi';

-- Dimensión Tarifa
CREATE TABLE dim_tarifa (
    tarifa_id INT UNSIGNED AUTO_INCREMENT,
    rate_code_id TINYINT UNSIGNED NOT NULL,
    tarifa_tipo VARCHAR(50) NOT NULL,
    tarifa_descripcion VARCHAR(255) DEFAULT NULL,
    creacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    actualizacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (tarifa_id),
    UNIQUE KEY uq_dim_tarifa_rate_code_id (rate_code_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dimensión para tipos de tarifa';

-- --------------------------------------------------------
-- 2. TABLA DE HECHOS
-- --------------------------------------------------------

-- Tabla de Hechos para Viajes de Taxi
CREATE TABLE fact_taxi_trips (
    viaje_id BIGINT UNSIGNED AUTO_INCREMENT,
    tiempo_recogida_id INT UNSIGNED NOT NULL,
    tiempo_destino_id INT UNSIGNED NOT NULL,
    ubicacion_recogida_id INT UNSIGNED NOT NULL,
    ubicacion_destino_id INT UNSIGNED NOT NULL,
    proveedor_id INT UNSIGNED NOT NULL,
    pago_id INT UNSIGNED NOT NULL,
    tarifa_id INT UNSIGNED NOT NULL,
    
    -- Métricas
    distancia_millas DECIMAL(8,2) NOT NULL,
    duracion_minutos INT UNSIGNED NOT NULL,
    tarifa_base_usd DECIMAL(8,2) NOT NULL,
    recargo_usd DECIMAL(8,2) DEFAULT 0.00,
    impuesto_mta_usd DECIMAL(8,2) DEFAULT 0.00,
    propina_usd DECIMAL(8,2) DEFAULT 0.00,
    peaje_usd DECIMAL(8,2) DEFAULT 0.00,
    mejora_recargo_usd DECIMAL(8,2) DEFAULT 0.00,
    monto_total_usd DECIMAL(8,2) NOT NULL,
    pasajeros_cantidad TINYINT UNSIGNED NOT NULL,
    store_and_fwd_flag CHAR(1) DEFAULT NULL,
    
    -- Campos de auditoría
    creacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    actualizacion_fecha DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    PRIMARY KEY (viaje_id),
    
    -- Claves foráneas
    CONSTRAINT fk_fact_taxi_trips_tiempo_recogida FOREIGN KEY (tiempo_recogida_id) 
        REFERENCES dim_tiempo (tiempo_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fact_taxi_trips_tiempo_destino FOREIGN KEY (tiempo_destino_id) 
        REFERENCES dim_tiempo (tiempo_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fact_taxi_trips_ubicacion_recogida FOREIGN KEY (ubicacion_recogida_id) 
        REFERENCES dim_ubicacion (ubicacion_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fact_taxi_trips_ubicacion_destino FOREIGN KEY (ubicacion_destino_id) 
        REFERENCES dim_ubicacion (ubicacion_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fact_taxi_trips_proveedor FOREIGN KEY (proveedor_id) 
        REFERENCES dim_proveedor (proveedor_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fact_taxi_trips_pago FOREIGN KEY (pago_id) 
        REFERENCES dim_pago (pago_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fact_taxi_trips_tarifa FOREIGN KEY (tarifa_id) 
        REFERENCES dim_tarifa (tarifa_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Índices para optimizar consultas
    INDEX idx_fact_taxi_trips_tiempo_recogida (tiempo_recogida_id),
    INDEX idx_fact_taxi_trips_ubicacion_recogida (ubicacion_recogida_id),
    INDEX idx_fact_taxi_trips_ubicacion_destino (ubicacion_destino_id),
    INDEX idx_fact_taxi_trips_pago (pago_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tabla de hechos que almacena todas las métricas de viajes';

-- --------------------------------------------------------
-- 3. TABLA DE STAGING
-- --------------------------------------------------------

-- Tabla de staging para el NYC Yellow Taxi Trip Data (enero 2019)
CREATE TABLE stage_yellow_taxi_data (
    stage_id BIGINT UNSIGNED AUTO_INCREMENT,
    VendorID TINYINT,
    tpep_pickup_datetime DATETIME,
    tpep_dropoff_datetime DATETIME,
    passenger_count INT,
    trip_distance DECIMAL(10,2),
    RatecodeID TINYINT,
    store_and_fwd_flag CHAR(1),
    PULocationID SMALLINT,
    DOLocationID SMALLINT,
    payment_type SMALLINT,
    fare_amount DECIMAL(10,2),
    extra DECIMAL(10,2),
    mta_tax DECIMAL(10,2),
    tip_amount DECIMAL(10,2),
    tolls_amount DECIMAL(10,2),
    improvement_surcharge DECIMAL(10,2),
    total_amount DECIMAL(10,2),
    congestion_surcharge DECIMAL(10,2),
    
    -- Control de procesamiento
    procesado TINYINT(1) DEFAULT 0,
    fecha_procesamiento DATETIME DEFAULT NULL,
    
    -- Metadatos
    archivo_origen VARCHAR(255) DEFAULT NULL,
    fecha_carga DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (stage_id),
    INDEX idx_stage_processed (procesado),
    INDEX idx_stage_pickup_datetime (tpep_pickup_datetime),
    INDEX idx_stage_pickup_location (PULocationID),
    INDEX idx_stage_dropoff_location (DOLocationID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tabla de staging para datos de Yellow Taxi';