create database credit_recovery;

-- Create LOANS table
CREATE TABLE LOANS (
    loan_id INT,
    user_id INT,
    total_amount_disbursed FLOAT,
    disbursement_date DATE
);

-- Insert data into LOANS table
INSERT INTO LOANS (loan_id, user_id, total_amount_disbursed, disbursement_date) VALUES 
    (1, 1, 5000, '2022-09-02'),
    (2, 2, 6000, '2022-09-02'),
    (3, 1, 1000, '2022-10-05'),
    (4, 3, 10000, '2022-09-02');


-- Create PAYMENTS table
CREATE TABLE PAYMENTS (
    payment_id INT,
    loan_id INT,
    amount FLOAT,
    type STRING,
    payment_timestamp TIMESTAMP
);

-- Insert data into PAYMENTS table
INSERT INTO PAYMENTS (payment_id, loan_id, amount, type, payment_timestamp) VALUES 
    (1, 1, 5000, 'disbursement', '2022-10-01 05:01:12'),
    (2, 2, 100, 'repayment', '2022-10-01 05:05:12'),
    (3, 1, 1000, 'repayment', '2022-10-01 05:31:01'),
    (4, 2, 10, 'repayment', '2022-11-01 03:11:01');

    
-- 1. Question: Calculate the Total Loan Portfolio Value and Delinquency Rate
-- Calculate the total loan portfolio value and the delinquency rate, 
-- where the delinquency rate is defined as the percentage of loans with no repayments to the total loan portfolio.

WITH loan_repayment_status AS (
    SELECT 
        l.loan_id,
        l.total_amount_disbursed,
        CASE 
            WHEN SUM(CASE WHEN p.type = 'repayment' THEN p.amount ELSE 0 END) = 0 THEN 1
            ELSE 0
        END AS is_delinquent
    FROM LOANS l
    LEFT JOIN PAYMENTS p ON l.loan_id = p.loan_id
    GROUP BY l.loan_id, l.total_amount_disbursed
)
SELECT 
    SUM(total_amount_disbursed) AS total_portfolio_value,
    ROUND((SUM(is_delinquent) / COUNT(*)) * 100, 2) AS delinquency_rate_percentage
FROM loan_repayment_status;

-- outstanding balance

SELECT 
        l.loan_id,
        total_amount_disbursed as disbursed, 
        sum(CASE when p.type = 'repayment' then amount else 0 end) as repayed,
        ROUND((sum(CASE when p.type = 'repayment' then amount else 0 end)/  sum(total_amount_disbursed)),2) * 100 as repayment_rate_in_percentage,
        ((total_amount_disbursed) - sum(CASE when p.type = 'repayment' then amount else 0 end)) as outstanding_balance
FROM loans l
LEFT JOIN payments p on l.loan_id = p.loan_id
group by l.loan_id, total_amount_disbursed;



-- 2 Due to limited bandwidth, the collection recovery team can only call 1000 users a day, to help the team generate a 
-- priority list for the current date based on the following criteria from the table created in the above question.

     -- 2.1	Pick only the user_id-loan_id combination where latest repayment day is more than 30 days prior to current date
     -- 2.2	Total outstanding balance is more than or equal to 70% of the total amount disbursed
     -- or 
     -- Total outstanding balance is more than or equal to 10000.
     -- Rank the user in descending order of the Total outstanding balance

-- get the sum of repaying loans by loan_id and the number of days since the last payment
WITH payment_summary AS (
    SELECT 
        loan_id,
        COALESCE(SUM(CASE WHEN type = 'repayment' THEN amount ELSE 0 END), 0) AS repayment,  -- Sum of repayment amounts
        DATEDIFF(day, MAX(payment_timestamp), CURRENT_TIMESTAMP) AS last_paid_before_n_days  -- Days since the last payment
    FROM payments
    GROUP BY loan_id
),

loan_details AS (
    SELECT
        l.loan_id,
        l.user_id,
        l.total_amount_disbursed,
        l.total_amount_disbursed - COALESCE(p.repayment, 0) AS total_outstanding_amount,  -- Calculate outstanding balance
        l.disbursement_date,
        p.last_paid_before_n_days
    FROM loans l
    LEFT JOIN payment_summary p ON l.loan_id = p.loan_id
)

