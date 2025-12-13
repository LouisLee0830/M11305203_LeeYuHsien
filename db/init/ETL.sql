-- ETL.sql
--
-- files:
--   /var/lib/mysql-files/data1.csv
--   /var/lib/mysql-files/data2.csv

SET NAMES utf8mb4;
SET sql_safe_updates = 0;

-- ------------------------------------------------------------
-- 0) Database
-- ------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS InternetUsers
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE InternetUsers;

-- Create an app user
CREATE USER IF NOT EXISTS 'InternetUsers'@'%' IDENTIFIED BY 'InternetUsersPassword';
GRANT ALL PRIVILEGES ON InternetUsers.* TO 'InternetUsers'@'%';
FLUSH PRIVILEGES;

-- ------------------------------------------------------------
-- 1) Drop tables
-- ------------------------------------------------------------
DROP TABLE IF EXISTS InternetUserFact;
DROP TABLE IF EXISTS Country;
DROP TABLE IF EXISTS IntermediateRegion;
DROP TABLE IF EXISTS SubRegion;
DROP TABLE IF EXISTS Region;

DROP TABLE IF EXISTS staging_data1;
DROP TABLE IF EXISTS staging_data2;

-- ------------------------------------------------------------
-- 2) Staging tables
-- ------------------------------------------------------------
CREATE TABLE staging_data1 (
  Entity        VARCHAR(200) NULL,
  Code          VARCHAR(50)  NULL,
  Year          INT          NULL,
  InternetUsers DOUBLE       NULL
);

CREATE TABLE staging_data2 (
  name                     VARCHAR(200) NULL,
  alpha2                   CHAR(2)      NULL,
  alpha3                   CHAR(3)      NULL,
  country_code             VARCHAR(20)  NULL,
  iso_3166_2               VARCHAR(50)  NULL,
  region                   VARCHAR(100) NULL,
  sub_region               VARCHAR(100) NULL,
  intermediate_region      VARCHAR(100) NULL,
  region_code              VARCHAR(20)  NULL,
  sub_region_code          VARCHAR(20)  NULL,
  intermediate_region_code VARCHAR(20)  NULL
);

-- ------------------------------------------------------------
-- 3) Load CSV into staging
-- ------------------------------------------------------------
TRUNCATE TABLE staging_data1;
LOAD DATA INFILE '/var/lib/mysql-files/data1.csv'
INTO TABLE staging_data1
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@Entity, @Code, @Year, @InternetUsers)
SET
  Entity        = NULLIF(REPLACE(@Entity, '\r', ''), ''),
  Code          = NULLIF(REPLACE(@Code, '\r', ''), ''),
  Year          = NULLIF(REPLACE(@Year, '\r', ''), ''),
  InternetUsers = NULLIF(REPLACE(@InternetUsers, '\r', ''), '');

TRUNCATE TABLE staging_data2;
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
  name                     = NULLIF(REPLACE(@name, '\r', ''), ''),
  alpha2                   = NULLIF(REPLACE(@alpha2, '\r', ''), ''),
  alpha3                   = NULLIF(REPLACE(@alpha3, '\r', ''), ''),
  country_code             = NULLIF(REPLACE(@country_code, '\r', ''), ''),
  iso_3166_2               = NULLIF(REPLACE(@iso_3166_2, '\r', ''), ''),
  region                   = NULLIF(REPLACE(@region, '\r', ''), ''),
  sub_region               = NULLIF(REPLACE(@sub_region, '\r', ''), ''),
  intermediate_region      = NULLIF(REPLACE(@intermediate_region, '\r', ''), ''),
  region_code              = NULLIF(REPLACE(@region_code, '\r', ''), ''),
  sub_region_code          = NULLIF(REPLACE(@sub_region_code, '\r', ''), ''),
  intermediate_region_code = NULLIF(REPLACE(@intermediate_region_code, '\r', ''), '');

-- ------------------------------------------------------------
-- 4) Antarctica
-- ------------------------------------------------------------
UPDATE staging_data2
SET region = 'Antarctica', sub_region = 'Antarctica'
WHERE name = 'Antarctica' AND region IS NULL;

-- ------------------------------------------------------------
-- 5) Normalized tables
-- ------------------------------------------------------------
CREATE TABLE Region (
  RegionID   INT AUTO_INCREMENT PRIMARY KEY,
  RegionName VARCHAR(100) NOT NULL,
  RegionCode INT NULL,
  CONSTRAINT UQ_Region_Name UNIQUE (RegionName)
);

CREATE TABLE SubRegion (
  SubRegionID   INT AUTO_INCREMENT PRIMARY KEY,
  RegionID      INT NOT NULL,
  SubRegionName VARCHAR(100) NOT NULL,
  SubRegionCode INT NULL,
  CONSTRAINT UQ_SubRegion UNIQUE (RegionID, SubRegionName),
  CONSTRAINT FK_SubRegion_Region FOREIGN KEY (RegionID) REFERENCES Region(RegionID)
);

