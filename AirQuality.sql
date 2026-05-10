-- =============================================================================
-- Air Quality Case Study
-- Dataset : UCI Air Quality Dataset (AirQualityUCI.csv)
-- Source  : https://archive.ics.uci.edu/dataset/360/air+quality
-- Author  : Plinio Durango
-- Date    : 2025
-- =============================================================================
-- TABLE OF CONTENTS
--   PART 1 - Background & Dataset Overview
--   PART 2 - Exploratory Data Analysis (7-Step Framework)
--             Step 1 : Inspect the table
--             Step 2 : What does one row represent?
--             Step 3 : Table dimensions
--             Step 4 : Column value ranges (CO, Benzene, NO2)
--             Step 5 : Date range validation
--             Step 6 : Duplicate check
--             Step 7 : Missing value check
--   PART 3 - Data Cleaning View
--   PART 4 - Analysis Queries
--             Query 1 : Monthly pollutant averages (all pollutants combined)
--             Query 2 : Month with highest & lowest average per pollutant
--             Query 3 : Days exceeding critical thresholds (WHO standards)
--             Query 4 : Hourly pollution patterns (peak hours)
--             Query 5 : Temperature & humidity correlation with CO
-- =============================================================================


-- =============================================================================
-- PART 1 - BACKGROUND & DATASET OVERVIEW
-- =============================================================================

/*
CONTEXT
-------
This case study analyzes air quality measurements collected by a
gas multisensor device deployed in a heavily polluted area of an Italian city.
Hourly average responses from five metal oxide chemical sensors are recorded
alongside ground-truth concentrations from a certified reference analyzer.

DATASET
-------
Source  : UCI Machine Learning Repository
URL     : https://archive.ics.uci.edu/dataset/360/air+quality
Period  : March 2004 - April 2005 (390 days)
Rows    : 9,357 hourly observations
Columns : 15 (after removing 2 empty trailing columns)

KEY COLUMNS
-----------
  CO(GT)      - Ground truth CO concentration       [mg/m^3]
  C6H6(GT)    - Ground truth Benzene concentration  [microg/m^3]
  NO2(GT)     - Ground truth NO2 concentration      [microg/m^3]
  PT08.S1-S5  - Metal oxide sensor responses        [dimensionless]
  T           - Temperature                         [Celsius]
  RH          - Relative Humidity                   [%]
  AH          - Absolute Humidity                   [g/m^3]

MISSING VALUE ENCODING
----------------------
The value -200 is used throughout the dataset as a placeholder for
missing (NULL) measurements, as documented in the UCI repository.
All analysis queries use NULLIF(column, -200) to exclude these values.

ANALYTICAL FOCUS
----------------
This study focuses on three reference pollutant columns:
CO(GT), C6H6(GT), and NO2(GT). These represent high-precision
measurements from certified analyzers -- the ground truth that
low-cost metal oxide sensors aim to replicate at scale.
The broader research goal is to model:
    CO(GT) = f(sensor signals, temperature, humidity)
While predictive modeling is outside the scope of this case study,
the EDA below establishes a strong foundation for understanding
air quality patterns in this region of Italy.
*/

USE case_study_hmw;

-- =============================================================================
-- PART 2 - EXPLORATORY DATA ANALYSIS (7-STEP FRAMEWORK)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STEP 1: Inspect the table
-- -----------------------------------------------------------------------------

SELECT *
FROM airqualityuci
LIMIT 100;

/*
OBSERVATIONS:
- The table has 17 columns. The last two are entirely empty (NULL)
  and will be dropped below.
- Measurements are recorded hourly based on the Time column.
- Columns CO(GT) through AH each represent the hourly average
  for that variable.
- Several numeric columns are stored as TEXT due to import formatting.
  This must be corrected before any numerical analysis.
*/

-- Drop the two empty trailing columns left over from CSV import
ALTER TABLE airqualityuci
DROP COLUMN MyUnknownColumn;

