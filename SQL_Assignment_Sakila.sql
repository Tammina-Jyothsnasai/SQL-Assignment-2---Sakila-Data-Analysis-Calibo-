-- ============================================================
-- SQL ASSIGNMENT 2 - SAKILA DATA ANALYSIS
-- CINEVAULT RENTALS
-- Database: Sakila
-- Author: T. Jyothsna Sai
-- ============================================================

USE sakila;

-- ============================================================
-- SECTION A: SCHEMA DESIGN & DDL
-- Q1. New Franchise Rollout
-- ============================================================

-- Q1(a) Create performance table
DROP TABLE IF EXISTS cv_employee_perf;

CREATE TABLE cv_employee_perf (
    perf_id INT PRIMARY KEY AUTO_INCREMENT,
    staff_id INT,
    review_month DATE,
    films_processed INT,
    rating DECIMAL(3,1),
    remarks VARCHAR(255)
);

-- Verify table structure
DESC cv_employee_perf;

-- Q1(b) Add FOREIGN KEY
ALTER TABLE cv_employee_perf
ADD CONSTRAINT fk_cv_employee_perf_staff
FOREIGN KEY (staff_id)
REFERENCES staff(staff_id);

-- Q1(c) Make rating NOT NULL with default 3.0
ALTER TABLE cv_employee_perf
MODIFY rating DECIMAL(3,1) NOT NULL DEFAULT 3.0;

-- Q1(d) Rename remarks to notes and change type to TEXT
ALTER TABLE cv_employee_perf
CHANGE remarks notes TEXT;

-- Verify final structure
DESC cv_employee_perf;


-- ============================================================
-- Q2. Data Type Conversion Issue
-- ============================================================

-- Q2(a) Widen rental_rate
ALTER TABLE film
MODIFY rental_rate DECIMAL(6,2);

-- Verify
DESC film;

-- Q2(b) Convert payment_date from DATETIME to DATE for display
SELECT
    payment_id,
    payment_date,
    CAST(payment_date AS DATE) AS date_only
FROM payment
ORDER BY payment_id
LIMIT 20;


-- ============================================================
-- Q3. Decommissioning & Cleanup
-- ============================================================

-- Q3(a) Remove all rows but keep the table
-- NOTE: Run this only when the performance data is no longer needed.
TRUNCATE TABLE cv_employee_perf;

-- Verification
SELECT * FROM cv_employee_perf;

-- Q3(b) Permanently remove the table
-- NOTE: After DROP, Q7 queries using this table require Q1 to be
-- executed again to recreate the table.
DROP TABLE cv_employee_perf;

-- Q3(c) Explanation:
-- TRUNCATE removes all rows but keeps the table structure.
-- DROP removes both the table data and its structure.
-- DELETE is useful when specific rows must be removed using WHERE.


-- ============================================================
-- Q4. Normalization Check
-- ============================================================

-- Concept:
-- Repeating customer/film details in every rental row creates
-- redundancy and can cause update, insertion, and deletion anomalies.
--
-- Sakila avoids this by separating data into related tables:
-- customer(customer_id)
-- film(film_id)
-- inventory(inventory_id, film_id)
-- rental(customer_id, inventory_id)
--
-- The tables are connected using primary and foreign keys.


-- ============================================================
-- SECTION B: DATA MANIPULATION
-- ============================================================

-- Q5. Onboarding New Staff
INSERT INTO staff
(first_name, last_name, address_id, email, store_id, active, username, password)
VALUES
('ANANYA', 'RAO', 1, 'ananya@cinevault.com', 1, 1, 'ananya', 'ananya123');

-- Verify
SELECT *
FROM staff
ORDER BY staff_id DESC
LIMIT 1;


-- ============================================================
-- Q6. Price Correction - Bulk Update
-- ============================================================

-- Q6(a) Increase PG film rental rates by 15%
UPDATE film
SET rental_rate = ROUND(rental_rate * 1.15, 2)
WHERE rating = 'PG';

-- Q6(b) Cap replacement_cost at 25.00
SET SQL_SAFE_UPDATES = 0;

UPDATE film
SET replacement_cost = 25.00
WHERE replacement_cost > 25.00;

SET SQL_SAFE_UPDATES = 1;


-- ============================================================
-- Q7. Data Cleanup - Conditional Delete
-- ============================================================

SET SQL_SAFE_UPDATES = 0;

DELETE FROM cv_employee_perf
WHERE films_processed = 0
  AND rating < 2.0;

SET SQL_SAFE_UPDATES = 1;

-- Verify deleted rows
SELECT *
FROM cv_employee_perf
WHERE films_processed = 0
  AND rating < 2.0;

