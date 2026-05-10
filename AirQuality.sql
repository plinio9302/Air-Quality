/* Part 1. 
This is my first case study. 
Contains the responses of a gas multisensor device
deployed on the field in an Italian city.
Hourly responses averages are recorded along with 
gas concentrations references from a certified analyzer.
The data was retrived from 
"https://archive.ics.uci.edu/dataset/360/air+quality"
*/

/* Part 2: EDA queries */ 

USE case_study_hmw;

-- 1. What's in the table? 

SELECT *
FROM airqualityuci
LIMIT 100;
 /*
 This table appears to be structured as a matrix with 17 columns.
The last two columns are entirely empty (NULL) and do not contain 
useful information, so they can be removed in a later step.

Based on the "Time" column, the measurements are recorded hourly.
From the column "CO(GT)" through "AH", each value represents the average
measurement taken over one hour.
 */
 
ALTER TABLE airqualityuci
DROP COLUMN MyUnknownColumn;

ALTER TABLE airqualityuci
DROP COLUMN `MyUnknownColumn_[0]`;


 
 -- 2. What does one row represent? 
 
 /* 
 Bases on question number 1 : 
Each row corresponds to one hour of air quality measurements,
including multiple pollutant concentrations and environmental variables
such as Temperature, Relative Humidity, etc.
 */


 
 /*
While inspecting the dataset, I noticed that some columns,
such as CO(GT), contain the value -200.
Since these columns measure pollutant concentration in mg/m^3,
negative values are physically impossible.

After reviewing the dataset documentation, I found that
the value -200 is used as a placeholder to represent
missing (NULL) measurements.
Therefore, these values should be treated as NULL in subsequent analysis.
*/
 

-- 3. What are the table dimensions?

SELECT 
	COUNT(*)
FROM airqualityuci;
-- 9357 Rows were counted in this data set

DESCRIBE airqualityuci; 
/* 
This command shows that the table contains 15 columns, 
as previously observed. However, it also reveals inconsistencies 
between certain variables and their assigned data types.

For example, the column CO(GT) represents a continuous variable measuring
pollutant concentration in mg/m^3. Since concentration values are numerical
and expected to be non-negative, this column should have a numeric data type
(e.g., FLOAT or DOUBLE).

However, the current data type is TEXT, which indicates that the values
were imported as strings. This discrepancy must be corrected before
performing numerical analysis or aggregation.

In this same situation we have:
	C6H6(GT): Which meassure 
	Ground Truth hourly averaged concentrations for Benzene in mg/m^3
    T: Temperature in Celcius
    RH: Relative Humidity %
    AH: Absolute Humidity
*/


ALTER TABLE airqualityuci
MODIFY COLUMN `CO(GT)` DOUBLE;

SELECT `CO(GT)`
FROM airqualityuci;
-- Fantastic! this column has now its appropiate data type
-- and is now ready for future computations

-- 4. What values can each column take? (Pick at least 3)


SELECT DISTINCT `CO(GT)`
FROM airqualityuci
WHERE
	`CO(GT)` > 0
ORDER BY `CO(GT)` DESC;
/*
They were 96 diferent observations. 
Ranging between (0  and 11.9) mg/m^3
Notice that we excluded
Null values(-200) 
*/

SELECT DISTINCT `C6H6(GT)`
FROM airqualityuci
WHERE
	`C6H6(GT)` > 0
ORDER BY `C6H6(GT)` DESC;
 /*
They were 398 diferent observations of Benzene. 
Ranging between (0 and 9.9) microg/m^3
Notice that we excluded
Null values(-200) 
*/

SELECT DISTINCT `NO2(GT)`
FROM airqualityuci
WHERE
	`NO2(GT)` > 0
ORDER BY `NO2(GT)` DESC;
 /*
They were 283 diferent observations. 
Ranging between (0 and 340) microg/m^3
Notice that we excluded
Null values(-200).
*/
 
 
 -- 5. Check min/max of dates, for understanding, and for any errors
 
 /* 
Check at least one date. If you don't have a date, check at least 
one other column for errors.
[Dates are nice because it's often easy to tell if they're way off.]
 */
 