ALTER TABLE airqualityuci
DROP COLUMN `MyUnknownColumn_[0]`;


-- -----------------------------------------------------------------------------
-- STEP 2: What does one row represent?
-- -----------------------------------------------------------------------------

/*
Each row corresponds to one hour of air quality measurements,
capturing multiple pollutant concentrations alongside environmental
variables such as temperature and relative humidity.

Composite identifier: (Date, Time) -- since measurements are hourly,
each Date-Time pair should uniquely identify one observation.
There is no explicit primary key column in this dataset.
*/


-- -----------------------------------------------------------------------------
-- STEP 3: Table dimensions
-- -----------------------------------------------------------------------------

SELECT COUNT(*) AS total_rows
FROM airqualityuci;
-- Result: 9,357 rows

DESCRIBE airqualityuci;
/*
OBSERVATIONS:
- 15 columns remain after dropping the two empty columns.
- Several columns that should be numeric are stored as TEXT.
  This happens when the CSV importer cannot parse the decimal
  separator format (comma vs. period).

Columns requiring type correction:
  CO(GT)   -- pollutant concentration [FLOAT/DOUBLE]
  C6H6(GT) -- pollutant concentration [FLOAT/DOUBLE]
  T        -- temperature              [FLOAT/DOUBLE]
  RH       -- relative humidity        [FLOAT/DOUBLE]
  AH       -- absolute humidity        [FLOAT/DOUBLE]
*/

-- Fix data types for numerical columns stored as TEXT
ALTER TABLE airqualityuci MODIFY COLUMN `CO(GT)`   DOUBLE;
ALTER TABLE airqualityuci MODIFY COLUMN `C6H6(GT)` DOUBLE;
ALTER TABLE airqualityuci MODIFY COLUMN `T`        DOUBLE;
ALTER TABLE airqualityuci MODIFY COLUMN `RH`       DOUBLE;
ALTER TABLE airqualityuci MODIFY COLUMN `AH`       DOUBLE;

-- Verify the fix
SELECT `CO(GT)`, `C6H6(GT)`, T, RH, AH
FROM airqualityuci
LIMIT 5;
-- All five columns should now display numeric values correctly.


-- -----------------------------------------------------------------------------
-- STEP 4: What values can each column take?
-- -----------------------------------------------------------------------------

-- CO(GT): Carbon Monoxide concentration [mg/m^3]
SELECT
    COUNT(DISTINCT `CO(GT)`)         AS distinct_values,
    MIN(NULLIF(`CO(GT)`,   -200))    AS min_co,
    MAX(NULLIF(`CO(GT)`,   -200))    AS max_co
FROM airqualityuci;
-- 96 distinct values | Range: 0 to 11.9 mg/m^3 (excluding -200 placeholders)

-- C6H6(GT): Benzene concentration [microg/m^3]
SELECT
    COUNT(DISTINCT `C6H6(GT)`)       AS distinct_values,
    MIN(NULLIF(`C6H6(GT)`, -200))    AS min_benzene,
    MAX(NULLIF(`C6H6(GT)`, -200))    AS max_benzene
FROM airqualityuci;
-- 398 distinct values | Range: 0 to 9.9 microg/m^3

-- NO2(GT): Nitrogen Dioxide concentration [microg/m^3]
SELECT
    COUNT(DISTINCT `NO2(GT)`)        AS distinct_values,
    MIN(NULLIF(`NO2(GT)`,  -200))    AS min_no2,
    MAX(NULLIF(`NO2(GT)`,  -200))    AS max_no2
FROM airqualityuci;
-- 283 distinct values | Range: 0 to 340 microg/m^3

-- -----------------------------------------------------------------------------
-- STEP 5: Date range validation
-- -----------------------------------------------------------------------------