-- Production safeguard:
-- Before DELETE without WHERE, take a backup and first run
-- a SELECT with the same condition. Prefer testing in a
-- transaction/staging environment.


-- ============================================================
-- SECTION C: BUSINESS FILTERING & OPERATORS
-- ============================================================

-- Q8. Marketing Segment 1 - Multi-condition Filter
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    a.district
FROM customer AS c
JOIN address AS a
    ON c.address_id = a.address_id
WHERE c.active = 1
  AND a.district IN ('California', 'Texas')
  AND c.customer_id BETWEEN 1 AND 200;


-- Q9(a) Emails containing sakilacustomer.org
SELECT
    customer_id,
    first_name,
    last_name,
    email
FROM customer
WHERE email LIKE '%sakilacustomer.org%';


-- Q9(b) Films whose description does not contain 'Amazing'
SELECT
    film_id,
    title,
    description
FROM film
WHERE description NOT LIKE '%Amazing%'
ORDER BY film_id;


-- Q9(c) Rentals that have not been returned
SELECT
    rental_id,
    rental_date,
    inventory_id,
    customer_id,
    staff_id,
    return_date
FROM rental
WHERE return_date IS NULL;


-- Q10. Operator Combination Challenge
SELECT
    f.title,
    c.name AS category,
    f.rental_rate,
    f.length
FROM film AS f
JOIN film_category AS fc
    ON f.film_id = fc.film_id
JOIN category AS c
    ON fc.category_id = c.category_id
WHERE c.name NOT IN ('Children', 'Music', 'Travel')
  AND f.rental_rate > 2.99
  AND f.length NOT BETWEEN 60 AND 90;


-- ============================================================
-- SECTION D: RELATIONSHIP ANALYSIS - ALL JOINS
-- ============================================================

-- Q11. INNER JOIN - Film, Category and Language
SELECT
    f.title AS film_title,
    c.name AS category_name,
    l.name AS language_name
FROM film AS f
INNER JOIN film_category AS fc
    ON f.film_id = fc.film_id
INNER JOIN category AS c
    ON fc.category_id = c.category_id
INNER JOIN language AS l
    ON f.language_id = l.language_id
ORDER BY f.title;


-- Q12(a). LEFT JOIN - Every customer with rental count
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(r.rental_id) AS rental_count
FROM customer AS c
LEFT JOIN rental AS r
    ON c.customer_id = r.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name;


-- Q12(b). RIGHT JOIN - Same result
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(r.rental_id) AS rental_count
FROM rental AS r
RIGHT JOIN customer AS c
    ON r.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name;


-- Q13. FULL OUTER JOIN Simulation
-- MySQL does not directly support FULL OUTER JOIN.
-- LEFT JOIN + RIGHT JOIN are combined using UNION.
SELECT
    a.actor_id,
    CONCAT(a.first_name, ' ', a.last_name) AS actor_name,
    f.film_id,
    f.title
FROM actor AS a
LEFT JOIN film_actor AS fa
    ON a.actor_id = fa.actor_id
LEFT JOIN film AS f
    ON fa.film_id = f.film_id

UNION

SELECT
    a.actor_id,
    CONCAT(a.first_name, ' ', a.last_name) AS actor_name,
    f.film_id,
    f.title
FROM actor AS a
RIGHT JOIN film_actor AS fa
    ON a.actor_id = fa.actor_id
RIGHT JOIN film AS f
    ON fa.film_id = f.film_id;


-- Q14. SELF JOIN - Staff members working in the same store
SELECT
    s1.staff_id AS staff_1_id,
    s1.first_name AS staff_1_first_name,
    s1.last_name AS staff_1_last_name,
    s2.staff_id AS staff_2_id,
    s2.first_name AS staff_2_first_name,
    s2.last_name AS staff_2_last_name,
    s1.store_id
FROM staff AS s1
INNER JOIN staff AS s2
    ON s1.store_id = s2.store_id
   AND s1.staff_id < s2.staff_id
ORDER BY
    s1.store_id,
    s1.staff_id,
    s2.staff_id;


-- Q15. CROSS JOIN - Every store/category combination
SELECT
    s.store_id,
    c.category_id,
    c.name AS category_name
FROM store AS s
CROSS JOIN category AS c
ORDER BY
    s.store_id,
    c.category_id;


-- ============================================================
-- SECTION E: AGGREGATION, GROUPING & OUTPUT-BASED QUESTIONS
-- ============================================================

-- Q16(a). Total revenue per staff member
SELECT
    staff_id,
    SUM(amount) AS total_revenue
FROM payment
GROUP BY staff_id;