SELECT 
    user_id,
    loan_id,
    last_paid_before_n_days,
    total_amount_disbursed,
    total_outstanding_amount,
    RANK() OVER (ORDER BY total_outstanding_amount DESC) AS "Rank"  -- Rank loans by outstanding balance
FROM loan_details
WHERE last_paid_before_n_days >= 30 OR 
      total_outstanding_amount = 10000 OR
      total_outstanding_amount >= 0.7 * total_amount_disbursed;





-- . 3. Write a query to create a table that will have total outstanding balance on each day from disbursement day till 
-- last repayment date of the loan for each user - loan combination. Assume that all the loan tenure is for 60 days only.

     -- 3.1.	Total outstanding balance at each day                                                                        
     -- Definition of Total outstanding balance = total disbursed amount (type=’disbursement’ in PAYMENTS table) - total repaid amount (type=’repayment’ in PAYMENTS table)

     -- 3.2.	Latest repayment date at each day


-- Step 1: Generate a sequence of numbers (1 to 60) to simulate daily intervals
WITH DateSeries AS (
    SELECT SEQ4() + 1 AS n              -- SEQ4() generates numbers starting from 0; adding 1 starts it from 1
    FROM TABLE(GENERATOR(ROWCOUNT => 60))  -- Generate exactly 60 rows to represent days
),

-- Step 2: Get loan details and the latest payment date for each loan
LoanDetails AS (
    SELECT
        l.user_id,                       -- User ID associated with each loan
        l.loan_id,                       -- Loan ID
        l.disbursement_date,             -- Date when the loan was disbursed
        l.total_amount_disbursed,        -- Total amount disbursed for the loan
        MAX(p.payment_timestamp) AS last_payment_date  -- Latest payment timestamp for each loan
    FROM loans l
    LEFT JOIN payments p ON l.loan_id = p.loan_id AND p.type = 'repayment'  -- Join payments table
    GROUP BY l.user_id, l.loan_id, l.disbursement_date, l.total_amount_disbursed  -- Group by loan details
),

-- Step 3: Generate daily records for each loan up to the last payment date or 60 days
DailyBalance AS (
    SELECT
        ld.user_id,                                -- User ID associated with the loan
        ld.loan_id,                                -- Loan ID
        DATEADD(day, ds.n, ld.disbursement_date) AS date,  -- Add each day in DateSeries to disbursement_date
        ld.total_amount_disbursed,                 -- Total disbursed amount for each loan
    FROM LoanDetails ld
    CROSS JOIN DateSeries ds                       -- Cross join to create daily records for each loan
    WHERE DATEADD(day, ds.n, ld.disbursement_date) <= ld.last_payment_date
        OR DATEADD(day, ds.n, ld.disbursement_date) <=
           DATEADD(day, 60, disbursement_date)
),
-- Step 4: Calculate outstanding balance and latest repayment date for each daily balance
BalancesAndRepayments AS (
    SELECT
        db.date,                                     -- Date for which the balance is calculated
        db.user_id,                                  -- User ID
        db.loan_id,                                  -- Loan ID
        db.total_amount_disbursed,                   -- Total amount disbursed for the loan
        db.total_amount_disbursed - COALESCE(SUM(p.amount), 0) AS total_outstanding_amount, -- Outstanding balance
        MAX(p.payment_timestamp) AS latest_repayment_date  -- Latest repayment date up to this balance date
    FROM DailyBalance db
    LEFT JOIN payments p ON db.loan_id = p.loan_id AND DATE(p.payment_timestamp) <= db.date AND p.type = 'repayment'
    GROUP BY db.date, db.user_id, db.loan_id, db.total_amount_disbursed  -- Group by loan details and date
)

-- Step 5: Final output to display outstanding balance and latest repayment date for each loan by date
SELECT 
    b.date,                                       -- Date for each balance entry
    b.user_id,                                    -- User ID
    b.loan_id,                                    -- Loan ID
    b.total_amount_disbursed,                     -- Total amount disbursed for the loan
    COALESCE(b.total_outstanding_amount, b.total_amount_disbursed) AS total_outstanding_amount, -- Outstanding balance
    COALESCE(TO_CHAR(b.latest_repayment_date), 'no payment yet') AS latest_repayment_date -- Latest repayment date or 'no payment yet' if no repayment
FROM BalancesAndRepayments b
ORDER BY b.user_id, b.loan_id, b.date;            -- Sort by user, loan, and date for readability
