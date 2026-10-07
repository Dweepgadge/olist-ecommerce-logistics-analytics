# 📦 Olist Brazilian E-Commerce: Logistics & Sales Performance Analytics
### *End-to-End Analytics Portfolio Project: Advanced SQL (MySQL) + Power BI + DAX*

![MySQL](https://img.shields.io/badge/MySQL-8.0-blue?logo=mysql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-Desktop-yellow?logo=powerbi&logoColor=white)
![DAX](https://img.shields.io/badge/DAX-Measures-orange)
![Python ETL](https://img.shields.io/badge/Python-ETL_Batch-green?logo=python&logoColor=white)

---

## 📌 1. Executive Summary & Business Problem
**Olist** is the largest e-commerce marketplace platform in Brazil connecting small merchants to Brazilian consumers. With over 100,000 orders across 2016–2018, leadership observed growing customer churn, rising 1-star reviews, and delivery complaints.

### Core Business Objectives:
1. **Customer Satisfaction Impact:** Does delivery delay directly drive negative reviews and NPS erosion?
2. **Revenue at Risk:** How much Gross Merchandise Value (GMV) is trapped in late deliveries?
3. **Root Cause Analysis:** Are fulfillment delays caused by **Seller Dispatch SLA breaches** or **Logistics Courier Transit failures**?
4. **Geographical Supply Chain Bottlenecks:** Which Brazilian states suffer the highest transit latency and freight inflation?
5. **Interactive Executive Reporting:** Build an interactive 2-page Power BI dashboard for C-suite and Supply Chain leadership.

---

## 🏗️ 2. Architecture & Relational Schema Design

The dataset consists of 9 relational tables modeled into a normalized 3NF schema in MySQL 8.0, and subsequently transformed into an analytical **Star Schema** in Power BI.

```
                          [customers]
                              │ (customer_id)
                              ▼
[payments] ◄───(order_id)─── [orders] ───(order_id)───► [reviews]
                              │ (order_id)
                              ▼
                        [order_items]
                        │           │
           (product_id) │           │ (seller_id)
                        ▼           ▼
                   [products]   [sellers]
                        │
                        ▼
            [category_translation]
```

### Relational Schema Highlights:
* **Primary & Foreign Key Constraints:** Established relational integrity across orders, line items, reviews, and customers.
* **Indexing Optimization:** Applied B-Tree indexes on `order_purchase_timestamp`, `order_status`, `order_delivered_customer_date`, and foreign keys to ensure sub-second query latency across 100K+ records.
* **ETL Ingestion (`scripts/load_data_to_mysql.py`):** Automated batch ingestion script handling null datetime fields, floating-point `NaN` translations, and geolocation deduplication (aggregated 1M GPS coordinate records to 19K zip-code centroids, reducing storage by 98%).

---

## 🔍 3. Key Business Insights & Analytical SQL Queries

### 💡 Finding 1: Delivery Delay is the Primary Driver of 1-Star Reviews
* **On-Time / Early Deliveries:** Maintain a healthy **~4.3 / 5** average rating with **< 9%** 1-star complaints.
* **Minor Delays (1–3 Days):** Average rating plummets **35%** down to **~2.6**, with 1-star reviews surging past **40%**.
* **Severe Delays (> 7 Days):** Rating crashes to **~1.5**, with over **70%** of customers leaving 1-star reviews.
* *Query:* [`02_business_insights.sql` (Analysis 1)](file:///c:/Users/lenovo/OneDrive/Desktop/project/olist_ecommerce_analysis/sql_scripts/02_business_insights.sql#L11-L30)

### 💰 Finding 2: R$ 1.15M+ GMV (8% of Total Revenue) is at Risk
* Out of **15.84M BRL** total revenue, **1.15M BRL (~8%)** is delivered late.
* Delayed orders incur significantly higher freight costs due to remote geographical dispatch, compounding fulfillment inefficiency.
* *Query:* [`02_business_insights.sql` (Analysis 2 - CTE & Window Function)](file:///c:/Users/lenovo/OneDrive/Desktop/project/olist_ecommerce_analysis/sql_scripts/02_business_insights.sql#L33-L64)

### 🚚 Finding 3: Root Cause — Carrier Transit vs. Seller SLA Breaches
* **On-time fulfillment:** ~85% of orders.
* **Seller SLA breach alone (late courier handover):** Represents ~6% of orders, but average review remains **~3.98** if the courier manages to deliver before the customer promise date.
* **Carrier transit failure:** Causes rating to collapse to **~2.1**, proving that customer perception is governed by the final customer-facing promise date, though seller delays burn critical carrier transit buffer.
* *Query:* [`02_business_insights.sql` (Analysis 3)](file:///c:/Users/lenovo/OneDrive/Desktop/project/olist_ecommerce_analysis/sql_scripts/02_business_insights.sql#L67-L93)

### 🗺️ Finding 4: Northeast States are High-Risk Bottlenecks
* Remote Northeast states—**Alagoas (AL), Maranhão (MA), Sergipe (SE), Piauí (PI)**—experience delay rates exceeding **15%–23%**, with actual transit times taking 22–28 days and freight costs nearly double the national average.
* *Query:* [`02_business_insights.sql` (Analysis 4)](file:///c:/Users/lenovo/OneDrive/Desktop/project/olist_ecommerce_analysis/sql_scripts/02_business_insights.sql#L96-L119)

### ⚙️ Finding 5: Solving the 1-to-Many Granularity Fan-Out Trap
* In e-commerce schemas, an order has $M$ line items and $N$ split payment methods. Joining `order_items` directly with `order_payments` produces $M \times N$ Cartesian rows, duplicating revenue sums.
* **Solution:** Pre-aggregated line items and payment transactions at the `order_id` level using Common Table Expressions (CTEs) before joining, achieving 100% financial accuracy.
* *Query:* [`02_business_insights.sql` (Analysis 5)](file:///c:/Users/lenovo/OneDrive/Desktop/project/olist_ecommerce_analysis/sql_scripts/02_business_insights.sql#L122-L157)

---

## 📊 4. Interactive Power BI Dashboard

The dashboard consists of two interactive, cross-filtering pages designed for executive decision-making:

### Page 1: Executive Sales & Platform Health Overview
* **KPI Metrics:** Total Revenue (`R$ 15.84M`), Total Orders (`99.4K`), On-Time Delivery Rate (`92.6%`), Average Review Score (`4.09 ⭐`), Revenue at Risk (`R$ 1.15M`).
* **Monthly Revenue & Order Volume Trend:** Dual-axis clustered column & line chart revealing seasonal e-commerce growth peaks (Black Friday spikes).
* **Delivery Performance Split:** Interactive Donut chart displaying on-time vs. delayed volume share.
* **Top 10 Product Categories:** Revenue leaderboards highlighting high-volume categories (`bed_bath_table`, `health_beauty`, `sports_leisure`).

### Page 2: Logistics Performance & Delivery Delay Deep-Dive
* **Delay Impact Curve (Hero Visual):** Bar chart tracking rating collapse across delay buckets (On-time: 4.3 ⭐ ➔ Minor delay: 2.6 ⭐ ➔ Severe delay: 1.5 ⭐).
* **State Supply Chain Bottleneck Leaderboard:** Ranked horizontal bar chart identifying high-delay regions (AL, MA, SE, CE).
* **Freight Disparity Analysis:** Visualizing the freight cost premium incurred by delayed orders.
* **Interactive Navigation & Cross-Filtering:** Native page navigation and dynamic context filtering across states and timeframes.

---

## 📐 5. Key DAX Measures

```dax
-- 1. Total Platform Revenue (GMV)
Total Revenue = SUM(olist_order_items_dataset[price]) + SUM(olist_order_items_dataset[freight_value])

-- 2. Total Orders (Distinct Grain)
Total Orders = DISTINCTCOUNT(olist_orders_dataset[order_id])

-- 3. On-Time Delivery Rate %
On-Time Delivery Rate % = 
DIVIDE(
    CALCULATE([Total Orders], olist_orders_dataset[Delivery Status] = "On-Time / Early"),
    CALCULATE([Total Orders], olist_orders_dataset[Delivery Status] IN {"On-Time / Early", "Delayed"}),
    0
)

-- 4. Revenue at Risk (Delayed GMV)
Revenue at Risk = CALCULATE([Total Revenue], olist_orders_dataset[Delivery Status] = "Delayed")

-- 5. Average Review Score
Avg Review Score = AVERAGE(olist_order_reviews_dataset[review_score])

-- 6. State-Specific Delay Rate
State Delay Rate % = DIVIDE([Delayed Orders], [Total Orders], 0)
```

---

## 🎯 6. Strategic Business Recommendations
1. **Dynamic Regional Estimated Delivery Dates (EDDs):** Recalibrate automated delivery promises for Northeast regions (AL, MA, SE) by adding a 4–5 day dynamic buffer to eliminate artificial delays and protect customer expectations.
2. **Seller SLA Enforcement & Deprioritization:** Enforce a 48-hour dispatch SLA. Sellers with chronic late handovers (>15% late dispatch rate) should have their marketplace buy-box rank deprioritized.
3. **Regional Fulfillment Hubs:** Partner with local third-party logistics (3PL) warehousing in Northeast Brazil to eliminate cross-country transit latency from São Paulo.

---

## 📁 Repository Structure
```
olist_ecommerce_analysis/
├── data/                                 # Raw Olist CSV files
├── sql_scripts/
│   ├── 01_schema_setup.sql              # DDL schema, PK/FK, indexes
│   └── 02_business_insights.sql         # Core analytical SQL queries
├── scripts/
│   └── load_data_to_mysql.py            # Optimized Python batch ETL script
├── powerbi/
│   └── olist_ecommerce_dashboard.pbix   # Interactive Power BI report file
├── documentation/
│   └── interview_qa_guide.md            # Complete interview preparation guide
└── README.md                             # Comprehensive project documentation
```

---

## 👤 Author & Contact
* **Analyst Portfolio Project:** E-Commerce Delivery & Sales Performance Analytics
* **Tools Used:** MySQL 8.0, Power BI, DAX, Python, Pandas, Git
