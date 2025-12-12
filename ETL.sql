-- ================================================
-- ETL.sql
-- Final Project - Internet Users
-- Step-by-step ETL: create DB, staging, normalized tables,
-- load CSV data, transform & load into 3NF schema.
-- ================================================

-- --------------------------------
-- Step 0: Create database & use it
-- --------------------------------
DROP DATABASE IF EXISTS InternetUsers;
CREATE DATABASE InternetUsers COLLATE utf8mb4_unicode_ci;
USE InternetUsers;

SET NAMES 'utf8mb4';

-- --------------------------------
-- Step 1: Create staging tables
-- --------------------------------
-- staging_data1: raw facts from data1.csv
-- Columns (from CSV): Entity, Code, Year, InternetUsers
CREATE TABLE staging_data1 (
    Entity         VARCHAR(200),
    Code           VARCHAR(10),
    Year           INT,
    InternetUsers  DOUBLE
) COLLATE utf8mb4_unicode_ci;

-- staging_data2: raw country & region data from data2.csv
-- CSV columns: 
-- name, alpha-2, alpha-3, country-code, iso_3166-2,
-- region, sub-region, intermediate-region,
-- region-code, sub-region-code, intermediate-region-code
CREATE TABLE staging_data2 (
    name                     VARCHAR(200),
    alpha2                   CHAR(2),
    alpha3                   CHAR(3),
    country_code             VARCHAR(10),
    iso_3166_2               VARCHAR(50),
    region                   VARCHAR(100),
    sub_region               VARCHAR(100),
    intermediate_region      VARCHAR(100),
    region_code              VARCHAR(10),
    sub_region_code          VARCHAR(10),
    intermediate_region_code VARCHAR(10)
) COLLATE utf8mb4_unicode_ci;


-- --------------------------------
-- Step 2: Load raw CSV into staging
-- --------------------------------

-- 2.1 Load data1.csv
LOAD DATA INFILE '/var/lib/mysql-files/data1.csv'
INTO TABLE staging_data1
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(Entity, Code, Year, InternetUsers);

-- 2.2 Load data2.csv
LOAD DATA INFILE '/var/lib/mysql-files/data2.csv'
INTO TABLE staging_data2
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@name, @alpha2, @alpha3, @country_code, @iso_3166_2,
 @region, @sub_region, @intermediate_region,
 @region_code, @sub_region_code, @intermediate_region_code)
SET
    name                     = NULLIF(@name, ''),
    alpha2                   = NULLIF(@alpha2, ''),
    alpha3                   = NULLIF(@alpha3, ''),
    country_code             = NULLIF(@country_code, ''),
    iso_3166_2               = NULLIF(@iso_3166_2, ''),
    region                   = NULLIF(@region, ''),
    sub_region               = NULLIF(@sub_region, ''),
    intermediate_region      = NULLIF(@intermediate_region, ''),
    region_code              = NULLIF(@region_code, ''),
    sub_region_code          = NULLIF(@sub_region_code, ''),
    intermediate_region_code = NULLIF(@intermediate_region_code, '');


-- --------------------------------
-- Step 3: Create normalized tables
-- (based on Phase 1 ERD)
-- --------------------------------

-- 3.1 Region
CREATE TABLE Region (
    RegionID    INT PRIMARY KEY AUTO_INCREMENT,
    RegionName  VARCHAR(100) NOT NULL UNIQUE,
    RegionCode  INT NULL
) COLLATE utf8mb4_unicode_ci;

-- 3.2 SubRegion
CREATE TABLE SubRegion (
    SubRegionID   INT PRIMARY KEY AUTO_INCREMENT,
    RegionID      INT NOT NULL,
    SubRegionName VARCHAR(100) NOT NULL UNIQUE,
    SubRegionCode INT NULL,
    CONSTRAINT FK_SubRegion_Region
        FOREIGN KEY (RegionID) REFERENCES Region(RegionID)
) COLLATE utf8mb4_unicode_ci;

-- 3.3 IntermediateRegion
CREATE TABLE IntermediateRegion (
    IntermediateRegionID   INT PRIMARY KEY AUTO_INCREMENT,
    SubRegionID            INT NOT NULL,
    IntermediateRegionName VARCHAR(100) NOT NULL UNIQUE,
    IntermediateRegionCode INT NULL,
    CONSTRAINT FK_IntermediateRegion_SubRegion
        FOREIGN KEY (SubRegionID) REFERENCES SubRegion(SubRegionID)
) COLLATE utf8mb4_unicode_ci;

-- 3.4 Country
CREATE TABLE Country (
    CountryID           INT PRIMARY KEY AUTO_INCREMENT,
    CountryName         VARCHAR(200) NOT NULL,
    Alpha2Code          CHAR(2) NULL,
    Alpha3Code          CHAR(3) NOT NULL,
    CountryNumericCode  INT NULL,
    RegionID            INT NOT NULL,
    SubRegionID         INT NOT NULL,
    IntermediateRegionID INT NULL,
    CONSTRAINT UQ_Country_Alpha3 UNIQUE (Alpha3Code),
    CONSTRAINT UQ_Country_Name   UNIQUE (CountryName),
    CONSTRAINT FK_Country_Region
        FOREIGN KEY (RegionID) REFERENCES Region(RegionID),
    CONSTRAINT FK_Country_SubRegion
        FOREIGN KEY (SubRegionID) REFERENCES SubRegion(SubRegionID),
    CONSTRAINT FK_Country_IntermediateRegion
        FOREIGN KEY (IntermediateRegionID) REFERENCES IntermediateRegion(IntermediateRegionID)
) COLLATE utf8mb4_unicode_ci;