/*
The Date column is stored in dd/mm/YYYY format, which is not directly
compatible with SQL date functions. We use STR_TO_DATE() to convert it
to the standard YYYY-MM-DD format for all date-based operations.
*/

SELECT
    MIN(STR_TO_DATE(Date, '%d/%m/%Y'))  AS start_date,
    MAX(STR_TO_DATE(Date, '%d/%m/%Y'))  AS end_date,
    DATEDIFF(
        MAX(STR_TO_DATE(Date, '%d/%m/%Y')),
        MIN(STR_TO_DATE(Date, '%d/%m/%Y'))
    )                                   AS total_days
FROM airqualityuci;
-- start_date: 2004-03-10 | end_date: 2005-04-04 | total_days: 390


-- -----------------------------------------------------------------------------
-- STEP 6: Duplicate check
-- -----------------------------------------------------------------------------

/*
Since there is no primary key, we use (Date, Time) as the composite
identifier. Each Date-Time pair should appear exactly once,
as measurements are recorded hourly.
*/

SELECT
    Date,
    Time,
    COUNT(*) AS occurrences
FROM airqualityuci
GROUP BY Date, Time
ORDER BY occurrences DESC
LIMIT 10;
-- All occurrences = 1: no duplicate hourly records found.


-- -----------------------------------------------------------------------------
-- STEP 7: Missing value check
-- -----------------------------------------------------------------------------

-- Count missing values (-200 placeholders) for all three focal pollutants
SELECT
    SUM(CASE WHEN `CO(GT)`   = -200 THEN 1 ELSE 0 END) AS missing_co,
    SUM(CASE WHEN `C6H6(GT)` = -200 THEN 1 ELSE 0 END) AS missing_benzene,
    SUM(CASE WHEN `NO2(GT)`  = -200 THEN 1 ELSE 0 END) AS missing_no2,
    COUNT(*)                                            AS total_rows
FROM airqualityuci;

/*
RESULTS:
  CO(GT)   : 1,683 missing out of 9,357 (18.0%)
  C6H6(GT) : 1,639 missing out of 9,357 (17.5%)
  NO2(GT)  : 1,642 missing out of 9,357 (17.5%)

Missing values are substantial (~17-18%) and likely occur during
sensor maintenance or calibration windows. All analysis queries
exclude these placeholders using NULLIF(column, -200).
*/


-- =============================================================================
-- PART 3 - DATA CLEANING VIEW
-- =============================================================================

/*
To avoid repeating NULLIF(-200) in every query, we create a clean view
that replaces all -200 placeholders with proper NULL values and converts
the Date column to standard SQL DATE format.
All analysis queries in Part 4 reference airquality_clean instead of
the raw table.
*/

CREATE OR REPLACE VIEW airquality_clean AS
SELECT
    STR_TO_DATE(Date, '%d/%m/%Y')   AS date_clean,
    Time,
    NULLIF(`CO(GT)`,      -200)     AS co_gt,
    NULLIF(`PT08.S1(CO)`, -200)     AS sensor_co,
    NULLIF(`C6H6(GT)`,    -200)     AS benzene_gt,
    NULLIF(`NOx(GT)`,     -200)     AS nox_gt,
    NULLIF(`NO2(GT)`,     -200)     AS no2_gt,
    NULLIF(`T`,           -200)     AS temperature,
    NULLIF(`RH`,          -200)     AS humidity_rel,
    NULLIF(`AH`,          -200)     AS humidity_abs
FROM airqualityuci;

-- Verify the view
SELECT * FROM airquality_clean LIMIT 5;

-- =============================================================================
-- PART 4 - ANALYSIS QUERIES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- QUERY 1: Monthly averages for all three pollutants combined
-- -----------------------------------------------------------------------------

/*
Rather than running three separate queries, we compute the monthly
average for CO, Benzene, and NO2 in a single result set.
This gives a complete month-by-month pollution overview.
*/