SELECT 
	airqualityuci.Date
FROM 	
	airqualityuci;
 
 -- There is a problem with my column "Date"
 /* The current formating(dd/mm/YY)
 is not compatible with SQL function such as ORDER BY
 or MIN() and MAX(). Therefore we should use the function
 STR_TO_DATE() to change my curent format into a SQL format(YYYY-MM-DD)
 */
 
SELECT 
  MIN(STR_TO_DATE(airqualityuci.Date, '%d/%m/%Y')) AS min_date,
  MAX(STR_TO_DATE(airqualityuci.Date, '%d/%m/%Y')) AS max_date
FROM airqualityuci;
-- min_date = 2004-03-10
-- max_date = 2005-04-04
 
 /* We can now calculate the total time period of these observations
 -- Answer : 365 + 21 + 4 = 390
 */
 
 -- A Cleanest way for the total time period can be excecuted as follow:
 
SELECT 
	DATEDIFF(MAX(STR_TO_DATE(airqualityuci.Date, '%d/%m/%Y')),
    MIN(STR_TO_DATE(airqualityuci.Date, '%d/%m/%Y'))) AS number_of_days
FROM airqualityuci; --  390 Days

-- So my dataset has 9357 observations taken from 2004-03-10 to 2005-04-04


-- 6. Check for any duplicates, DISTINCT

SELECT 
	COUNT(*)
FROM 
	airqualityuci; -- This gave us 9357 Obserations
/*
There is no explicit primary key in this dataset.
Therefore, to assess potential duplicates, we use the combination
of Date and Time as a composite identifier.
Because measurements are taken hourly, each Date–Time pair
should uniquely represent one hourly air quality record.
*/
SELECT 
	airqualityuci.Date,
    airqualityuci.Time,
    Count(*) AS duplicates
FROM 
	airqualityuci
GROUP BY
	airqualityuci.Date,
    airqualityuci.Time
ORDER BY 
	duplicates DESC;

-- Awsome! The duplicates column starts at 1,
-- This means there is not duplicates.


-- 7. Check for any missing values: NULLS
-- Check at least one column

/* I will now procced to choose the column`CO(GT)` 
Since is the column that I am interest the most.
*/

SELECT 
	COUNT(*)
FROM 
	airqualityuci
WHERE
	`CO(GT)` = -200;
    
/*
There are 1683 out of 9357 entries, registered as 
NULL(-200) values.
*/


/* Part 3: Explore more: 
What questions do you have about this dataset? 
What are you curious about? 
What insights could you find? 
Write at least 3 queries to discover something new 
*/  


-- 1. Find the month with the highest average concentration for
-- Benzene (C6H6), CO, and NO2.

SELECT
  DATE_FORMAT(STR_TO_DATE(airqualityuci.Date, '%d/%m/%Y'), '%Y-%m') AS year_mont,
  ROUND(AVG(NULLIF(`C6H6(GT)`, -200)), 2) AS avg_benzene
FROM airqualityuci
GROUP BY year_mont
ORDER BY avg_benzene DESC
LIMIT 1;

-- Answer : 2004-10 with a concetartion of 13.08 microg/m^3

SELECT
  DATE_FORMAT(STR_TO_DATE(airqualityuci.Date, '%d/%m/%Y'), '%Y-%m') AS year_mont,
  ROUND(AVG(NULLIF(`CO(GT)`, -200)), 2) AS avg_co
FROM airqualityuci
GROUP BY year_mont
ORDER BY avg_co DESC
LIMIT 1;

-- Answer : 2004-12, with a concetartion of 2.75 mg/m^3 


SELECT
  DATE_FORMAT(STR_TO_DATE(airqualityuci.Date, '%d/%m/%Y'), '%Y-%m') AS year_mont,
  ROUND(AVG(NULLIF(`NO2(GT)`, -200)), 2) AS avg_no2
