# Modelado y Carga de Datos en un Data Warehouse: NYC Yellow Taxi

_Diagrama Entidad-Relación del Data Warehouse para NYC Yellow Taxi_

## Índice

1. [Selección de la Base de Datos Transaccional](#1-selección-de-la-base-de-datos-transaccional)
2. [Identificación de Dimensiones y Tablas de Hechos](#2-identificación-de-dimensiones-y-tablas-de-hechos)
3. [Definición del Modelo Estrella](#3-definición-del-modelo-estrella)
4. [Taxonomía y Nomenclatura](#4-taxonomía-y-nomenclatura)
5. [Implementación de la Base de Datos](#5-implementación-de-la-base-de-datos)
6. [Diagrama Entidad-Relación](#6-diagrama-entidad-relación)
7. [Proceso ETL](#7-proceso-etl)
   - [7.1 Carga de la Tabla Stage](#71-carga-de-la-tabla-stage)
   - [7.2 Carga de Dimensiones](#72-carga-de-dimensiones)
   - [7.3 Carga de la Tabla de Hechos](#73-carga-de-la-tabla-de-hechos)
8. [Desafíos y Soluciones](#8-desafíos-y-soluciones)
9. [Conclusiones](#9-conclusiones)

## 1. Selección de la Base de Datos Transaccional

Para este proyecto, seleccioné el dataset de "NYC Yellow Taxi Trip Data" correspondiente a enero de 2019, publicado por la Comisión de Taxis y Limusinas de Nueva York (TLC). Este conjunto de datos contiene información detallada sobre los viajes realizados por los taxis amarillos en la ciudad de Nueva York, incluyendo:

- Fechas y horas de recogida y destino
- Ubicaciones de recogida y destino (mediante códigos de zonas)
- Información de tarifas y pagos
- Distancias recorridas
- Número de pasajeros
- Identificación de proveedores

La elección de este dataset se justifica por los siguientes motivos:

1. **Relevancia empresarial**: Los datos de taxis representan un caso de uso real con aplicaciones prácticas en optimización de rutas, análisis de demanda y estrategias de precios.
2. **Riqueza de dimensiones**: El conjunto de datos ofrece múltiples dimensiones (tiempo, ubicación, proveedor, tipo de pago) que permiten crear un modelo dimensional completo.
3. **Volumen adecuado**: Con millones de registros mensuales, proporciona un volumen suficiente para demostrar las capacidades de un data warehouse sin ser inmanejable.
4. **Disponibilidad pública**: Los datos son de acceso público a través del portal NYC Open Data (https://data.cityofnewyork.us), lo que facilita su reproducibilidad y verificación.
5. **Actualizaciones periódicas**: Al ser actualizado mensualmente, permite diseñar un sistema escalable para cargas incrementales.

## 2. Identificación de Dimensiones y Tablas de Hechos

Tras analizar la estructura de los datos de Yellow Taxi, identifiqué un esquema con una tabla de hechos central y cinco dimensiones principales:

### Tabla de Hechos

- **fact_taxi_trips**: Contiene las métricas y medidas de cada viaje, como distancia recorrida, tiempo de viaje y montos monetarios.

### Dimensiones

1. **dim_tiempo**: Dimensión temporal que almacena información jerárquica sobre las fechas y horas.

   - _Justificación_: Permite análisis por diferentes granularidades temporales (hora, día, mes, etc.)

2. **dim_ubicacion**: Contiene información sobre las zonas geográficas de Nueva York.

   - _Justificación_: Facilita el análisis de patrones geográficos de los viajes

3. **dim_proveedor**: Almacena información sobre las compañías proveedoras de servicios de taxi.

   - _Justificación_: Permite comparar el desempeño entre diferentes compañías

4. **dim_pago**: Contiene los diferentes métodos de pago utilizados.

   - _Justificación_: Facilita el análisis de preferencias de pago y su influencia en propinas

5. **dim_tarifa**: Define los diferentes tipos de tarifas aplicables a los viajes.
   - _Justificación_: Permite analizar la rentabilidad por tipo de tarifa

Las métricas principales identificadas en la tabla de hechos incluyen:

- Distancia del viaje (millas)
- Duración del viaje (minutos)
- Tarifa base (USD)
- Recargos adicionales (USD)
- Propina (USD)
- Monto total (USD)
- Cantidad de pasajeros

## 3. Definición del Modelo Estrella

Para este proyecto, implementé un **modelo estrella** en lugar de un modelo copo de nieve. Esta decisión se fundamenta en las siguientes razones:

1. **Simplicidad de consultas**: El modelo estrella facilita la creación de consultas analíticas mediante joins directos entre la tabla de hechos y las dimensiones, sin necesidad de múltiples joins entre tablas de dimensiones normalizadas.

2. **Rendimiento**: Para cargas de trabajo analíticas (OLAP), el modelo estrella suele ofrecer mejor rendimiento al minimizar el número de joins necesarios para responder consultas complejas.

3. **Jerarquías planas**: Las dimensiones identificadas (tiempo, ubicación, proveedor, pago, tarifa) tienen jerarquías relativamente planas que no justifican una mayor normalización.

4. **Facilidad de mantenimiento**: Un modelo más sencillo facilita su mantenimiento y comprensión por parte de los usuarios finales y desarrolladores.

5. **Enfoque analítico**: El data warehouse está diseñado principalmente para análisis, no para procesamiento transaccional, por lo que la redundancia controlada es aceptable en favor de un mejor rendimiento de consulta.

El modelo estrella implementado ubica la tabla `fact_taxi_trips` en el centro, conectada directamente a las cinco tablas de dimensiones a través de sus respectivas claves foráneas.

## 4. Taxonomía y Nomenclatura

He establecido las siguientes convenciones de nomenclatura para mantener consistencia y claridad en la estructura del data warehouse:

### Prefijos de Tablas

- **dim\_**: Prefijo para tablas de dimensiones (ej. `dim_tiempo`, `dim_ubicacion`)
- **fact\_**: Prefijo para tablas de hechos (ej. `fact_taxi_trips`)
- **stage\_**: Prefijo para tablas de staging (ej. `stage_yellow_taxi_data`)

### Convención de Nombres para Columnas

- **Claves primarias**: `[entidad]_id` (ej. `tiempo_id`, `ubicacion_id`, `viaje_id`)
- **Claves foráneas**: Nombre de la clave primaria referenciada (ej. `proveedor_id`, `pago_id`)
- **Métricas**: Nombre descriptivo con sufijo de unidad (ej. `distancia_millas`, `monto_total_usd`)
- **Indicadores booleanos**: Prefijo `es_` (ej. `es_fin_semana`, `es_aeropuerto`)
- **Nombres en español**: Para mantener coherencia cultural y facilitar la comprensión en el contexto latinoamericano

### Convención para Índices

- **Índices de clave primaria**: Generados automáticamente por MySQL
- **Índices de clave foránea**: `fk_[tabla]_[campo]` (ej. `fk_fact_taxi_trips_proveedor`)
- **Índices de rendimiento**: `idx_[tabla]_[campo(s)]` (ej. `idx_stage_procesado`)

Esta taxonomía bien definida facilita:

- La comprensión rápida del propósito de cada tabla y columna
- El mantenimiento del código y la depuración
- La consistencia a través de todo el modelo de datos

## 5. Implementación de la Base de Datos

La implementación del data warehouse se realizó en MySQL mediante scripts SQL bien estructurados. A continuación, se presenta un extracto del script principal que crea todas las tablas necesarias:

### Extracto de CreateTablesTaxi.sql

```sql
-- Script de creación de esquema para NYC Yellow Taxi Data Warehouse
-- Modelo Estrella

DROP DATABASE IF EXISTS nyc_taxi_dw;
CREATE DATABASE nyc_taxi_dw;
USE nyc_taxi_dw;

-- TABLAS DE DIMENSIONES

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

-- (Resto de las definiciones de tablas)
```

El script completo incluye la definición detallada de todas las tablas con:

- Tipos de datos apropiados para cada columna
- Restricciones de integridad referencial
- Índices para optimizar consultas
- Valores predeterminados y restricciones NOT NULL
- Comentarios explicativos sobre el propósito de las tablas y columnas

## 6. Diagrama Entidad-Relación

El Diagrama Entidad-Relación (DER) fue generado utilizando MySQL Workbench a partir del script `ScriptDER.sql`. Este script define todas las tablas y sus relaciones para generar una representación visual del modelo.

### Características del DER

1. **Estructura de Estrella**: Muestra claramente la tabla de hechos `fact_taxi_trips` en el centro, conectada a las cinco tablas de dimensiones.

2. **Relaciones Uno a Muchos**: Cada dimensión se relaciona con la tabla de hechos mediante una relación uno a muchos (1:N).

3. **Claves Primarias y Foráneas**: Todas las relaciones están establecidas mediante claves primarias en las dimensiones y sus correspondientes claves foráneas en la tabla de hechos.

4. **Cardinalidad**: La cardinalidad de las relaciones está claramente indicada, mostrando cómo cada registro en las dimensiones puede estar relacionado con múltiples registros en la tabla de hechos.

5. **Tablas Auxiliares**: Se incluye también la tabla de staging `stage_yellow_taxi_data`, que aunque no forma parte del modelo dimensional, es crucial para el proceso ETL.

El DER proporciona una visualización clara de la estructura del data warehouse, facilitando la comprensión de las relaciones entre las diferentes entidades y la estructura general del modelo estrella implementado.

## 7. Proceso ETL

El proceso de Extracción, Transformación y Carga (ETL) se implementó en tres fases principales, utilizando scripts SQL específicos para cada etapa.

### 7.1 Carga de la Tabla Stage

La primera fase del proceso ETL consiste en cargar los datos desde el archivo CSV original a la tabla de staging, utilizando el script `CreateStageTable.sql`:

```sql
USE nyc_taxi_dw;

-- Truncar la tabla de staging si ya contiene datos
TRUNCATE TABLE stage_yellow_taxi_data;

-- Configurar características de importación
SET SESSION sql_mode = '';  -- Permitir valores NULL o vacíos
SET GLOBAL max_allowed_packet = 1073741824;  -- 1GB para archivos grandes
SET GLOBAL local_infile = 1;  -- Permitir carga local de archivos

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
    tpep_dropoff_datetime
    -- (Resto de campos)
)
SET archivo_origen = 'yellow_tripdata_2019-01.csv',
    fecha_carga = NOW();

-- Verificación de datos cargados
SELECT COUNT(*) AS total_registros FROM stage_yellow_taxi_data;
```

Este script realiza las siguientes operaciones:

1. Configuración del entorno MySQL para la carga de archivos grandes
2. Carga de datos desde un archivo CSV a la tabla de staging
3. Registro de metadatos (fecha de carga, origen del archivo)
4. Verificaciones de calidad para detectar valores nulos o problemas en los datos

### 7.2 Carga de Dimensiones

La segunda fase consiste en poblar las tablas de dimensiones con datos limpios y transformados, utilizando el script `CreateDimFacts.sql`. Para la dimensión tiempo, se implementó un procedimiento almacenado especial:

```sql
-- Procedimiento para generar datos de tiempo para un rango de fechas
DELIMITER //
DROP PROCEDURE IF EXISTS llenar_dim_tiempo;
CREATE PROCEDURE llenar_dim_tiempo(fecha_inicio DATE, fecha_fin DATE)
BEGIN
    DECLARE fecha_actual DATETIME;
    -- (Declaración de variables)

    SET fecha_actual = fecha_inicio;

    WHILE fecha_actual <= fecha_fin DO
        -- (Lógica para generar registros de tiempo)
    END WHILE;
END //
DELIMITER ;

-- Ejecutar el procedimiento con el rango de fechas de enero 2019
CALL llenar_dim_tiempo('2019-01-01', '2019-01-31');
```

Para las otras dimensiones, se utilizaron inserciones directas:

```sql
-- Cargar dimensión ubicación
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
```

### 7.3 Carga de la Tabla de Hechos

Debido a problemas de rendimiento con grandes volúmenes de datos, se desarrolló un script optimizado (`FillDimFacts.sql`) para cargar la tabla de hechos en pequeños lotes:

```sql
-- Crear tabla temporal para IDs específicos
DROP TEMPORARY TABLE IF EXISTS temp_stage_ids;
CREATE TEMPORARY TABLE temp_stage_ids AS
SELECT stage_id
FROM stage_yellow_taxi_data
WHERE procesado = 0
AND VendorID IS NOT NULL
-- (Otras condiciones)
LIMIT 20;

-- Insertar en la tabla de hechos
INSERT INTO fact_taxi_trips (
    tiempo_recogida_id,
    tiempo_destino_id,
    -- (Otros campos)
)
SELECT
    -- Dimensión tiempo
    (SELECT MIN(tiempo_id) FROM dim_tiempo
     WHERE HOUR(fecha_completa) = HOUR(s.tpep_pickup_datetime)
     AND DATE(fecha_completa) = DATE(s.tpep_pickup_datetime)),
    -- (Otras selecciones)
FROM
    stage_yellow_taxi_data s
JOIN
    temp_stage_ids t ON s.stage_id = t.stage_id
WHERE
    s.procesado = 0;
```

Esta estrategia de carga en lotes pequeños permitió:

1. Evitar problemas de timeout en la conexión MySQL
2. Procesar registros en grupos manejables
3. Mantener un control sobre los registros ya procesados
4. Resolver problemas con valores nulos o inconsistentes

## 8. Desafíos y Soluciones

Durante la implementación del data warehouse, enfrenté varios desafíos que requirieron soluciones específicas:

### Problemas de Timeout en MySQL

**Desafío**: Al intentar cargar grandes volúmenes de datos en la tabla de hechos, se producían errores de timeout como `Error Code: 2013. Lost connection to MySQL server during query`.

**Solución**: Implementé una estrategia de carga incremental con lotes muy pequeños (20 registros) y utilicé tablas temporales para optimizar el proceso. También modifiqué los parámetros de conexión de MySQL para aumentar los tiempos de espera.

### Valores Nulos y Dimensiones Faltantes

**Desafío**: Algunos registros contenían valores nulos o referencias a identificadores de dimensiones que no existían (como el `VendorID = 4`).

**Solución**: Implementé un manejo robusto de nulos utilizando funciones como `IFNULL` y `COALESCE`, y creé valores predeterminados en las dimensiones para manejar referencias desconocidas o nulas.

```sql
-- Añadir proveedor desconocido y faltantes
INSERT IGNORE INTO dim_proveedor (vendor_id, proveedor_nombre)
VALUES
    (0, 'Proveedor Desconocido'),
    (4, 'Otro Proveedor');
```

### Rendimiento de Joins Complejos

**Desafío**: Los joins entre la tabla de staging y múltiples dimensiones resultaban en consultas de bajo rendimiento.

**Solución**: Reemplacé los joins complejos por subconsultas independientes para cada dimensión, lo que resultó en un mejor rendimiento:

```sql
(SELECT MIN(tiempo_id) FROM dim_tiempo
 WHERE HOUR(fecha_completa) = HOUR(s.tpep_pickup_datetime)
 AND DATE(fecha_completa) = DATE(s.tpep_pickup_datetime))
```

### Integración de Datos Temporales

**Desafío**: El formato de fecha y hora en los datos originales requería transformaciones para integrarse con la dimensión de tiempo.

**Solución**: Implementé funciones de formateo de fechas para asegurar que los registros se unieran correctamente con la dimensión tiempo:

```sql
DATE_FORMAT(s.tpep_pickup_datetime, '%Y-%m-%d %H:%i:00')
```

## 9. Conclusiones

La implementación del data warehouse para los datos de NYC Yellow Taxi demuestra la aplicación práctica de los conceptos de modelado dimensional en un caso de uso real. El modelo estrella diseñado proporciona una estructura óptima para realizar análisis sobre patrones de viajes de taxi, comportamientos de pago y rendimiento por zonas geográficas.

Los principales logros de este proyecto incluyen:

1. Creación de un modelo dimensional completo y bien estructurado con cinco dimensiones y una tabla de hechos.

2. Implementación de un proceso ETL que maneja eficientemente los datos desde la fuente original hasta el data warehouse.

3. Solución de problemas técnicos como timeouts en MySQL, manejo de valores nulos y optimización de rendimiento.

4. Establecimiento de una taxonomía clara y consistente para las tablas y campos.

5. Desarrollo de scripts modulares y reutilizables para cada fase del proceso ETL.

Este data warehouse proporciona una base sólida para análisis como:

- Análisis de patrones de viaje por hora y día de la semana
- Comparación de rendimiento entre diferentes proveedores de servicios
- Identificación de las rutas más rentables y zonas de mayor demanda
- Análisis de preferencias de pago y su relación con las propinas

El enfoque modular y las técnicas de optimización implementadas aseguran que este modelo pueda escalarse para manejar cargas de datos mayores y actualizaciones periódicas, cumpliendo así con los requisitos de un sistema de data warehouse empresarial.
