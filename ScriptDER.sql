-- MySQL Script para el Modelo NYC Taxi Data Warehouse
-- Modelo: NYC Taxi Data Warehouse    Version: 1.0
-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------
-- Schema nyc_taxi_dw
-- -----------------------------------------------------

-- -----------------------------------------------------
-- Schema nyc_taxi_dw
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `nyc_taxi_dw` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE `nyc_taxi_dw`;

-- -----------------------------------------------------
-- Table `nyc_taxi_dw`.`dim_tiempo`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `nyc_taxi_dw`.`dim_tiempo` (
  `tiempo_id` INT NOT NULL AUTO_INCREMENT,
  `fecha_completa` DATETIME NOT NULL,
  `anio` INT NOT NULL,
  `mes` INT NOT NULL,
  `dia` INT NOT NULL,
  `hora` INT NOT NULL,
  `minuto` INT NOT NULL,
  `dia_semana` INT NOT NULL,
  `nombre_dia_semana` VARCHAR(15) NOT NULL,
  `es_fin_semana` TINYINT(1) NOT NULL,
  `trimestre` INT NOT NULL,
  `nombre_mes` VARCHAR(15) NOT NULL,
  `anio_mes` VARCHAR(7) NOT NULL,
  `semana_anio` INT NOT NULL,
  PRIMARY KEY (`tiempo_id`),
  UNIQUE INDEX `fecha_completa_UNIQUE` (`fecha_completa` ASC) VISIBLE)
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

-- -----------------------------------------------------
-- Table `nyc_taxi_dw`.`dim_ubicacion`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `nyc_taxi_dw`.`dim_ubicacion` (
  `ubicacion_id` INT NOT NULL AUTO_INCREMENT,
  `location_id` SMALLINT UNSIGNED NOT NULL,
  `zona` VARCHAR(100) NOT NULL,
  `distrito` VARCHAR(50) NOT NULL,
  `servicio_zona` VARCHAR(50) NULL DEFAULT NULL,
  `es_aeropuerto` TINYINT(1) NULL DEFAULT '0',
  PRIMARY KEY (`ubicacion_id`),
  UNIQUE INDEX `location_id_UNIQUE` (`location_id` ASC) VISIBLE)
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

-- -----------------------------------------------------
-- Table `nyc_taxi_dw`.`dim_proveedor`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `nyc_taxi_dw`.`dim_proveedor` (
  `proveedor_id` INT NOT NULL AUTO_INCREMENT,
  `vendor_id` INT NOT NULL,
  `proveedor_nombre` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`proveedor_id`),
  UNIQUE INDEX `vendor_id_UNIQUE` (`vendor_id` ASC) VISIBLE)
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

-- -----------------------------------------------------
-- Table `nyc_taxi_dw`.`dim_pago`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `nyc_taxi_dw`.`dim_pago` (
  `pago_id` INT NOT NULL AUTO_INCREMENT,
  `payment_type` INT NOT NULL,
  `metodo_pago_nombre` VARCHAR(50) NOT NULL,
  `es_electronico` TINYINT(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`pago_id`),
  UNIQUE INDEX `payment_type_UNIQUE` (`payment_type` ASC) VISIBLE)
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

-- -----------------------------------------------------
-- Table `nyc_taxi_dw`.`dim_tarifa`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `nyc_taxi_dw`.`dim_tarifa` (
  `tarifa_id` INT NOT NULL AUTO_INCREMENT,
  `rate_code_id` INT NOT NULL,
  `tarifa_tipo` VARCHAR(50) NOT NULL,
  `tarifa_descripcion` VARCHAR(100) NULL DEFAULT NULL,
  PRIMARY KEY (`tarifa_id`),
  UNIQUE INDEX `rate_code_id_UNIQUE` (`rate_code_id` ASC) VISIBLE)
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