FROM airqualityuci
GROUP BY year_mont
ORDER BY avg_no2 DESC
LIMIT 1;

-- Answer : 2005-02, with a concetartion of 160.69 microg/m^3


-- 2. Find the month with the lowest average concentration for
-- Benzene (C6H6), CO, and NO2.

SELECT
  DATE_FORMAT(STR_TO_DATE(airqualityuci.Date, '%d/%m/%Y'), '%Y-%m') AS year_mont,
  ROUND(AVG(NULLIF(`C6H6(GT)`, -200)), 2) AS avg_benzene
FROM airqualityuci
GROUP BY year_mont
ORDER BY avg_benzene 
LIMIT 1;

-- Answer : 2005-04 with a concetartion of 3.83 microg/m^3

SELECT
  DATE_FORMAT(STR_TO_DATE(airqualityuci.Date, '%d/%m/%Y'), '%Y-%m') AS year_mont,
  ROUND(AVG(NULLIF(`CO(GT)`, -200)), 2) AS avg_co
FROM airqualityuci
GROUP BY year_mont
ORDER BY avg_co 
LIMIT 1;

-- Answer : 2005-04, with a concetartion of 1.21 mg/m^3 


SELECT
  DATE_FORMAT(STR_TO_DATE(airqualityuci.Date, '%d/%m/%Y'), '%Y-%m') AS year_mont,
  ROUND(AVG(NULLIF(`NO2(GT)`, -200)), 2) AS avg_no2
FROM airqualityuci
GROUP BY year_mont
ORDER BY avg_no2 
LIMIT 1;

-- Answer : 2004-08, with a concetartion of 70.10 microg/m^3

-- 3. Determine how many days each pollutant exceeded a 
-- critical threshold level.

SELECT 
    COUNT(DISTINCT DATE_FORMAT(STR_TO_DATE(Date, '%d/%m/%Y'), '%Y-%m-%d')) AS n_days_CO
FROM airqualityuci
WHERE `CO(GT)` > 10;

-- Answer : 3 days 

SELECT 
	COUNT(DISTINCT DATE_FORMAT(STR_TO_DATE(Date, '%d/%m/%Y'), '%Y-%m-%d')) n_days_no2
FROM
	airqualityuci
WHERE 
	`NO2(GT)` > 200;
    
-- Answer: 87 days


SELECT 
	COUNT(DISTINCT DATE_FORMAT(STR_TO_DATE(Date, '%d/%m/%Y'), '%Y-%m-%d')) n_days_benzene
FROM
	airqualityuci
WHERE 
	`C6H6(GT)` > 5;

-- Answer: 378 days

/* 
EXPLANATION AND JUSTIFICATON:

The reason I focused my case study on the three columns CO(GT), 
C6H6(GT), and NO2(GT) is that these variables represent 
high-precision reference measurements of pollutant concentrations.

These reference analyzers are accurate but expensive and energy-intensive.
In contrast, the metal oxide sensors (PT08.S1, S2, S3, S4, S5) are cheaper,
smaller, and can be deployed at a much larger scale. However, they do not
directly measure pollutant concentration with the same level of precision.

The underlying objective is to determine whether the responses of the
low-cost metal oxide sensors, along with environmental variables such as
temperature and humidity, can be used to predict the ground-truth
concentrations provided by the reference analyzers.

In other words, the goal is to model relationships of the form:

CO(GT) = f(sensor signals, temperature, humidity)

Although the objective of this case study is not to build a predictive model,
the dataset still provides a strong foundation for understanding the air
quality conditions in this particular area of Italy.

As demonstrated throughout the exploratory data analysis, it is possible
to extract meaningful insights regarding pollutant levels, seasonal
patterns, and threshold exceedances. Even without developing a formal
predictive model, the data allow for a comprehensive assessment of how
polluted the area was during the observation period.

Therefore, this exploratory approach remains both relevant and informative,
highlighting the value of structured EDA in environmental data analysis.
*/