SELECT
    DATE_FORMAT(date_clean, '%Y-%m') AS year_month,
    ROUND(AVG(co_gt),      2)        AS avg_co_mg_m3,
    ROUND(AVG(benzene_gt), 2)        AS avg_benzene_microg_m3,
    ROUND(AVG(no2_gt),     2)        AS avg_no2_microg_m3
FROM airquality_clean
GROUP BY year_month
ORDER BY year_month;

/*
OBSERVATIONS:
- Winter months (Nov-Feb) show consistently higher CO and Benzene levels,
  likely driven by increased heating activity and reduced atmospheric
  dispersion in colder, more stable air.
- NO2 peaks in February 2005, potentially linked to higher traffic
  density during colder months when people drive more.
- April 2005 shows the lowest concentrations across all three pollutants,
  consistent with warmer temperatures improving atmospheric mixing.
*/


-- -----------------------------------------------------------------------------
-- QUERY 2: Month with highest and lowest average per pollutant
-- -----------------------------------------------------------------------------

-- CO: Highest monthly average
SELECT DATE_FORMAT(date_clean, '%Y-%m') AS year_month,
       ROUND(AVG(co_gt), 2)             AS avg_co
FROM airquality_clean
GROUP BY year_month
ORDER BY avg_co DESC
LIMIT 1;
-- Result: 2004-12, avg CO = 2.75 mg/m^3

-- CO: Lowest monthly average
SELECT DATE_FORMAT(date_clean, '%Y-%m') AS year_month,
       ROUND(AVG(co_gt), 2)             AS avg_co
FROM airquality_clean
GROUP BY year_month
ORDER BY avg_co ASC
LIMIT 1;
-- Result: 2005-04, avg CO = 1.21 mg/m^3

-- Benzene: Highest monthly average
SELECT DATE_FORMAT(date_clean, '%Y-%m') AS year_month,
       ROUND(AVG(benzene_gt), 2)         AS avg_benzene
FROM airquality_clean
GROUP BY year_month
ORDER BY avg_benzene DESC
LIMIT 1;
-- Result: 2004-10, avg Benzene = 13.08 microg/m^3

-- Benzene: Lowest monthly average
SELECT DATE_FORMAT(date_clean, '%Y-%m') AS year_month,
       ROUND(AVG(benzene_gt), 2)         AS avg_benzene
FROM airquality_clean
GROUP BY year_month
ORDER BY avg_benzene ASC
LIMIT 1;
-- Result: 2005-04, avg Benzene = 3.83 microg/m^3

-- NO2: Highest monthly average
SELECT DATE_FORMAT(date_clean, '%Y-%m') AS year_month,
       ROUND(AVG(no2_gt), 2)            AS avg_no2
FROM airquality_clean
GROUP BY year_month
ORDER BY avg_no2 DESC
LIMIT 1;
-- Result: 2005-02, avg NO2 = 160.69 microg/m^3

-- NO2: Lowest monthly average
SELECT DATE_FORMAT(date_clean, '%Y-%m') AS year_month,
       ROUND(AVG(no2_gt), 2)            AS avg_no2
FROM airquality_clean
GROUP BY year_month
ORDER BY avg_no2 ASC
LIMIT 1;
-- Result: 2004-08, avg NO2 = 70.10 microg/m^3


-- -----------------------------------------------------------------------------
-- QUERY 3: Days exceeding critical WHO threshold levels
-- -----------------------------------------------------------------------------

/*
Reference thresholds (WHO Air Quality Guidelines):
  CO(GT)   : > 10  mg/m^3     (8-hour mean guideline)
  NO2(GT)  : > 200 microg/m^3 (1-hour mean guideline)
  C6H6(GT) : >  5  microg/m^3 (annual guideline, used as hourly proxy)

We count both the number of exceedance hours and the number of
distinct days where at least one hourly reading exceeded the threshold.
*/