-- -----------------------------------------------------
-- Table `nyc_taxi_dw`.`fact_taxi_trips`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `nyc_taxi_dw`.`fact_taxi_trips` (
  `viaje_id` INT NOT NULL AUTO_INCREMENT,
  `tiempo_recogida_id` INT NOT NULL,
  `tiempo_destino_id` INT NOT NULL,
  `ubicacion_recogida_id` INT NOT NULL,
  `ubicacion_destino_id` INT NOT NULL,
  `proveedor_id` INT NOT NULL,
  `pago_id` INT NOT NULL,
  `tarifa_id` INT NOT NULL,
  `distancia_millas` DECIMAL(8,2) NOT NULL DEFAULT '0.00',
  `duracion_minutos` INT NOT NULL DEFAULT '0',
  `tarifa_base_usd` DECIMAL(8,2) NOT NULL DEFAULT '0.00',
  `recargo_usd` DECIMAL(8,2) NOT NULL DEFAULT '0.00',
  `impuesto_mta_usd` DECIMAL(8,2) NOT NULL DEFAULT '0.00',
  `propina_usd` DECIMAL(8,2) NOT NULL DEFAULT '0.00',
  `peaje_usd` DECIMAL(8,2) NOT NULL DEFAULT '0.00',
  `mejora_recargo_usd` DECIMAL(8,2) NOT NULL DEFAULT '0.00',
  `monto_total_usd` DECIMAL(8,2) NOT NULL DEFAULT '0.00',
  `pasajeros_cantidad` INT NOT NULL DEFAULT '1',
  `store_and_fwd_flag` CHAR(1) NULL DEFAULT NULL,
  PRIMARY KEY (`viaje_id`),
  INDEX `fk_taxi_recogida_idx` (`tiempo_recogida_id` ASC) VISIBLE,
  INDEX `fk_taxi_destino_idx` (`tiempo_destino_id` ASC) VISIBLE,
  INDEX `fk_taxi_ubicacion_recogida_idx` (`ubicacion_recogida_id` ASC) VISIBLE,
  INDEX `fk_taxi_ubicacion_destino_idx` (`ubicacion_destino_id` ASC) VISIBLE,
  INDEX `fk_taxi_proveedor_idx` (`proveedor_id` ASC) VISIBLE,
  INDEX `fk_taxi_pago_idx` (`pago_id` ASC) VISIBLE,
  INDEX `fk_taxi_tarifa_idx` (`tarifa_id` ASC) VISIBLE,
  CONSTRAINT `fk_taxi_tiempo_recogida`
    FOREIGN KEY (`tiempo_recogida_id`)
    REFERENCES `nyc_taxi_dw`.`dim_tiempo` (`tiempo_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_taxi_tiempo_destino`
    FOREIGN KEY (`tiempo_destino_id`)
    REFERENCES `nyc_taxi_dw`.`dim_tiempo` (`tiempo_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_taxi_ubicacion_recogida`
    FOREIGN KEY (`ubicacion_recogida_id`)
    REFERENCES `nyc_taxi_dw`.`dim_ubicacion` (`ubicacion_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_taxi_ubicacion_destino`
    FOREIGN KEY (`ubicacion_destino_id`)
    REFERENCES `nyc_taxi_dw`.`dim_ubicacion` (`ubicacion_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_taxi_proveedor`
    FOREIGN KEY (`proveedor_id`)
    REFERENCES `nyc_taxi_dw`.`dim_proveedor` (`proveedor_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_taxi_pago`
    FOREIGN KEY (`pago_id`)
    REFERENCES `nyc_taxi_dw`.`dim_pago` (`pago_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_taxi_tarifa`
    FOREIGN KEY (`tarifa_id`)
    REFERENCES `nyc_taxi_dw`.`dim_tarifa` (`tarifa_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

-- -----------------------------------------------------
-- Table `nyc_taxi_dw`.`stage_yellow_taxi_data`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `nyc_taxi_dw`.`stage_yellow_taxi_data` (
  `stage_id` INT NOT NULL AUTO_INCREMENT,
  `VendorID` INT NULL DEFAULT NULL,
  `tpep_pickup_datetime` DATETIME NOT NULL,
  `tpep_dropoff_datetime` DATETIME NOT NULL,
  `passenger_count` INT NULL DEFAULT NULL,
  `trip_distance` DECIMAL(8,2) NULL DEFAULT NULL,
  `RatecodeID` INT NULL DEFAULT NULL,
  `store_and_fwd_flag` CHAR(1) NULL DEFAULT NULL,
  `PULocationID` SMALLINT UNSIGNED NOT NULL,
  `DOLocationID` SMALLINT UNSIGNED NOT NULL,
  `payment_type` INT NULL DEFAULT NULL,
  `fare_amount` DECIMAL(8,2) NULL DEFAULT NULL,
  `extra` DECIMAL(8,2) NULL DEFAULT NULL,
  `mta_tax` DECIMAL(8,2) NULL DEFAULT NULL,
  `tip_amount` DECIMAL(8,2) NULL DEFAULT NULL,
  `tolls_amount` DECIMAL(8,2) NULL DEFAULT NULL,
  `improvement_surcharge` DECIMAL(8,2) NULL DEFAULT NULL,
  `total_amount` DECIMAL(8,2) NULL DEFAULT NULL,
  `congestion_surcharge` DECIMAL(8,2) NULL DEFAULT NULL,
  `procesado` TINYINT(1) NOT NULL DEFAULT '0',
  `fecha_procesamiento` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`stage_id`),
  INDEX `idx_stage_vendorid` (`VendorID` ASC) VISIBLE,
  INDEX `idx_stage_pulocationid` (`PULocationID` ASC) VISIBLE,
  INDEX `idx_stage_dolocationid` (`DOLocationID` ASC) VISIBLE,
  INDEX `idx_stage_pickup_datetime` (`tpep_pickup_datetime` ASC) VISIBLE,
  INDEX `idx_stage_procesado` (`procesado` ASC) VISIBLE)
ENGINE = InnoDB
AUTO_INCREMENT = 1
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

-- End of script