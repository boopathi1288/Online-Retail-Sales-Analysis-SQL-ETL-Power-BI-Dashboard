-- Online Retail Dataset: Cleaning and Data Modeling Script
-- Author: [Boopathi Raja Mahalingam]
-- Description: Clean and transform online retail sales data for Power BI analysis.

--------------------------------------------------
-- STEP 1: Create a clean working copy
--------------------------------------------------

SELECT * 
INTO Online_retailclean
FROM New_online_retail;

--------------------------------------------------
-- STEP 2: Handle NULLs and invalid entries
--------------------------------------------------

-- Check rows with NULL or missing key fields
SELECT *
FROM Online_retailclean
WHERE CustomerID IS NULL 
   OR StockCode IS NULL
   OR Quantity IS NULL
   OR UnitPrice IS NULL;

-- Remove rows with NULL CustomerID or zero sales
DELETE FROM Online_retailclean
WHERE CustomerID IS NULL 
   OR Quantity = 0   --In this process I am removing the 0 Quantity because there is no selling SO ther is no profit or loss--
   OR UnitPrice = 0;

--------------------------------------------------
-- STEP 3: Remove exact duplicates
--------------------------------------------------

WITH RemoveExactDuplicate AS (
  SELECT *, 
         ROW_NUMBER() OVER(PARTITION BY InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country
                           ORDER BY (SELECT NULL)) AS rn
  FROM Online_retailclean
)
DELETE FROM RemoveExactDuplicate
WHERE rn > 1;

--------------------------------------------------
-- STEP 4: Add calculated columns
--------------------------------------------------

-- Add TotalPrice
ALTER TABLE Online_retailclean 
ADD TotalPrice DECIMAL(20, 3);

UPDATE Online_retailclean
SET TotalPrice = CAST(UnitPrice AS DECIMAL(20, 3)) * CAST(Quantity AS DECIMAL(20, 3));

-- Add OrderStatus
ALTER TABLE Online_retailclean 
ADD OrderStatus VARCHAR(30);

UPDATE Online_retailclean
SET OrderStatus = CASE
    WHEN Quantity < 0 THEN 'Returned'
    WHEN LEFT(InvoiceNo, 1) = 'C' THEN 'Cancelled'
    ELSE 'Delivered'
END;

-- Add TransactionType
ALTER TABLE Online_retailclean
ADD TransactionType VARCHAR(50);

UPDATE Online_retailclean
SET TransactionType = CASE
    WHEN StockCode IN ('DOT', 'BANK CHARGES', 'S', 'M', 'B') THEN 'Other'
    WHEN Quantity < 0 THEN 'Return'
    WHEN UnitPrice < 0 THEN 'Refund'
    ELSE 'Sale'
END;

--------------------------------------------------
-- STEP 5: Create star schema tables
--------------------------------------------------

-- Fact table
SELECT InvoiceNo, InvoiceDate, StockCode, Quantity, UnitPrice, CustomerID, Country, TotalPrice, OrderStatus
INTO Fact_Sales
FROM Online_retailclean
WHERE Quantity > 0;

-- Dimension tables
SELECT DISTINCT CustomerID, Country
INTO Dim_Customer
FROM Online_retailclean;

SELECT DISTINCT StockCode, Description
INTO Dim_Product
FROM Online_retailclean;

SELECT DISTINCT 
  CAST(InvoiceDate AS DATE) AS Date,
  DATENAME(MONTH, InvoiceDate) AS Month,
  YEAR(InvoiceDate) AS Year,
  DATENAME(WEEKDAY, InvoiceDate) AS DayName
INTO Dim_Date
FROM Online_retailclean;

--------------------------------------------------
-- STEP 6: Remove duplicate rows in dimension
--------------------------------------------------

-- Dim_Date duplicates
WITH Duplicates AS (
  SELECT *, 
         ROW_NUMBER() OVER(PARTITION BY Date ORDER BY (SELECT NULL)) AS RowNum
  FROM Dim_Date
)
DELETE FROM Duplicates
WHERE RowNum > 1;