-- Total hours exceeding each threshold
SELECT
    SUM(CASE WHEN co_gt      > 10  THEN 1 ELSE 0 END) AS hours_co_exceeded,
    SUM(CASE WHEN no2_gt     > 200 THEN 1 ELSE 0 END) AS hours_no2_exceeded,
    SUM(CASE WHEN benzene_gt > 5   THEN 1 ELSE 0 END) AS hours_benzene_exceeded
FROM airquality_clean;

-- Distinct days exceeding each threshold
SELECT
    COUNT(DISTINCT CASE WHEN co_gt      > 10  THEN date_clean END) AS days_co_exceeded,
    COUNT(DISTINCT CASE WHEN no2_gt     > 200 THEN date_clean END) AS days_no2_exceeded,
    COUNT(DISTINCT CASE WHEN benzene_gt > 5   THEN date_clean END) AS days_benzene_exceeded
FROM airquality_clean;

/*
INTERPRETATION:
- Benzene exceeded its threshold on 378 out of 390 days (97% of the study period).
  This is a serious public health concern, as chronic Benzene exposure
  is linked to leukemia and other blood disorders.
- NO2 exceeded its threshold on 87 days (~22%), concentrated in winter months.
- CO exceeded its threshold on only 3 days, suggesting CO levels
  were generally within safe limits in this area during the study period.
*/


-- -----------------------------------------------------------------------------
-- QUERY 4: Hourly pollution patterns (peak hours of the day)
-- -----------------------------------------------------------------------------

/*
Identifying which hours of the day have the highest average pollution
can reveal links to human activity patterns such as rush hours
and residential heating cycles.
*/

SELECT
    Time                              AS hour_of_day,
    ROUND(AVG(co_gt),      2)         AS avg_co,
    ROUND(AVG(benzene_gt), 2)         AS avg_benzene,
    ROUND(AVG(no2_gt),     2)         AS avg_no2,
    COUNT(*)                          AS observations
FROM airquality_clean
GROUP BY Time
ORDER BY Time;

/*
INTERPRETATION:
- Peak CO and Benzene are expected around morning (07:00-09:00)
  and evening (17:00-20:00) rush hours, consistent with vehicle emissions.
- Overnight hours (00:00-05:00) likely show lower concentrations
  due to reduced traffic and industrial activity.
*/


-- -----------------------------------------------------------------------------
-- QUERY 5: Temperature & humidity correlation with CO levels
-- -----------------------------------------------------------------------------

/*
Cold temperatures reduce atmospheric mixing (lower boundary layer height),
causing pollutants to accumulate near the surface.
We bucket temperature into ranges and compare average pollutant
concentrations across buckets to test this hypothesis.
*/

SELECT
    CASE
        WHEN temperature < 5  THEN '1 - Very Cold (< 5 C)'
        WHEN temperature < 15 THEN '2 - Cold     (5-15 C)'
        WHEN temperature < 25 THEN '3 - Mild    (15-25 C)'
        ELSE                       '4 - Warm     (> 25 C)'
    END                            AS temp_bucket,
    COUNT(*)                       AS observations,
    ROUND(AVG(co_gt),      2)      AS avg_co,
    ROUND(AVG(benzene_gt), 2)      AS avg_benzene,
    ROUND(AVG(no2_gt),     2)      AS avg_no2,
    ROUND(AVG(humidity_rel), 1)    AS avg_humidity_pct
FROM airquality_clean
WHERE temperature IS NOT NULL
GROUP BY temp_bucket
ORDER BY temp_bucket;

/*
INTERPRETATION:
- Colder temperature buckets are expected to show higher average CO
  and Benzene concentrations due to reduced atmospheric mixing
  and increased heating and vehicle activity in cold weather.
- Higher relative humidity in cold months may also suppress some
  atmospheric dispersion, compounding the pollution effect.
*/


-- =============================================================================
-- END OF CASE STUDY
-- =============================================================================