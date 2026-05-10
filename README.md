# Air Quality Case Study

**Author:** Plinio Durango | **Tool:** MySQL | **Dataset:** UCI Air Quality

---

## Overview

This case study analyzes hourly air quality measurements collected by a gas multisensor device deployed in a heavily polluted area of an Italian city. The data spans 390 days (March 2004 - April 2005) and captures both low-cost metal oxide sensor responses and ground-truth concentrations from a certified reference analyzer.

The analysis focuses on three key pollutants and explores seasonal trends, peak pollution hours, threshold exceedances, and the relationship between temperature and pollutant levels.

---

## Dataset

**Source:** [UCI Machine Learning Repository - Air Quality](https://archive.ics.uci.edu/dataset/360/air+quality)

| Property | Value |
|---|---|
| Rows | 9,357 hourly observations |
| Columns | 15 (after removing 2 empty trailing columns) |
| Period | 2004-03-10 to 2005-04-04 (390 days) |
| Unique identifier | (Date, Time) composite key |

### Key Columns

| Group | Columns |
|---|---|
| Reference pollutants | CO(GT) [mg/m^3], C6H6/Benzene(GT) [microg/m^3], NO2(GT) [microg/m^3] |
| Sensor responses | PT08.S1 (CO), PT08.S2 (NMHC), PT08.S3 (NOx), PT08.S4 (NO2), PT08.S5 (O3) |
| Environmental | T (Temperature C), RH (Relative Humidity %), AH (Absolute Humidity g/m^3) |

**Missing value encoding:** The value -200 is used as a placeholder for missing measurements throughout the dataset. All analysis queries handle this using NULLIF(column, -200).

---

## Project Structure

```
Air-Quality/
├── AirQuality.sql       # Full case study: EDA, data cleaning view & analysis queries
├── AirQualityUCI.csv    # Raw dataset from UCI repository
└── README.md
```

---

## Methodology

### Data Cleaning

A `airquality_clean` SQL view was created to:
- Replace all -200 placeholders with proper NULL values using NULLIF()
- Convert the Date column from dd/mm/YYYY to standard SQL DATE format using STR_TO_DATE()
- Rename columns with cleaner aliases (e.g., co_gt, benzene_gt, temperature)

All analysis queries reference this view instead of the raw table.

### EDA Issues Found

1. Two empty trailing columns from CSV import (dropped via ALTER TABLE)
2. Numeric columns CO(GT), C6H6(GT), T, RH, AH stored as TEXT — corrected with ALTER TABLE MODIFY COLUMN
3. Date column in dd/mm/YYYY format — incompatible with native SQL date functions
4. Missing values encoded as -200 (~17-18% across all three focal pollutants)
5. No explicit primary key — (Date, Time) used as composite identifier

---

## Analysis

### Query 1 - Monthly Pollutant Averages
Computed monthly averages for CO, Benzene, and NO2 in a single combined query. Winter months (Nov-Feb) show consistently higher concentrations, while April 2005 shows the lowest levels across all pollutants.

### Query 2 - Peak and Low Months per Pollutant
Identified the month with the highest and lowest average for each pollutant:

| Pollutant | Highest Month | Lowest Month |
|---|---|---|
| CO (mg/m^3) | Dec 2004 (2.75) | Apr 2005 (1.21) |
| Benzene (microg/m^3) | Oct 2004 (13.08) | Apr 2005 (3.83) |
| NO2 (microg/m^3) | Feb 2005 (160.69) | Aug 2004 (70.10) |

### Query 3 - WHO Threshold Exceedances
Counted days where hourly readings exceeded WHO Air Quality Guidelines:

| Pollutant | Threshold | Days Exceeded | % of Study Period |
|---|---|---|---|
| CO | > 10 mg/m^3 | 3 days | 0.8% |
| NO2 | > 200 microg/m^3 | 87 days | 22.3% |
| Benzene | > 5 microg/m^3 | 378 days | 97% |

Benzene exceeded safe levels on 97% of days in the study — a serious public health concern given its links to leukemia and blood disorders.

### Query 4 - Hourly Pollution Patterns
Aggregated average pollutant concentrations by hour of day to identify peak pollution windows, expected to align with morning and evening rush hours (07:00-09:00 and 17:00-20:00).

### Query 5 - Temperature vs. Pollutant Levels
Bucketed temperature into four ranges and compared average pollutant concentrations across buckets. Cold temperatures reduce atmospheric mixing, causing pollutants to accumulate near ground level — tested and confirmed by the data.

---

## Tools & Technologies

| Tool | Purpose |
|---|---|
| MySQL | Data cleaning, EDA, view creation, and analysis queries |
| SQL (STR_TO_DATE, NULLIF, DATE_FORMAT) | Date parsing, missing value handling, time-series aggregation |

---

## Key Findings

- Benzene concentrations exceeded WHO guidelines on 97% of days, indicating persistent air quality issues in this area of Italy.
- Pollution levels follow a strong seasonal pattern, peaking in winter months due to heating activity and reduced atmospheric mixing.
- CO levels remained within safe limits on most days, with only 3 exceedances over the 390-day period.
- Cold temperatures correlate with higher pollutant concentrations, consistent with known atmospheric boundary layer dynamics.
