-- 1. Question: Identify the Most Recent Salary for Each Employee with Their Title
-- For each employee with an existing contract, find the most recent salary and their associated title. If 
-- an employee has multiple titles, show the title at the time of their latest salary

WITH recent_salaries AS (
    SELECT 
        emp_no,
        salary,
        from_date AS last_contract,
        ROW_NUMBER() OVER (PARTITION BY emp_no ORDER BY from_date DESC) AS rn
    FROM salaries
    WHERE to_date > current_date
)
SELECT rs.emp_no, rs.salary, rs.last_contract, t.title
FROM recent_salaries rs
JOIN titles t ON rs.emp_no = t.emp_no 
             --AND rs.last_contract BETWEEN t.from_date AND t.to_date
WHERE rs.rn = 1;


-- 2. Question: List Each Department's Longest-Serving Current Manager
-- Problem: For each department, find the current manager with the longest tenure. 
-- Only include managers who are still actively managing their departments 

SELECT 
dept_name, 
concat(first_name, '', last_name) as manager_name, 
from_date, to_date, 
datediff(year, from_date, case when to_date > current_date then current_date end) as tenure_lenght
FROM employees e
JOIN dept_manager dm on e.emp_no = dm.emp_no
JOIN departments d on d.dept_no = dm.dept_no
WHERE to_date > current_date
ORDER BY tenure_lenght DESC
LIMIT 5;


-- 3. Question: Determine the Average Time Spent in Each Department for Current Employees
-- Problem: Calculate the average time (in years) each employee spends in their department and report the result per department.

SELECT  dept_name,
        e.emp_no, 
        concat(first_name, ' ', last_name) as fullname, 
        AVG(datediff(year, from_date, case when to_date > current_date then current_date else to_date end)) as avg_years
FROM    departments d
JOIN    dept_emp de on d.dept_no = de.dept_no
JOIN    employees e on e.emp_no = de.emp_no
WHERE to_date > current_date
GROUP BY   e.emp_no, d.dept_no,dept_name, fullname
ORDER BY dept_name DESC, avg_years DESC;







    

    
    


