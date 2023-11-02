CREATE DATABASE e_commerce_ZOMATO;
ALTER DATABASE e_commerce_ZOMATO MODIFY NAME = e_commerce_Z
USE e_commerce_Z;

SELECT * FROM users;
SELECT * FROM goldusers_signup;
SELECT * FROM sales;
SELECT * FROM product;

--Q1. WHAT IS THE TOTAL AMOUNT EACH CUSTOMER SPENT ON ZOMATO
SELECT userid, SUM(p.price) AS Total_Spent FROM product AS p
INNER JOIN sales AS s
ON s.product_id = p.product_id
GROUP BY userid
Order BY Total_Spent DESC;

--Q2. HOW MANY DAYS HAS EACH CUSTOMER VISITED ZOMATO
SELECT userid, COUNT(DISTINCT created_date) AS Zomato_Visit FROM sales
GROUP BY userid;

--Q3. WHAT WAS THE FIRST PRODUCT PURCHASED BY EACH OF THE CUSTOMER
SELECT * FROM (
SELECT RANK() OVER(PARTITION BY userid ORDER BY created_date) AS FIRST_ORDER, userid, product_id, created_date
FROM sales) AS A
WHERE FIRST_ORDER = 1;
--OR
SELECT * FROM product AS P
INNER JOIN (SELECT *, RANK() OVER(PARTITION BY userid ORDER BY created_date) AS FIRST_ORDER FROM sales) AS A
ON A.product_id = P.product_id
WHERE FIRST_ORDER = 1;

--Q4. WHAT IS THE MOST PURCHASED ITEM IN THE MENU AND HOW MANY TIMES IT WAS PURCHASED BY ALL CUSTOMERS
SELECT userid, COUNT(product_id) AS BUYING_COUNT  FROM SALES
WHERE product_id = 
(SELECT product_id 
FROM sales
GROUP BY product_id
ORDER BY COUNT(product_id) DESC
OFFSET 0 ROW FETCH FIRST 1 ROWS ONLY)
GROUP BY userid;

--Q5. WHICH ITEM WAS MOST POPULAR FOR EACH CUSTOMER
SELECT * FROM 
(SELECT *, RANK() OVER(PARTITION BY userid ORDER BY CNT DESC) AS RNK FROM
(SELECT userid, product_id, COUNT(product_id) AS CNT FROM sales
GROUP BY userid, product_id)AS A) AS B
WHERE RNK = 1;

--Q6. WHICH ITEM WAS FIRST PURCHASED BY THE CUSTOMER AFTER THEY BECAME A GOLD MEMBER
SELECT * FROM 
(SELECT A.*, RANK() OVER(PARTITION BY userid ORDER BY created_date) AS RNK FROM 
(SELECT S.userid, S.created_date, S.product_id, G.gold_signup_date
FROM SALES AS S
INNER JOIN goldusers_signup AS G
ON S.userid = G.userid
AND created_date >= gold_signup_date) AS A) AS B
WHERE RNK = 1;

--Q7. WHICH ITEM WAS JUST PURCHASED BEFORE CUSTOMER BECAME A MEMBER
SELECT * FROM 
(SELECT A.*, RANK() OVER(PARTITION BY userid ORDER BY created_date DESC) AS RNK FROM 
(SELECT S.userid, S.created_date, S.product_id, G.gold_signup_date
FROM SALES AS S
INNER JOIN goldusers_signup AS G
ON S.userid = G.userid
AND S.created_date < G.gold_signup_date) AS A) AS B
WHERE RNK = 1;

--Q8. WHAT ARE THE TOTAL ORDERS ORDERED AND TOTAL AMOUN SPENT BY EACH MEMBER BEFORE THEY ACQUIRE MEMBERSHIP
SELECT A.userid, COUNT(A.created_date) AS TOTAL_ORDERS_ORDERED, SUM(A.price) TOTAL_AMOUNT_SPENT FROM
(SELECT S.userid, S.created_date, S.product_id, P.product_name, P.price, G.gold_signup_date
FROM SALES AS S
INNER JOIN goldusers_signup AS G
ON S.userid = G.userid AND S.created_date < G.gold_signup_date
INNER JOIN product AS P
ON S.product_id = P.product_id) AS A
GROUP BY A.userid;

