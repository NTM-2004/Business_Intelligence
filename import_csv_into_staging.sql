BULK INSERT stg_reviews
FROM 'D:\College\BI\Project\Business_Intelligence\olist_csv\olist_customers_dataset.csv'-- Nhớ thay bằng đường dẫn thực tế trên máy bạn
WITH (
    FORMAT = 'CSV',          -- Bắt buộc phải có dòng này để kích hoạt tính năng đọc chuẩn CSV
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a', 
    CODEPAGE = '65001',
    TABLOCK
);
