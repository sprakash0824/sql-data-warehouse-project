/*
====================================================================================
Stored Procedure: Load Silver Layer 
====================================================================================
Bronze to Silver 
====================================================================================
Script Purpuse: 
This Stored Procedure proforms the ETL (Extract, Transform and Load) process to
populate the 'silver' schema table from the 'bronze' schema.
====================================================================================
Put Clean data into 'silver tables' from bronze tables
====================================================================================
First Truncates all Silver tables then load data from bronze tables
=====================================================================================
It's become easy I put all things in stored procedure that it execute easly
====================================================================================
This is syntax for Execute
EXEC Silver.load_silver;
====================================================================================
*/


CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	PRINT '==============================================';
	PRINT ' Loading Silver Layer';
	PRINT '==============================================';
	
	PRINT '==============================================';
	PRINT 'Loading CRM Table';
	PRINT '==============================================';

	PRINT '=== Truncating table: silver.crm_cust_info';
	TRUNCATE TABLE silver.crm_cust_info
	PRINT '== Inserting data into: silver.crm_cust_info';

	INSERT INTO silver.crm_cust_info
	(
		cst_id,
		cst_key,
		cst_firstname,
		cst_lastname,
		cst_marital_status,
		cst_gendr,
		cst_create_date

	)
	SELECT
	cst_id,
	cst_key,
	TRIM(cst_firstname) AS cst_firstname,				  --Remove Unwanted Spaces
	TRIM(cst_lastname) AS cst_lastname,					 --Remove Unwanted Spaces
	CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'					--Remove Short Name Give Full Name
		WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'				   	 --Remove Short Name Give Full Name
		ELSE 'n/a'
	END cst_marital_status,
	CASE WHEN UPPER(TRIM(cst_gendr)) = 'F' THEN 'Female'		   --Remove Short Name Give Full Name
		WHEN UPPER(TRIM(cst_gendr)) = 'M' THEN 'Male'		   	   --Remove Short Name Give Full Name
		ELSE 'n/a'
	END cst_gender,
	cst_create_date
	FROM(
		SELECT
		*,
		ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) flag_last		--Solv Some Date Issue
		FROM bronze.crm_cust_info
		WHERE cst_id IS NOT NULL
	)t
	WHERE flag_last = 1

	--Insert Another One [ silver.crm_prod_info ]---------------------------------------------------------------------------------------

	PRINT '==============================================';
	PRINT ' Loading Silver Layer';
	PRINT '==============================================';
	
	PRINT '==============================================';
	PRINT 'Loading CRM Table';
	PRINT '==============================================';

	PRINT '=== Truncating table: silver.crm_prod_info';
	TRUNCATE TABLE silver.crm_prod_info
	PRINT '== Inserting data into: silver.crm_prod_info';

	INSERT INTO silver.crm_prod_info(
		prd_id,
		cat_id,
		prd_key,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt
	)

	SELECT
		prd_id,
		REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS cat_id,		--Remove '-', and Give  '_' and Extract Cat_id Like 'AC_BC'.
		SUBSTRING(prd_key,7,LEN(prd_key)) AS prd_key,			--Extract prd_key Only From prd_key Like 'BC-M005'.
		prd_nm,
		ISNULL(prd_cost,0) AS prd_cost,				--Replace NULL with 0.
	
		CASE UPPER(TRIM(prd_line))				--Replace Short With Full Name.
			WHEN 'M' THEN 'Mountain'
			WHEN 'R' THEN 'Road'				
			WHEN 'S' THEN 'Other Sales'
			WHEN 'T' THEN 'Touring'
			ELSE 'n/a'
		END AS prd_line,
		CAST(prd_start_dt AS date)AS prd_start_dt,		-- Change Data Type.
		CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS DATE) AS prd_end_dt --Change Wronge Date start_dt > End_dt.
	FROM bronze.crm_prod_info

	--Insert Another One [ silver.crm_sales_details ]-----------------------------------------------------------------------------------

	PRINT '==============================================';
	PRINT ' Loading Silver Layer';
	PRINT '==============================================';
	
	PRINT '==============================================';
	PRINT 'Loading CRM Table';
	PRINT '==============================================';

	PRINT '=== Truncating table: silver.crm_sales_details';
	TRUNCATE TABLE silver.crm_sales_details
	PRINT '== Inserting data into: silver.crm_sales_details';

	INSERT INTO silver.crm_sales_details(

		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price
	)
	SELECT
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL	--Change Data Type 'INT' To 'VARCHAR' and 'VARCHAR' To 'DATE'.
			ELSE CAST(CAST(sls_order_dt AS VARCHAR)AS DATE)	
		END AS sls_order_dt,

		CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL	--Change Data Type 'INT' To 'VARCHAR' and 'VARCHAR' To 'DATE'.
			ELSE CAST(CAST(sls_ship_dt AS VARCHAR)AS DATE)
		END AS sls_ship_dt,
	
		CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL		--Change Data Type 'INT' To 'VARCHAR' and 'VARCHAR' To 'DATE'.
			ELSE CAST(CAST(sls_due_dt AS VARCHAR)AS DATE)
		END AS sls_due_dt,
	
		CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
			THEN sls_quantity * ABS(sls_price)
			ELSE sls_sales				--  Currect Number According To Price, Quantity and Sales.																								
		END AS sls_sales,

		sls_quantity,
	
		CASE WHEN sls_price IS NULL OR sls_quantity <= 0		--  Currect Number According To Price, Quantity and Sales.
			THEN ABS(sls_sales) / NULLIF(sls_quantity,0)
			ELSE ABS(sls_price)
		END sls_price

	FROM bronze.crm_sales_details

	--Insert Another One [ silver.erp_cust_az12 ] ====================================================================================

	PRINT '==============================================';
	PRINT ' Loading Silver Layer';
	PRINT '==============================================';
	
	PRINT '==============================================';
	PRINT 'Loading ERP Table';
	PRINT '==============================================';

	PRINT '=== Truncating table: silver.erp_cust_az12';
	TRUNCATE TABLE silver.erp_cust_az12
	PRINT '== Inserting data into: silver.erp_cust_az12';

	INSERT INTO silver.erp_cust_az12(
		cid,
		b_date,
		gender
	)
	SELECT
	CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))		--Remove String Like 'NAS'.
		ELSE cid
	END AS cid,

	CASE WHEN b_date > GETDATE() THEN NULL		--Check Some Date Quality.
		ELSE b_date
	END b_date,

	CASE WHEN UPPER(TRIM(gender)) IN ('F', 'FEMALE') THEN 'Female'  --Give The Full Name.
		 WHEN UPPER(TRIM(gender)) IN ('M', 'MALE') THEN 'Male'
		ELSE 'n/a'
	END AS gender

	FROM bronze.erp_cust_az12

	--Insert Another One [ silver.erp_loc_a101 ] ===================================================================================

	PRINT '==============================================';
	PRINT ' Loading Silver Layer';
	PRINT '==============================================';
	
	PRINT '==============================================';
	PRINT 'Loading ERP Table';
	PRINT '==============================================';

	PRINT '=== Truncating table: silver.erp_loc_a101';
	TRUNCATE TABLE silver.erp_loc_a101
	PRINT '== Inserting data into: silver.erp_loc_a101';

	INSERT INTO silver.erp_loc_a101
	(
		cid,
		cntry
	)
	SELECT
	REPLACE(cid,'-','') AS cid,					--Replace '-' and Put '' Nothing.
	CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'		 --Give Full Name 					
		WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
		WHEN TRIM(cntry) IN ('US','USA') THEN 'United State'
		ELSE TRIM(cntry)
	END AS cntry
	FROM bronze.erp_loc_a101;

	--Insert Another One [ silver.erp_px_cat_g1v2 ] =================================================================================

	PRINT '==============================================';
	PRINT ' Loading Silver Layer';
	PRINT '==============================================';
	
	PRINT '==============================================';
	PRINT 'Loading ERP Table';
	PRINT '==============================================';

	PRINT '=== Truncating table: silver.erp_px_cat_g1v2';
	TRUNCATE TABLE silver.erp_px_cat_g1v2
	PRINT '== Inserting data into: silver.erp_px_cat_g1v2';
	
	
	INSERT INTO silver.erp_px_cat_g1v2		--This Table Has No Data Quality Issue
	(
		id,
		cat,
		subcat,
		maintenance
	)
	SELECT
		id,
		cat,
		subcat,
		maintenance
	FROM bronze.erp_px_cat_g1v2;

	PRINT '====================================================';
	PRINT 'Stop Inserting Whole Data has inserted';
	PRINT '====================================================';
	PRINT 'Procedure has been complete';
END

--create procedure