-- 3.5 InternetUserFact
CREATE TABLE InternetUserFact (
    CountryID     INT NOT NULL,
    Year          INT NOT NULL,
    InternetUsers BIGINT NOT NULL,
    CONSTRAINT PK_InternetUserFact PRIMARY KEY (CountryID, Year),
    CONSTRAINT FK_InternetUserFact_Country
        FOREIGN KEY (CountryID) REFERENCES Country(CountryID)
) COLLATE utf8mb4_unicode_ci;


-- --------------------------------
-- Step 4: Transform & Load - Region hierarchy
-- --------------------------------

-- 4.1 Load Region from staging_data2 (distinct region)
INSERT INTO Region (RegionName, RegionCode)
SELECT DISTINCT
    region,
    region_code
FROM staging_data2
WHERE region IS NOT NULL
  AND region <> '';

-- 4.2 Load SubRegion from staging_data2 (distinct sub_region + Region)
INSERT INTO SubRegion (RegionID, SubRegionName, SubRegionCode)
SELECT DISTINCT
    r.RegionID,
    s.sub_region,
    s.sub_region_code
FROM staging_data2 s
JOIN Region r
  ON s.region = r.RegionName
WHERE s.sub_region IS NOT NULL
  AND s.sub_region <> '';

-- 4.3 Load IntermediateRegion (only non-null intermediate_region)
INSERT INTO IntermediateRegion (SubRegionID, IntermediateRegionName, IntermediateRegionCode)
SELECT DISTINCT
    sr.SubRegionID,
    s.intermediate_region,
    s.intermediate_region_code
FROM staging_data2 s
JOIN SubRegion sr
  ON s.sub_region = sr.SubRegionName
WHERE s.intermediate_region IS NOT NULL
  AND s.intermediate_region <> '';


-- --------------------------------
-- Step 5: Transform & Load - Country
-- --------------------------------
-- staging_data2  region / sub_region / intermediate_region
-- > Region / SubRegion / IntermediateRegion  FK

INSERT INTO Country (
    CountryName,
    Alpha2Code,
    Alpha3Code,
    CountryNumericCode,
    RegionID,
    SubRegionID,
    IntermediateRegionID
)
SELECT DISTINCT
    s.name,
    s.alpha2,
    s.alpha3,
    s.country_code,
    r.RegionID,
    sr.SubRegionID,
    ir.IntermediateRegionID
FROM staging_data2 s
JOIN Region r
  ON s.region     = r.RegionName
JOIN SubRegion sr
  ON s.sub_region = sr.SubRegionName
LEFT JOIN IntermediateRegion ir
  ON s.intermediate_region = ir.IntermediateRegionName;

-- ==========================================================
-- Step X: Fix special case: Antarctica (missing region info)
-- ==========================================================

-- Create a Region entry for Antarctica (if not exists)
INSERT IGNORE INTO Region (RegionName, RegionCode)
VALUES ('Antarctica', NULL);

-- Create a SubRegion entry for Antarctica (if not exists)
INSERT IGNORE INTO SubRegion (RegionID, SubRegionName, SubRegionCode)
SELECT r.RegionID, 'Antarctica', NULL
FROM Region r
WHERE r.RegionName = 'Antarctica';

-- Insert Antarctica as Country (if not exists)
INSERT INTO Country (
    CountryName,
    Alpha2Code,
    Alpha3Code,
    CountryNumericCode,
    RegionID,
    SubRegionID,
    IntermediateRegionID
)
SELECT
    s.name,
    s.alpha2,
    s.alpha3,
    s.country_code,
    r.RegionID,
    sr.SubRegionID,
    NULL
FROM staging_data2 s
JOIN Region r
  ON r.RegionName = 'Antarctica'
JOIN SubRegion sr
  ON sr.SubRegionName = 'Antarctica'
WHERE s.name = 'Antarctica'
ON DUPLICATE KEY UPDATE
    RegionID = VALUES(RegionID),
    SubRegionID = VALUES(SubRegionID),
    IntermediateRegionID = VALUES(IntermediateRegionID);

-- Insert Antarctica Internet User Facts (only missing years)
INSERT IGNORE INTO InternetUserFact (CountryID, Year, InternetUsers)
SELECT
    c.CountryID,
    d.Year,
    CAST(d.InternetUsers AS SIGNED)
FROM staging_data1 d
JOIN Country c
  ON d.Code = c.Alpha3Code
WHERE c.CountryName = 'Antarctica'
  AND d.Year IS NOT NULL
  AND d.InternetUsers IS NOT NULL
  AND d.Year BETWEEN 1900 AND 2100;



-- --------------------------------
-- Step 6: Transform & Load - InternetUserFact
-- --------------------------------
--  data1.csv  Code (alpha-3) > Country.Alpha3Code

INSERT INTO InternetUserFact (CountryID, Year, InternetUsers)
SELECT
    c.CountryID,
    d.Year,
    -- 1
    CAST(d.InternetUsers AS SIGNED)
FROM staging_data1 d
JOIN Country c
  ON d.Code = c.Alpha3Code
WHERE d.Year IS NOT NULL
  AND d.Year BETWEEN 1900 AND 2100
  AND d.InternetUsers IS NOT NULL;


-- --------------------------------
-- Step 7: Basic Data Quality Checks
-- --------------------------------

-- 7.1
SELECT COUNT(*) AS CountryCount FROM Country;

-- 7.2
SELECT COUNT(*) AS FactCount FROM InternetUserFact;

-- 7.3
SELECT c.CountryName, f.Year, f.InternetUsers
FROM Country c
JOIN InternetUserFact f ON c.CountryID = f.CountryID
WHERE c.CountryName = 'Taiwan'
ORDER BY f.Year;