-- Q16(b). Staff whose total revenue exceeds 15000
SELECT
    staff_id,
    SUM(amount) AS total_revenue
FROM payment
GROUP BY staff_id
HAVING SUM(amount) > 15000;


-- Q16(c). Overall company revenue and highest individual payment
SELECT
    SUM(amount) AS total_company_revenue,
    MAX(amount) AS highest_individual_payment
FROM payment;


-- Q17. Categories with more than 60 films
SELECT
    c.name AS category_name,
    COUNT(f.film_id) AS total_films,
    ROUND(AVG(f.rental_rate), 2) AS avg_rental_rate
FROM category AS c
INNER JOIN film_category AS fc
    ON c.category_id = fc.category_id
INNER JOIN film AS f
    ON fc.film_id = f.film_id
GROUP BY
    c.category_id,
    c.name
HAVING COUNT(f.film_id) > 60
ORDER BY total_films DESC;


-- Q18. Rank customers by total spending
SELECT
    c.customer_id,
    c.first_name,
    SUM(p.amount) AS total_spent,
    DENSE_RANK() OVER (
        ORDER BY SUM(p.amount) DESC
    ) AS spend_rank
FROM customer AS c
INNER JOIN payment AS p
    ON c.customer_id = p.customer_id
GROUP BY
    c.customer_id,
    c.first_name
ORDER BY spend_rank;


-- ============================================================
-- SECTION F: ADVANCED ANALYTICS
-- SUBQUERIES & WINDOW FUNCTIONS
-- ============================================================

-- Q19(a). Films whose rental rate is above their category average
SELECT
    f.film_id,
    f.title,
    f.rental_rate,
    fc.category_id
FROM film AS f
INNER JOIN film_category AS fc
    ON f.film_id = fc.film_id
WHERE f.rental_rate > (
    SELECT AVG(f2.rental_rate)
    FROM film AS f2
    INNER JOIN film_category AS fc2
        ON f2.film_id = fc2.film_id
    WHERE fc2.category_id = fc.category_id
);


-- Q19(b). Customers who have never made a payment
SELECT
    c.customer_id,
    c.first_name,
    c.last_name
FROM customer AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM payment AS p
    WHERE p.customer_id = c.customer_id
);

-- Q19(c) Concept:
-- IN may need to compare against a large result set.
-- EXISTS checks whether a matching row exists and can stop
-- once a match is found, which can be more efficient in
-- appropriate large-data scenarios.


-- Q20(a). Top 3 most-rented films in each store
WITH film_rental_counts AS (
    SELECT
        i.store_id,
        f.film_id,
        f.title,
        COUNT(r.rental_id) AS rental_count
    FROM inventory AS i
    INNER JOIN film AS f
        ON i.film_id = f.film_id
    LEFT JOIN rental AS r
        ON i.inventory_id = r.inventory_id
    GROUP BY
        i.store_id,
        f.film_id,
        f.title
),
ranked_films AS (
    SELECT
        store_id,
        film_id,
        title,
        rental_count,
        ROW_NUMBER() OVER (
            PARTITION BY store_id
            ORDER BY rental_count DESC
        ) AS film_rank
    FROM film_rental_counts
)
SELECT
    store_id,
    film_id,
    title,
    rental_count,
    film_rank
FROM ranked_films
WHERE film_rank <= 3
ORDER BY
    store_id,
    film_rank;


-- Q20(b) Window-function concept:
-- ROW_NUMBER(): gives unique sequential numbers.
-- RANK(): equal values share a rank and later ranks are skipped.
-- DENSE_RANK(): equal values share a rank without gaps.
--
-- Example for equal values:
-- ROW_NUMBER() -> 1, 2, 3
-- RANK()       -> 1, 2, 2, 4
-- DENSE_RANK() -> 1, 2, 2, 3


-- ============================================================
-- BONUS: CTE + JOIN + WINDOW FUNCTION
-- Running total of customer spending
-- ============================================================

WITH rental_history AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        r.rental_id,
        r.rental_date,
        p.payment_date,
        p.amount
    FROM customer AS c
    INNER JOIN rental AS r
        ON c.customer_id = r.customer_id
    INNER JOIN payment AS p
        ON r.rental_id = p.rental_id
)
SELECT
    customer_id,
    first_name,
    last_name,
    rental_id,
    rental_date,
    payment_date,
    amount,
    SUM(amount) OVER (
        PARTITION BY customer_id
        ORDER BY payment_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM rental_history
ORDER BY
    customer_id,
    payment_date;


-- ============================================================
-- END OF SQL ASSIGNMENT 2
-- ============================================================
