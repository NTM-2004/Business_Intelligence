DROP TABLE IF EXISTS Dim_Customer;
GO

SELECT DISTINCT 
    customer_id, 
    customer_unique_id, 
    customer_zip_code_prefix AS zip_code, 
    customer_city AS city, 
    customer_state AS state
INTO Dim_Customer
FROM stg_customers;


DROP TABLE IF EXISTS Dim_Product;
GO

SELECT 
    p.product_id,
    -- Logic: Ưu tiên tên tiếng Anh -> Nếu thiếu lấy tên gốc -> Nếu vẫn thiếu hoặc rỗng, gán là 'Unknown'
    COALESCE(
        NULLIF(t.product_category_name_english, ''), 
        NULLIF(p.product_category_name, ''), 
        'Unknown'
    ) AS category_name,
    CAST(p.product_weight_g AS FLOAT) AS weight_g,
    CAST(p.product_length_cm AS FLOAT) AS length_cm,
    CAST(p.product_height_cm AS FLOAT) AS height_cm,
    CAST(p.product_width_cm AS FLOAT) AS width_cm
INTO Dim_Product
FROM stg_products p
LEFT JOIN stg_category_translation t 
    ON p.product_category_name = t.product_category_name;

select * from Dim_Product

DROP TABLE IF EXISTS Dim_Date;
GO

-- 1. Tạo bảng Dim_Date bằng cách trích xuất dữ liệu từ bảng Orders gốc
-- Sử dụng TRY_CONVERT với mã 103 để đọc đúng định dạng Ngày/Tháng/Năm
SELECT DISTINCT 
    TRY_CONVERT(DATE, NULLIF(order_purchase_timestamp, ''), 103) AS [DateKey],
    YEAR(TRY_CONVERT(DATE, NULLIF(order_purchase_timestamp, ''), 103)) AS [Year],
    MONTH(TRY_CONVERT(DATE, NULLIF(order_purchase_timestamp, ''), 103)) AS [Month],
    -- Lấy tên tháng bằng tiếng Anh để báo cáo chuyên nghiệp hơn
    DATENAME(MONTH, TRY_CONVERT(DATE, NULLIF(order_purchase_timestamp, ''), 103)) AS [MonthName],
    DAY(TRY_CONVERT(DATE, NULLIF(order_purchase_timestamp, ''), 103)) AS [Day],
    DATEPART(QUARTER, TRY_CONVERT(DATE, NULLIF(order_purchase_timestamp, ''), 103)) AS [Quarter],
    -- Lấy thứ trong tuần (Ví dụ: Monday, Tuesday...)
    DATENAME(WEEKDAY, TRY_CONVERT(DATE, NULLIF(order_purchase_timestamp, ''), 103)) AS [DayOfWeek],
    -- Tạo nhãn Tháng/Năm (Ví dụ: 2018-07) để vẽ biểu đồ đường
    FORMAT(TRY_CONVERT(DATE, NULLIF(order_purchase_timestamp, ''), 103), 'yyyy-MM') AS [YearMonth]
INTO Dim_Date
FROM stg_orders
WHERE order_purchase_timestamp IS NOT NULL 
  AND order_purchase_timestamp != ''
  -- Lọc bỏ các dòng lỗi không thể convert để tránh giá trị NULL trong Dim_Date
  AND TRY_CONVERT(DATE, NULLIF(order_purchase_timestamp, ''), 103) IS NOT NULL;

-- 2. Thiết lập khóa chính để tối ưu hóa truy vấn
ALTER TABLE Dim_Date ALTER COLUMN [DateKey] DATE NOT NULL;
ALTER TABLE Dim_Date ADD CONSTRAINT PK_DimDate PRIMARY KEY ([DateKey]);

select * from Dim_Date


DROP TABLE IF EXISTS Fact_Sales;
GO

WITH CTE_Payments AS (
    SELECT 
        order_id, 
        payment_type,
        TRY_CAST(NULLIF(payment_installments, '') AS INT) AS payment_installments,
        ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY TRY_CAST(NULLIF(payment_value, '') AS FLOAT) DESC) as rn
    FROM stg_payments
),
CTE_Reviews AS (
    SELECT 
        order_id, 
        TRY_CAST(NULLIF(review_score, '') AS INT) AS review_score,
        ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY review_answer_timestamp DESC) as rn
    FROM stg_reviews
    WHERE review_score IS NOT NULL AND review_score != ''
)
SELECT 
    i.order_item_id,
    o.order_id,
    o.customer_id,
    i.product_id,
    
    -- Dùng TRY_CONVERT với mã 103 để dịch đúng định dạng DD/MM/YYYY
    TRY_CONVERT(DATE, NULLIF(o.order_purchase_timestamp, ''), 103) AS order_date, 
    
    TRY_CAST(NULLIF(i.price, '') AS FLOAT) AS price,
    TRY_CAST(NULLIF(i.freight_value, '') AS FLOAT) AS freight_value,
    
    p.payment_type AS main_payment_type,
    p.payment_installments,
    r.review_score,
    
    -- Xử lý tương tự cho các cột ngày tháng khác
    TRY_CONVERT(DATETIME2, NULLIF(o.order_delivered_customer_date, ''), 103) AS delivered_date,
    TRY_CONVERT(DATETIME2, NULLIF(o.order_estimated_delivery_date, ''), 103) AS estimated_date
INTO Fact_Sales
FROM stg_orders o
JOIN stg_order_items i 
    ON o.order_id = i.order_id
LEFT JOIN CTE_Payments p 
    ON o.order_id = p.order_id AND p.rn = 1
LEFT JOIN CTE_Reviews r 
    ON o.order_id = r.order_id AND r.rn = 1
WHERE o.order_status = 'delivered' 
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_purchase_timestamp != '';

-- Bước 1: Xóa bỏ các dòng rác không có mã khách hàng (nếu có)
DELETE FROM Dim_Customer WHERE customer_id IS NULL;
GO

-- Bước 2: Ép cột này sang trạng thái BẮT BUỘC có dữ liệu (NOT NULL)
ALTER TABLE Dim_Customer ALTER COLUMN customer_id VARCHAR(50) NOT NULL;
GO

-- Bước 3: Gắn Khóa chính
ALTER TABLE Dim_Customer ADD CONSTRAINT PK_DimCustomer PRIMARY KEY (customer_id);
GO

-- Bước 1: Xóa bỏ các dòng rác không có mã sản phẩm (nếu có)
DELETE FROM Dim_Product WHERE product_id IS NULL;
GO

-- Bước 2: Ép cột này sang trạng thái BẮT BUỘC có dữ liệu (NOT NULL)
ALTER TABLE Dim_Product ALTER COLUMN product_id VARCHAR(50) NOT NULL;
GO

-- Bước 3: Gắn Khóa chính
ALTER TABLE Dim_Product ADD CONSTRAINT PK_DimProduct PRIMARY KEY (product_id);
GO

select * FROM Dim_Customer WHERE customer_id IS NULL;
select * FROM Dim_Product WHERE product_id IS NULL;