--Q9. CASE: IF BUYING EACH PRODUCT GENERATES CERTAIN POINTS, REDEEM 2 PTS = RS 5
--EXAMPLE: P1 = RS 5 = 1 PT, P2 = RS 10 = 5 PTS (i.e. RS 2 = 1 PT), P3 = RS 5 = 1 PT
--(1) CALCULATE POINTS COLLECTED BY EACH CUSTOMER
SELECT userid, SUM(POINTS_COLLECTED) AS TOTAL_PTS_PER_CUSTOMER FROM
(SELECT *, TOTAL_PRICE / AMOUNT_ALLOTED AS POINTS_COLLECTED  FROM
(SELECT B.*,
CASE 
WHEN B.product_id = 1 then 5
WHEN B.product_id = 2 then 2
WHEN B.product_id = 3 then 5
ELSE 0
END AS AMOUNT_ALLOTED
FROM
(SELECT A.userid, A.product_id, SUM(A.price) AS TOTAL_PRICE FROM
(SELECT S.userid, S.product_id, P.price FROM sales AS S
INNER JOIN product AS P
ON S.product_id = P.product_id) AS A
GROUP BY A.userid, A.product_id) AS B) AS C) AS D
GROUP BY userid;

--(2) FOR WHICH PRODUCT MOST POINT HAS BEEN GIVEN TILL NOW
SELECT product_id, TOTAL_PRICE/AMOUNT_ALLOTED AS POINTS_PER_PRODUCT FROM
(SELECT B.*,
CASE 
WHEN B.product_id = 1 then 5
WHEN B.product_id = 2 then 2
WHEN B.product_id = 3 then 5
ELSE 0
END AS AMOUNT_ALLOTED
FROM
(SELECT A.product_id, SUM(A.price) AS TOTAL_PRICE FROM
(SELECT S.userid, S.product_id, P.price FROM sales AS S
INNER JOIN product AS P
ON S.product_id = P.product_id) AS A
GROUP BY A.product_id) AS B) AS C
ORDER BY POINTS_PER_PRODUCT DESC;

--Q10 IN THE FIRST 1 YEAR AFTER THE CUSTOMER JOINS THE GOLD PROGRAM (INCLUDING JOINING DATE)
--IRRESPECTIVE OF WHAT THE CUSTOMER HAS PURCHASED THEY CAN EARN 5 POINTS FOR EVERY 10 RS.
--WHO EARNED MORE AND WHAT WAS THEIR OVERALL POINTS EARNING IN THEIR FIRST YEAR
SELECT A.userid, A.created_date, A.gold_signup_date, A.product_id, A.product_name, A.price, A.price*0.5 AS TOTAL_PTS_EARNED FROM
(SELECT S.userid, S.created_date, G.gold_signup_date, P.product_id, P.product_name, P.price FROM sales AS S
INNER JOIN goldusers_signup AS G
ON S.userid = G.userid
INNER JOIN product AS P
ON P.product_id = S.product_id
WHERE S.created_date >= G.gold_signup_date AND S.created_date <= DATEADD(YEAR, 1, G.gold_signup_date)) AS A;

--Q11. RANK ALL THE TRANSACTIONS OF CUSTOMERS
SELECT *, RANK() OVER (PARTITION BY userid ORDER BY created_date) AS RANKING FROM sales;

--Q12. RANK ALL THE TRANSACTION EACH MEMBER, FOR EACH GOLD MEMBER AND FOR EVERY NON GOLD MEMBER TRANSACTIONS MARKS AS N/A
SELECT B.*,
CASE 
WHEN RANKING = 0 THEN 'N/A'
ELSE RANKING 
END AS RANKINGS
FROM
(SELECT A.*, 
CAST((CASE
WHEN A.gold_signup_date IS NULL THEN 0 ELSE
RANK() OVER (PARTITION BY userid ORDER BY created_date DESC)
END) AS VARCHAR) AS RANKING 
FROM
(SELECT S.userid, S.created_date, S.product_id, G.gold_signup_date
FROM sales AS S
LEFT JOIN goldusers_signup AS G
ON S.userid = G.userid AND S.created_date >= G.gold_signup_date) AS A) AS B;