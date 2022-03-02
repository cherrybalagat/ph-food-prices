/* Creating table and copying data from CSV */

CREATE TABLE food_prices_ph(
	date date,
	admin1 varchar(50),
	admin2 varchar(50),
	market varchar(50),
	latitude numeric,
	longitude float,
	category varchar(50),
	commodity varchar(50),
	unit varchar(10),
	priceflag varchar(10),
	pricetype varchar(10),
	currency varchar(5),
	price numeric,
	usdprice numeric
	);

COPY food_prices_ph
FROM 'D:\wfp_food_prices_phl.csv'
DELIMITER ','
CSV header;

/* Changing column names and deleting unnecessary columns */
ALTER TABLE food_prices_ph
RENAME admin1 TO region;

ALTER TABLE food_prices_ph
RENAME admin2 TO province;

ALTER TABLE food_prices_ph
DROP COLUMN longitude,
DROP COLUMN priceflag;

/* Change day in date from 15 to 1 */
UPDATE food_prices_ph
SET date = DATE_TRUNC('month',date);

/* Capitalize first letter of category */
UPDATE food_prices_ph
SET category = UPPER(SUBSTRING(category, 1, 1)) ||
     		           LOWER(SUBSTRING(category, 2, length(category)));	
				
/* Add year column and extract year from date  */
ALTER TABLE food_prices_ph
ADD COLUMN year double precision;

UPDATE food_prices_ph
SET year = EXTRACT (YEAR from date);

/* Delete commodities that have price data for two years only.
(There are no commodities with data for three years which is why '4' is used for COUNT) */
DELETE FROM food_prices_ph
WHERE commodity IN
	(SELECT commodity 
	FROM food_prices_ph 
	GROUP BY commodity, region
HAVING 
	COUNT (DISTINCT year) < 4);

/* Delete commodities with 'skipped' year values */
WITH cte_yrs AS
(SELECT commodity, 
 	year, 
 	ROW_NUMBER() OVER (PARTITION BY commodity ORDER BY year), 
 	(year - ROW_NUMBER() OVER (PARTITION BY commodity ORDER BY year)) as yr_difference
FROM food_prices_ph
GROUP BY commodity, year
ORDER BY commodity);

DELETE FROM food_prices_ph
WHERE commodity IN 
(SELECT commodity FROM
	(SELECT commodity, 
		     year, 
		     yr_difference, 
		     MIN(yr_difference) OVER (PARTITION BY commodity) as min, 
		     MAX(yr_difference) OVER (PARTITION BY commodity) as max  
		     FROM cte_yrs
	GROUP BY commodity, year, yr_difference
	ORDER BY commodity, year) as temp
	WHERE min <> max))

/* Only vegetable commodities will remain after deletions, change category to 'Vegetables' from 'Vegetables and fruits' */
UPDATE food_prices_ph
SET category = 'Vegetables'
WHERE category = 'Vegetables and fruits'
