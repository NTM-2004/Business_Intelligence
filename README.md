# E-Commerce Business Intelligence

<p align="center">
  <img src="https://img.shields.io/badge/Microsoft_SQL_Server-CC2927?style=for-the-badge&logo=microsoft-sql-server&logoColor=white" alt="SQL Server" />
  <img src="https://img.shields.io/badge/Power_BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black" alt="Power BI" />
  <img src="https://img.shields.io/badge/Data_Warehouse-Star_Schema-0052CC?style=for-the-badge" alt="Star Schema" />
  <img src="https://img.shields.io/badge/Kaggle-20BEFF?style=for-the-badge&logo=Kaggle&logoColor=white" alt="Kaggle" />
</p>

> A complete, end-to-end **Business Intelligence pipeline** built on the Brazilian **Olist e-commerce dataset**. This project covers every stage of a modern BI workflow — from raw data extraction and staging, through star-schema transformation in SQL Server, to an interactive Power BI dashboard.

**Institution:** The Posts and Telecommunications Institute of Technology (PTIT)  
**Course:** Business Intelligence | **Class:** E22HTTT | **Group:** 6  
**Contributors:** Nguyễn Tuấn Minh (B22DCKH077) & Nguyễn Xuân Kiên (B22DCKH062)

---

## 📑 Table of Contents
- [Dashboard Preview](#-dashboard-preview)
- [Project Overview](#-project-overview)
- [Architecture](#-architecture)
- [Dataset](#-dataset)
- [Data Warehouse Schema (Star Schema)](#-data-warehouse-schema-star-schema)
- [ETL Pipeline](#-etl-pipeline)
- [Analytical Measures (DAX)](#-analytical-measures-dax)
- [Key Business Insights](#-key-business-insights)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)

---

## 📈 Dashboard Preview

<p align="center">
  <!-- Hãy upload ảnh dashboard.png của bạn vào thư mục images trên repo -->
  <img src="images/dashboard.png" width="900" alt="Power BI Dashboard">
</p>

---

## 🎯 Project Overview

This project answers key business questions for an e-commerce company using a fully automated data pipeline:

| # | Business Question |
| :--- | :--- |
| 1 | What are the core drivers of sales revenue and how does seasonality impact them? |
| 2 | How do Brazilian consumers prefer to finance their online purchases? |
| 3 | Which product categories generate the highest revenue versus the highest volume? |
| 4 | Where are the logistical bottlenecks causing excessive freight costs and delays? |
| 5 | How exactly does shipping speed impact the final customer satisfaction score? |

---

## ⚙️ Architecture

```text
Raw CSV Files (Olist Dataset)
        │
        ▼
┌──────────────────┐
│  Staging Area    │  ← 2_Bulk_Insert.sql (SQL Server)
│  (Raw Tables)    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  ETL Pipeline    │  ← 4_ETL_Process.sql (T-SQL)
│  Extract         │
│  Transform       │
│  Load            │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────┐
│  SQL Server Data Warehouse       │ 
│  Star Schema                     │
│  • Dim_Customer                  │
│  • Dim_Product                   │
│  • Dim_Date                      │
│  • Fact_Sales       (Fact Table) │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────┐
│  Power BI        │  ← Olist_Dashboard.pbix
│  Dashboard       │
└──────────────────┘
```

---

## 📦 Dataset

The raw data is sourced from the publicly available [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle). It represents nearly 100,000 delivered orders placed between 2016 and 2018.

| File | Description |
| :--- | :--- |
| `olist_orders_dataset.csv` | Order-level data (status, purchase & delivery timestamps) |
| `olist_order_items_dataset.csv` | Line-item data per order (product, price, freight) |
| `olist_customers_dataset.csv` | Customer demographic info (ID, city, state, zip) |
| `olist_products_dataset.csv` | Product metadata (category, weight, dimensions) |
| `olist_order_payments_dataset.csv` | Payment type and installment details |
| `olist_order_reviews_dataset.csv` | Customer review scores (1-5 stars) |
| `product_category_name_translation.csv` | Portuguese → English category name mapping |

> **Note:** All raw CSV files live in the `Data/` directory and are excluded from version control via `.gitignore`.

---

## 🗄️ Data Warehouse Schema (Star Schema)

The data warehouse uses a **Star Schema** design for optimal query performance and analytical simplicity within Power BI.

<p align="center">
  <!-- Hãy upload ảnh erd.png của bạn vào thư mục images trên repo -->
  <img src="images/erd.png" width="700" alt="Data Warehouse Star Schema">
</p>

```text
                        ┌───────────────────┐
                        │     Dim_Date      │
                        │─────────────────  │
                        │ PK: DateKey       │
                        │ Year              │
                        │ Month             │
                        │ DayOfWeek         │
                        └────────┬──────────┘
                                 │
┌──────────────────┐    ┌────────┴──────────────┐    ┌──────────────────┐
│   Dim_Customer   │    │      Fact_Sales       │    │   Dim_Product    │
│────────────────  │    │───────────────────    │    │────────────────  │
│ PK: customer_id  │◄───│ PK: order_item_id     │───►│ PK: product_id   │
│ zip_code         │    │ PK: order_id          │    │ category_name    │
│ city             │    │ FK: customer_id       │    │ weight_g         │
│ state            │    │ FK: product_id        │    │ dimensions       │
└──────────────────┘    │ FK: order_date        │    └──────────────────┘
                        │ price                 │
                        │ freight_value         │
                        │ main_payment_type     │
                        │ payment_installments  │
                        │ review_score          │
                        └───────────────────────┘
```

> `order_id` is kept in the fact table as a **degenerate dimension** — it carries analytical value (distinguishing specific orders) but has no separate dimension table.

---

## 🔄 ETL Pipeline

The pipeline follows a classic **Extract → Transform → Load** pattern orchestrated directly in SQL Server:

### 1. Extract
Reads all relevant CSV files from the local directory into the Staging Area using high-performance `BULK INSERT`.

### 2. Transform

| Dimension / Fact | Transformation Logic |
| :--- | :--- |
| `Dim_Customer` | Deduplicate identities; extract state & city mappings. |
| `Dim_Product` | Left join with English translation dictionary; handle `NULL` values. |
| `Dim_Date` | Parse `order_purchase_timestamp` using `TRY_CONVERT`; extract year, quarter, month, day-of-week. |
| `Fact_Sales` | Utilize `ROW_NUMBER()` Window Functions to deduplicate 1-to-N relationships (prioritize primary payment method and latest review score); enforce referential integrity. |

### 3. Load
Tables are loaded into the core Data Warehouse in dependency order:
1. All three dimension tables first (`Dim_Customer`, `Dim_Product`, `Dim_Date`).
2. `Fact_Sales` last (depends on all dimensions). Primary and Foreign key constraints are applied.

---

## 🧮 Analytical Measures (DAX)

Instead of traditional SQL queries, the analytical logic powering the dashboard is built using **Data Analysis Expressions (DAX)** in Power BI:

```dax
-- 1. Total Revenue
Total Revenue = SUM(Fact_Sales[price])

-- 2. Average Delivery Days
Avg Delivery Days = AVERAGE(DATEDIFF(Fact_Sales[order_date], Fact_Sales[delivered_date], DAY))

-- 3. Freight-to-Price Ratio (Logistics Overhead)
% Freight to Price = DIVIDE(SUM(Fact_Sales[freight_value]), SUM(Fact_Sales[price]), 0)

-- 4. Average Customer Satisfaction
Avg Satisfaction = AVERAGE(Fact_Sales[review_score])
```

---

## 💡 Key Business Insights

### 1. The "10x Sem Juros" Financing Culture
While Credit Cards dominate (78.9% of revenue), there is a massive spike in **10-month installment plans** (over 5,100 orders). Long-term, interest-free financing is a critical conversion driver for Brazilian consumers, especially for premium categories like *watches_gifts*.

### 2. The Northern Logistics Bottleneck
Geography severely impacts profitability. While the economic hub (São Paulo) enjoys fast delivery (8.66 days) and low freight burdens (14.0%), remote Northern states face a logistics crisis. Customers in **Amapá (AP)** and **Roraima (RR)** wait an average of **28.2 days**, with shipping fees consuming over 28% of the product's price.

### 3. Delivery Speed Dictates Satisfaction
Data proves a mathematically perfect inverse correlation between shipping time and review scores:
* **5-Star Rating:** Achieved when delivery averages **10.59 days**.
* **1-Star Rating:** Triggered when wait times stretch to **19.54 days**.
* *Recommendation:* Implement a strict 12-day SLA and automated risk alerts for delayed shipments to protect brand reputation.

---

## 🛠️ Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Data Storage (Raw)** | CSV files (Olist public dataset) |
| **Database Engine** | Microsoft SQL Server |
| **ETL / Transformation** | T-SQL (CTEs, Window Functions, BULK INSERT) |
| **Data Warehouse** | SQL Server (Star Schema) |
| **Visualization / BI** | Microsoft Power BI Desktop |

---

## 📁 Project Structure

```text
E-Commerce-Business-Intelligence/
│
├── Data/                              # Raw CSV source files (not tracked in git)
│   ├── olist_orders_dataset.csv
│   ├── olist_order_items_dataset.csv
│   └── ...
│
├── Images/                            # Dashboard and Schema screenshots
│   ├── dashboard.png                  
│   └── erd.png
│
├── SQL_Scripts/                       # Main ETL scripts
│   ├── 1_Create_Staging.sql           # Creates staging tables
│   ├── 2_Bulk_Insert.sql              # Ingests raw CSVs
│   ├── 3_Create_DW.sql                # Creates Star Schema DDL
│   └── 4_ETL_Process.sql              # Transformations & Loading
│
├── PowerBI/
│   └── Olist_Dashboard.pbix           # Interactive Power BI Dashboard
│
├── Docs/
│   └── BI_Report_Group6.pdf           # Full written project report (PTIT)
│
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

Make sure you have the following installed:
- Microsoft SQL Server & SQL Server Management Studio (SSMS)
- Microsoft Power BI Desktop
- The Olist raw CSV files placed inside the `Data/` directory

### Setup & Run

#### Step 1 — Clone the repository
```bash
git clone [https://github.com/your-username/E-Commerce-Business-Intelligence.git](https://github.com/your-username/E-Commerce-Business-Intelligence.git)
cd E-Commerce-Business-Intelligence
```

#### Step 2 — Download the raw data
Download the Olist dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and place all CSV files into the `Data/` directory.

#### Step 3 — Run the ETL Pipeline
1. Open SSMS and connect to your local SQL Server instance.
2. Execute the scripts in the `SQL_Scripts/` folder sequentially:
   - Run `1_Create_Staging.sql`
   - Run `2_Bulk_Insert.sql` (Ensure file paths match your local machine)
   - Run `3_Create_DW.sql`
   - Run `4_ETL_Process.sql`

#### Step 4 — Open the Dashboard
1. Open `PowerBI/Olist_Dashboard.pbix` in Power BI Desktop.
2. Go to **Home > Transform Data > Data Source Settings** and update the connection to point to your local SQL Server instance.
3. Click **Refresh** to load the clean data from your Data Warehouse.

---

## 📜 License

This project uses the [Olist public dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) which is licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). This project is intended for educational purposes.