CREATE TABLE IntermediateRegion (
  IntermediateRegionID   INT AUTO_INCREMENT PRIMARY KEY,
  SubRegionID            INT NOT NULL,
  IntermediateRegionName VARCHAR(100) NOT NULL,
  IntermediateRegionCode INT NULL,
  CONSTRAINT UQ_IntermediateRegion UNIQUE (SubRegionID, IntermediateRegionName),
  CONSTRAINT FK_IntermediateRegion_SubRegion FOREIGN KEY (SubRegionID) REFERENCES SubRegion(SubRegionID)
);

CREATE TABLE Country (
  CountryID            INT AUTO_INCREMENT PRIMARY KEY,
  CountryName          VARCHAR(200) NOT NULL,
  Alpha2Code           CHAR(2) NULL,
  Alpha3Code           CHAR(3) NOT NULL,
  CountryNumericCode   INT NULL,
  RegionID             INT NOT NULL,
  SubRegionID          INT NOT NULL,
  IntermediateRegionID INT NULL,
  CONSTRAINT UQ_Country_Name UNIQUE (CountryName),
  CONSTRAINT UQ_Country_Alpha3 UNIQUE (Alpha3Code),
  CONSTRAINT FK_Country_Region FOREIGN KEY (RegionID) REFERENCES Region(RegionID),
  CONSTRAINT FK_Country_SubRegion FOREIGN KEY (SubRegionID) REFERENCES SubRegion(SubRegionID),
  CONSTRAINT FK_Country_IntermediateRegion FOREIGN KEY (IntermediateRegionID) REFERENCES IntermediateRegion(IntermediateRegionID)
);

CREATE TABLE InternetUserFact (
  CountryID      INT NOT NULL,
  Year           INT NOT NULL,
  InternetUsers  DOUBLE NULL,
  PRIMARY KEY (CountryID, Year),
  CONSTRAINT FK_InternetUserFact_Country FOREIGN KEY (CountryID) REFERENCES Country(CountryID)
);

-- ------------------------------------------------------------
-- 6) Transform + Load
-- ------------------------------------------------------------
-- 6.1 Region
INSERT INTO Region (RegionName, RegionCode)
SELECT DISTINCT
  region,
  CAST(region_code AS UNSIGNED)
FROM staging_data2
WHERE region IS NOT NULL;

-- 6.2 SubRegion
INSERT INTO SubRegion (RegionID, SubRegionName, SubRegionCode)
SELECT DISTINCT
  r.RegionID,
  s.sub_region,
  CAST(s.sub_region_code AS UNSIGNED)
FROM staging_data2 s
JOIN Region r ON r.RegionName = s.region
WHERE s.sub_region IS NOT NULL;

-- 6.3 IntermediateRegion
INSERT INTO IntermediateRegion (SubRegionID, IntermediateRegionName, IntermediateRegionCode)
SELECT DISTINCT
  sr.SubRegionID,
  s.intermediate_region,
  CAST(s.intermediate_region_code AS UNSIGNED)
FROM staging_data2 s
JOIN Region r ON r.RegionName = s.region
JOIN SubRegion sr ON sr.RegionID = r.RegionID AND sr.SubRegionName = s.sub_region
WHERE s.intermediate_region IS NOT NULL;

-- 6.4 Country
INSERT INTO Country (CountryName, Alpha2Code, Alpha3Code, CountryNumericCode, RegionID, SubRegionID, IntermediateRegionID)
SELECT DISTINCT
  s.name,
  s.alpha2,
  s.alpha3,
  CAST(s.country_code AS UNSIGNED),
  r.RegionID,
  sr.SubRegionID,
  ir.IntermediateRegionID
FROM staging_data2 s
JOIN Region r ON r.RegionName = s.region
JOIN SubRegion sr ON sr.RegionID = r.RegionID AND sr.SubRegionName = s.sub_region
LEFT JOIN IntermediateRegion ir
  ON ir.SubRegionID = sr.SubRegionID AND ir.IntermediateRegionName = s.intermediate_region
WHERE s.alpha3 IS NOT NULL;

-- 6.5 Fact table
INSERT INTO InternetUserFact (CountryID, Year, InternetUsers)
SELECT
  c.CountryID,
  s.Year,
  s.InternetUsers
FROM staging_data1 s
JOIN Country c ON c.Alpha3Code = s.Code
WHERE s.Year IS NOT NULL;

-- ------------------------------------------------------------
-- 7) Checks
-- ------------------------------------------------------------
SELECT 'Region' AS TableName, COUNT(*) AS RowCount FROM Region;
SELECT 'SubRegion' AS TableName, COUNT(*) AS RowCount FROM SubRegion;
SELECT 'IntermediateRegion' AS TableName, COUNT(*) AS RowCount FROM IntermediateRegion;
SELECT 'Country' AS TableName, COUNT(*) AS RowCount FROM Country;
SELECT 'InternetUserFact' AS TableName, COUNT(*) AS RowCount FROM InternetUserFact;

