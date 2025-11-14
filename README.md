## Baking Recipe Analysis: What Makes Recipes Successful?

## Project Overview
This project analyzes 469 baking recipes to uncover what drives high user ratings. By examining cooking time and ingredient presence against user ratings (2-5 scale), the analysis identifies that longer, ingredient-balanced recipes outperform quick alternatives. The finding implies that baking users reward effort and precision over convenience. This counterintuitive insight is relevant to recipe development and content strategy.

## Dataset Description
- **Source:** Kaggle - Better Recipes for a Better Life (https://www.kaggle.com/datasets/thedevastator/better-recipes-for-a-better-life/data)
- **Total Dataset:** 1,090 recipes; **Analyzed:** 469 baking recipes (Desserts, Bread, Quick Bread categories)
- **Key Fields:** recipe_name, rating, prep_time, cook_time, total_time, ingredients, cuisine_path
- **Rating Range:** 2-5 stars
- **Limitations:** 129 duplicate recipe names; 308 null cook times; inconsistent time formats (ranging from "5 mins" to "19 days 17 hrs 12 mins"); ingredient data unstructured (commas separate both ingredients and preparation notes)

## Objectives
1. What characteristics define top-performing (90th percentile) baking recipes?
2. How do cooking time and ingredient presence affect conversion to 4.5+ rating?
3. Is butter presence universally beneficial? What about flour?
4. Which recipe profiles have the highest success rates?

## Methodology
- **Data Quality Assessment:** Validated null values, duplicates, rating ranges, and time format inconsistencies
- **Time Normalization:** Regex parsing (`REGEXP_REPLACE`) to convert inconsistent formats ("1 day 1 hrs 30 mins", "3 hrs") into standardized minutes
- **Ingredient Flagging:** Word-boundary regex (`~*`) to detect 9 key baking ingredients with variant matching (e.g., "all-purpose flour", "self-rising flour")
- **Window Functions:** `PERCENT_RANK() OVER (ORDER BY rating)` to identify top 10% recipes
- **CTEs & Dynamic Segmentation:** Temporary result sets to segment recipes by time category, ingredient presence, and rating tier
- **Conversion Analysis:** Calculated success rates (% achieving 4.5+ rating) by profile segment

## Project Structure
```
├── baking_analysis.sql    # Complete SQL analysis (1 file)
│   ├── Data Quality Assessment
│   ├── Initial Data Exploration
│   ├── Baking Recipe Overview
│   ├── Data Transformation (time normalization, ingredient flags)
│   ├── Exploratory Analysis (time & ingredients vs ratings)
│   └── Advanced Analysis (top 10% profiles, conversion rates)
├── recipes.csv            # Original dataset from Kaggle
└── README.md              # This file
```

## Key Queries & Logic

**Time Normalization (Data Transformation):**
```sql
COALESCE(NULLIF(REGEXP_REPLACE(total_time, '^.*?(\d+)\s*days?.*$', '\1', 'i'), total_time)::INT, 0) * 24 * 60 +
COALESCE(NULLIF(REGEXP_REPLACE(total_time, '^.*?(\d+)\s*hrs?.*$', '\1', 'i'), total_time)::INT, 0) * 60 +
COALESCE(NULLIF(REGEXP_REPLACE(total_time, '^.*?(\d+)\s*mins?.*$', '\1', 'i'), total_time)::INT, 0) AS total_minutes
```
Extracts days, hours, and minutes separately, then converts to standardized minutes for analysis.

**Top 10% Profiling (Advanced Analysis):**
```sql
PERCENT_RANK() OVER (ORDER BY rating) AS percentile_rank
WHERE percentile_rank >= 0.9
```
Identifies the top 10% highest-rated recipes and analyzes their ingredient composition by time category.

**Conversion Rate by Segment (Advanced Analysis):**
```sql
ROUND(100.0 * SUM(CASE WHEN rating >= 4.5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS conversion_rate
GROUP BY time_category, butter_status
```
Measures what percentage of recipes in each profile achieve 4.5+ rating, revealing which profiles convert best.

## Results & Insights

**Key Insight 1: Time Drives Success**  
Users consistently rate longer recipes higher. Very Long recipes achieve 85.7% conversion vs 52.9% for Quick recipes. Baking is seemingly not valued for speed.

**Key Insight 2: Ingredient Balance Trumps Quantity**  
Top-rated recipes use LESS flour (52.5% vs 80% in low-rated recipes). Success comes from precision, not abundance.

**Key Insight 3: Butter Is Not Universal**  
Very Long WITHOUT butter: 85.7% conversion. Very Long WITH butter: 70.6%. Yet in Long recipes, both butter and non-butter versions perform similarly (~71%). 

**Key Insight 4: Context Matters**  
Flour helps in Very Long recipes (87.5% vs 76.7%) but hurts in Long recipes (67.1% vs 79.1%). Ingredient impact appears to be time-dependent.

## How to Run

**Prerequisites:**
- PostgreSQL installed
- DBeaver or similar SQL client
- `recipes.csv` from Kaggle dataset

**Steps:**
1. Create PostgreSQL database; connect via DBeaver
2. Import `recipes.csv`
3. Open `baking_analysis.sql` in DBeaver
4. Execute queries sequentially (or run entire script)
5. Review results and insights in query output
