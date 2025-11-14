-- BAKING RECIPE ANALYSIS
-- Analysis of Better Recipes for a Better Life dataset (Kaggle)


-- DATA QUALITY ASSESSMENT


-- 1. Checking for nulls and empty strings across columns

SELECT COUNT(*) AS null_ratings FROM recipes WHERE rating IS NULL;

-- Result: 0 null ratings

SELECT COUNT(*) AS null_prep_time FROM recipes WHERE prep_time IS NULL OR prep_time = '';

-- Result: 51 null prep times

SELECT COUNT(*) AS null_cook_time FROM recipes WHERE cook_time IS NULL OR cook_time = '';

-- Result: 308 null cook times

SELECT COUNT(*) AS null_total_time FROM recipes WHERE total_time IS NULL OR total_time = '';

-- Result: 45 null total times

SELECT COUNT(*) AS null_servings FROM recipes WHERE servings IS NULL;

-- Result: 0 null servings

SELECT COUNT(*) AS null_ingredients FROM recipes WHERE ingredients IS NULL OR ingredients = '';

-- Result: 0 null ingredients

SELECT COUNT(*) AS null_directions FROM recipes WHERE directions IS NULL OR directions = '';

-- Result: 0 null directions 

SELECT COUNT(*) AS null_cuisine_path FROM recipes WHERE cuisine_path IS NULL OR cuisine_path = '';

-- Result: 0 null cuisine paths

SELECT COUNT(*) AS null_nutrition FROM recipes WHERE nutrition IS NULL OR nutrition = '';

-- Result: 0 null nutritions


-- 2. Checking rating validity

SELECT MIN(rating), MAX(rating) FROM recipes;

-- Result: Min rating 2, Max rating 5 (valid range)


-- 3. Checking for duplicates

SELECT COUNT(DISTINCT recipe_name) AS unique_recipe_names,
       COUNT(*) AS total_recipes,
       COUNT(*) - COUNT(DISTINCT recipe_name) AS recipes_with_duplicate_names
FROM recipes;

-- Result: 961 unique recipe names, 1,090 total recipes, 129 duplicate rows


-- 4. Checking time format

SELECT DISTINCT prep_time FROM recipes WHERE prep_time IS NOT NULL ORDER BY prep_time;

-- Result: 22 unique formats ranging from "1 mins" to "9 hrs"

SELECT DISTINCT cook_time FROM recipes WHERE cook_time IS NOT NULL ORDER BY cook_time;

-- Result: 59 unique formats ranging from "1 mins" to "14 hrs 10 mins"

SELECT DISTINCT total_time FROM recipes WHERE total_time IS NOT NULL ORDER BY total_time;

-- Result: 121 unique formats including day-based times like "1 day 1 hrs" and "19 days 17 hrs 12 mins"


-- INITIAL DATA EXPLORATION
-- Understanding the overall dataset: total recipe count and rating distribution

SELECT COUNT(*) AS total_recipes FROM recipes;

-- Result: 1,090 total recipes in dataset

SELECT AVG(rating) AS avg_rating FROM recipes;

-- Result: Average rating across all recipes is about 4.53

SELECT recipe_name, rating FROM recipes ORDER BY rating DESC LIMIT 10;

-- Result: Top 10 recipes all have perfect 5-star ratings


-- BAKING RECIPE OVERVIEW
-- Understanding the baking recipe landscape before deeper analysis


-- 1. Baking Recipe Count and Percentage
-- Identifying the proportion of baking recipes within the total dataset

SELECT
  COUNT(*) AS baking_recipe_count,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM recipes), 2) AS percentage_of_total
FROM recipes
WHERE cuisine_path LIKE '%/Desserts/%' 
  OR cuisine_path LIKE '%/Bread/%'
  OR cuisine_path LIKE '%Quick Bread Recipes%';

-- Result: 469 baking recipes represent 43.03% of the dataset


-- 2. Rating Comparison: Baking vs Non-Baking Recipes
-- Comparing average ratings between baking and non-baking recipes

SELECT 
  'Baking' AS recipe_type,
  COUNT(*) AS recipe_count,
  ROUND(AVG(rating)::NUMERIC, 2) AS avg_rating
FROM recipes
WHERE cuisine_path LIKE '%/Desserts/%' 
  OR cuisine_path LIKE '%/Bread/%'
  OR cuisine_path LIKE '%Quick Bread Recipes%'

UNION ALL

SELECT 
  'Non-Baking' AS recipe_type,
  COUNT(*) AS recipe_count,
  ROUND(AVG(rating)::NUMERIC, 2) AS avg_rating
FROM recipes
WHERE cuisine_path NOT LIKE '%/Desserts/%' 
  AND cuisine_path NOT LIKE '%/Bread/%'
  AND cuisine_path NOT LIKE '%Quick Bread Recipes%';

-- Result: Baking recipes avg 4.5, Non-baking recipes avg 4.56. Non-baking recipes are rated marginally higher


-- 3. Top 10 Baking Recipes by Rating
-- Identifying the highest-rated baking recipes in the dataset

SELECT 
  recipe_name,
  rating,
  prep_time,
  cook_time,
  cuisine_path
FROM recipes
WHERE cuisine_path LIKE '%/Desserts/%' 
  OR cuisine_path LIKE '%/Bread/%'
  OR cuisine_path LIKE '%Quick Bread Recipes%'
ORDER BY rating DESC, recipe_name ASC
LIMIT 10;

-- Result: Top 10 baking recipes all have 5-star ratings. Mostly cakes and desserts with varying cook times (5 mins to 1 hr 15 mins)


-- DATA TRANSFORMATION
-- Standardizing time formats and ingredient information


-- 1. Normalizing time data
-- Parsing day, hour, minute components from total_time into standardized minutes

CREATE TEMPORARY TABLE recipes_normalized AS
SELECT *,
  COALESCE(NULLIF(REGEXP_REPLACE(total_time, '^.*?(\d+)\s*days?.*$', '\1', 'i'), total_time)::INT, 0) AS days,
  COALESCE(NULLIF(REGEXP_REPLACE(total_time, '^.*?(\d+)\s*hrs?.*$',  '\1', 'i'), total_time)::INT, 0) AS hours,
  COALESCE(NULLIF(REGEXP_REPLACE(total_time, '^.*?(\d+)\s*mins?.*$', '\1', 'i'), total_time)::INT, 0) AS minutes,
  (
    COALESCE(NULLIF(REGEXP_REPLACE(total_time, '^.*?(\d+)\s*days?.*$', '\1', 'i'), total_time)::INT, 0) * 24 * 60 +
    COALESCE(NULLIF(REGEXP_REPLACE(total_time, '^.*?(\d+)\s*hrs?.*$',  '\1', 'i'), total_time)::INT, 0) * 60 +
    COALESCE(NULLIF(REGEXP_REPLACE(total_time, '^.*?(\d+)\s*mins?.*$', '\1', 'i'), total_time)::INT, 0)
  ) AS total_minutes
FROM recipes;


-- Verifying normalization is working correctly

SELECT recipe_name, total_time, days, hours, minutes, total_minutes 
FROM recipes_normalized 
WHERE total_time IS NOT NULL
LIMIT 30;

-- Result: Normalization successful. Correctly parsed days, hours, minutes across all formats


-- 2. Normalizing ingredient data
-- Flagging presence of key baking ingredients with comprehensive variant matching

ALTER TABLE recipes_normalized
  ADD COLUMN has_flour BOOLEAN,
  ADD COLUMN has_sugar BOOLEAN,
  ADD COLUMN has_egg BOOLEAN,
  ADD COLUMN has_butter BOOLEAN,
  ADD COLUMN has_oil BOOLEAN,
  ADD COLUMN has_baking_soda BOOLEAN,
  ADD COLUMN has_baking_powder BOOLEAN,
  ADD COLUMN has_milk BOOLEAN,
  ADD COLUMN has_water BOOLEAN;

UPDATE recipes_normalized SET
  has_flour = ingredients ~* '\m(flour|all-purpose flour|plain flour|whole wheat flour|cake flour|self-rising flour|bread flour)\M',
  has_sugar = ingredients ~* '\m(sugar|white sugar|brown sugar|powdered sugar|icing sugar)\M',
  has_egg = ingredients ~* '\m(eggs?)\M',
  has_butter = ingredients ~* '\m(butter|ghee|margarine)\M',
  has_oil = ingredients ~* '\m(olive oil|vegetable oil|canola oil|avocado oil|sunflower oil|oil)\M',
  has_baking_soda = ingredients ~* '\m(baking soda|sodium bicarbonate|bicarbonate of soda)\M',
  has_baking_powder = ingredients ~* '\m(baking powder)\M',
  has_milk = ingredients ~* '\m(milk|whole milk|skim milk|fat-free milk|buttermilk|almond milk|soy milk|coconut milk)\M',
  has_water = ingredients ~* '\m(water)\M';


-- Verifying ingredient flags are populated for baking recipes

SELECT recipe_name, has_flour, has_sugar, has_egg, has_butter, has_oil, has_baking_soda, has_baking_powder, has_milk, has_water
FROM recipes_normalized 
WHERE (cuisine_path LIKE '%/Desserts/%'
  OR cuisine_path LIKE '%/Bread/%'
  OR cuisine_path LIKE '%Quick Bread Recipes%')
LIMIT 30;

-- Result: Ingredient flags successfully created across baking recipes


-- EXPLORATORY ANALYSIS
-- Investigating relationships between cooking time, ingredients, and baking recipe ratings


-- 1. Time-based Analysis: Total Cooking Time vs Rating
-- Categorizing baking recipes by total cooking time and comparing average ratings

SELECT
  CASE
    WHEN total_minutes < 30 THEN 'Quick (< 30 mins)'
    WHEN total_minutes >= 30 AND total_minutes < 60 THEN 'Medium (30-60 mins)'
    WHEN total_minutes >= 60 AND total_minutes < 180 THEN 'Long (1-3 hrs)'
    WHEN total_minutes >= 180 THEN 'Very Long (3+ hrs)'
  END AS time_category,
  COUNT(*) AS recipe_count,
  ROUND(AVG(rating)::NUMERIC, 2) AS avg_rating,
  MIN(rating) AS min_rating,
  MAX(rating) AS max_rating
FROM recipes_normalized
WHERE (cuisine_path LIKE '%/Desserts/%'
  OR cuisine_path LIKE '%/Bread/%'
  OR cuisine_path LIKE '%Quick Bread Recipes%')
  AND total_minutes IS NOT NULL
GROUP BY time_category
ORDER BY avg_rating DESC;

-- Result: Longer baking recipes rate significantly higher (Very Long 4.61 vs Medium 4.4)

-- Insight: Baking users don't value speed. Recipes requiring patience and effort receive higher ratings,
-- suggesting the audience prioritizes craftsmanship over convenience


-- 2. Ingredient-based Analysis: Ingredient Presence in Recipes
-- Identifying which key ingredients appear more frequently in highly-rated vs poorly-rated baking recipes

WITH rating_segments AS (
  SELECT
    CASE 
  	  WHEN rating >= 4.7 THEN 'Exceptional (4.7+ stars)'
  	  WHEN rating >= 4.4 THEN 'Excellent (4.4-4.6 stars)'
      WHEN rating >= 4 THEN 'Very Good (4-4.3 stars)'
      WHEN rating >= 3.5 THEN 'Good (3.5-3.9 stars)'
      ELSE 'Below Average (< 3.5 stars)'
  END AS rating_tier,
    has_flour, has_sugar, has_egg, has_butter, has_oil, 
    has_baking_soda, has_baking_powder, has_milk, has_water
  FROM recipes_normalized
  WHERE (cuisine_path LIKE '%/Desserts/%'
    OR cuisine_path LIKE '%/Bread/%'
    OR cuisine_path LIKE '%Quick Bread Recipes%')
)

SELECT
  rating_tier,
  COUNT(*) AS recipe_count,
  ROUND(100.0 * SUM(CASE WHEN has_flour THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_flour,
  ROUND(100.0 * SUM(CASE WHEN has_sugar THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_sugar,
  ROUND(100.0 * SUM(CASE WHEN has_egg THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_egg,
  ROUND(100.0 * SUM(CASE WHEN has_butter THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_butter,
  ROUND(100.0 * SUM(CASE WHEN has_oil THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_oil,
  ROUND(100.0 * SUM(CASE WHEN has_baking_soda THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_baking_soda,
  ROUND(100.0 * SUM(CASE WHEN has_baking_powder THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_baking_powder,
  ROUND(100.0 * SUM(CASE WHEN has_milk THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_milk,
  ROUND(100.0 * SUM(CASE WHEN has_water THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_water
FROM rating_segments
GROUP BY rating_tier
ORDER BY rating_tier DESC;

-- Result: Ingredient distribution across rating tiers
-- Very Good (4-4.3): 86 recipes | Good (3.5-3.9): 19 recipes | Exceptional (4.7+): 178 recipes | Excellent (4.4-4.6): 181 recipes | Below Average (< 3.5): 5 recipes

-- Insight:

-- LESS flour = higher ratings. Lower-rated recipes over-flour (80% vs 52.5%)
-- Implication: Excessive flour may create dense, dry baked goods. Precision in flour measurement matters

-- Baking soda presence varies across rating tiers (Exceptional 29.8%, Excellent 21.5%, Below Average 0%)
-- Implication: Strategic leavening agents matter, but the relationship isn't linear

-- Water more prominent in Exceptional recipes (27% vs 10-20%)
-- Implication: Hydration balance is critical. Top recipes get moisture right

-- Sugar + eggs near-universal (87-100% and 40-54%)
-- Implication: These are non-negotiable foundations of successful baking

-- Butter dominates over oil (58-79% vs 0-20%)
-- Implication: Users prefer butter flavor. Oil is rarely used in highly-rated recipes

-- Takeaway: Top-rated recipes are ingredient-restrained, not ingredient-heavy. Success comes from
-- precision and balance, not abundance. Quality over quantity


-- ADVANCED ANALYSIS
-- Identifying winning recipe profiles and conversion performance by segment


-- 1. Top 10% Recipe Profile
-- Identifying the characteristics of highest-performing baking recipes (90th percentile and above)

WITH percentile_calc AS (
  SELECT
    recipe_name,
    rating,
    total_minutes,
    CASE
      WHEN total_minutes < 30 THEN 'Quick (< 30 mins)'
      WHEN total_minutes >= 30 AND total_minutes < 60 THEN 'Medium (30-60 mins)'
      WHEN total_minutes >= 60 AND total_minutes < 180 THEN 'Long (1-3 hrs)'
      WHEN total_minutes >= 180 THEN 'Very Long (3+ hrs)'
    END AS time_category,
    has_flour, has_sugar, has_egg, has_butter, has_oil, has_baking_soda, has_baking_powder, has_milk, has_water,
    PERCENT_RANK() OVER (ORDER BY rating) AS percentile_rank
  FROM recipes_normalized
  WHERE (cuisine_path LIKE '%/Desserts/%'
    OR cuisine_path LIKE '%/Bread/%'
    OR cuisine_path LIKE '%Quick Bread Recipes%')
    AND total_minutes IS NOT NULL
),

top_10_percent AS (
  SELECT * FROM percentile_calc WHERE percentile_rank >= 0.9
)

SELECT
  time_category,
  COUNT(*) AS recipe_count,
  ROUND(AVG(rating)::NUMERIC, 2) AS avg_rating,
  ROUND(100.0 * SUM(CASE WHEN has_flour THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_flour,
  ROUND(100.0 * SUM(CASE WHEN has_sugar THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_sugar,
  ROUND(100.0 * SUM(CASE WHEN has_egg THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_egg,
  ROUND(100.0 * SUM(CASE WHEN has_butter THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_butter,
  ROUND(100.0 * SUM(CASE WHEN has_oil THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_oil,
  ROUND(100.0 * SUM(CASE WHEN has_baking_soda THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_baking_soda,
  ROUND(100.0 * SUM(CASE WHEN has_baking_powder THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_baking_powder,
  ROUND(100.0 * SUM(CASE WHEN has_milk THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_milk,
  ROUND(100.0 * SUM(CASE WHEN has_water THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_water
FROM top_10_percent
GROUP BY time_category
ORDER BY avg_rating DESC;

-- Result: Top 10% recipes show multiple winning profiles across all time categories (4.95-4.98 avg rating)

-- Quick recipes (5): No-bake style, minimal flour (0%), high butter (40%), simple base

-- Very Long recipes (5): Traditional indulgent, 100% sugar, 80% butter, slow fermentation

-- Long recipes (20): Modal winner, 65% flour, 100% sugar, 80% butter, 40% water - balanced moisture

-- Medium recipes (4): Technical baking, 75% flour, 50% baking powder for quick rise, structured approach

-- Insight: Long recipes (1-3 hrs) dominate top 10% (20/34 recipes). This may represent the optimal 
-- ingredient-to-time ratio. Multiple paths to success exist, but traditional balanced recipes win most


-- 2. Conversion Rate Analysis
-- Measuring success rate (4.5+ rating) across baking recipe profiles
-- Define "conversion" = recipe achieves 4.5+ rating


-- 2.1 Conversion by Time Category + Butter Presence

SELECT
  CASE
    WHEN total_minutes < 30 THEN 'Quick (< 30 mins)'
    WHEN total_minutes >= 30 AND total_minutes < 60 THEN 'Medium (30-60 mins)'
    WHEN total_minutes >= 60 AND total_minutes < 180 THEN 'Long (1-3 hrs)'
    WHEN total_minutes >= 180 THEN 'Very Long (3+ hrs)'
  END AS time_category,
  CASE WHEN has_butter THEN 'With Butter' ELSE 'Without Butter' END AS butter_status,
  COUNT(*) AS total_recipes,
  SUM(CASE WHEN rating >= 4.5 THEN 1 ELSE 0 END) AS converted_recipes,
  ROUND(100.0 * SUM(CASE WHEN rating >= 4.5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS conversion_rate,
  ROUND(AVG(rating)::NUMERIC, 2) AS avg_rating
FROM recipes_normalized
WHERE (cuisine_path LIKE '%/Desserts/%'
  OR cuisine_path LIKE '%/Bread/%'
  OR cuisine_path LIKE '%Quick Bread Recipes%')
  AND total_minutes IS NOT NULL
GROUP BY time_category, butter_status
ORDER BY conversion_rate DESC;

-- Result: Conversion success rises sharply with total time, peaking in long and very long recipes. Shorter recipes underperform despite ease

-- Very Long (3+ hrs): Highest conversion (70–86%), strongest ratings, minimal difference between butter use. Effort drives quality

-- Long (1–3 hrs): Consistently high success (~71%), large recipe base, balanced between butter and non-butter

-- Medium (30–60 mins): Noticeable dip (61–64% conversion, avg 4.35–4.48). Likely the weakest performance zone

-- Quick (<30 mins): Lowest success (53–60%), modest ratings (4.49–4.5), convenience trades off satisfaction

-- Insight: Conversion success scales with prep time. Butter presence offers no clear advantage; longer, more involved recipes consistently outperform


-- 2.2 Conversion by Time Category + Flour Presence

SELECT
  CASE
    WHEN total_minutes < 30 THEN 'Quick (< 30 mins)'
    WHEN total_minutes >= 30 AND total_minutes < 60 THEN 'Medium (30-60 mins)'
    WHEN total_minutes >= 60 AND total_minutes < 180 THEN 'Long (1-3 hrs)'
    WHEN total_minutes >= 180 THEN 'Very Long (3+ hrs)'
  END AS time_category,
  CASE WHEN has_flour THEN 'With Flour' ELSE 'Without Flour' END AS flour_status,
  COUNT(*) AS total_recipes,
  SUM(CASE WHEN rating >= 4.5 THEN 1 ELSE 0 END) AS converted_recipes,
  ROUND(100.0 * SUM(CASE WHEN rating >= 4.5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS conversion_rate,
  ROUND(AVG(rating)::NUMERIC, 2) AS avg_rating
FROM recipes_normalized
WHERE (cuisine_path LIKE '%/Desserts/%'
  OR cuisine_path LIKE '%/Bread/%'
  OR cuisine_path LIKE '%Quick Bread Recipes%')
  AND total_minutes IS NOT NULL
GROUP BY time_category, flour_status
ORDER BY conversion_rate DESC;

-- Result: Flour impact may be time-dependent, not universally beneficial

-- Very Long (3+ hrs): Flour helps significantly (87.5% vs 76.7%, ratings 4.71 vs 4.58)

-- Long (1–3 hrs): Flour hurts conversion (67.1% vs 79.1%) despite similar ratings

-- Medium (30–60 mins): Minimal difference (62.7% vs 61.5%), flour slightly reduces rating

-- Quick (< 30 mins): Flour helps (65.5% vs 51.1%)

-- Insight: Flour's benefit is context-dependent. Works best in very long recipes (slow fermentation).
-- Counterproductive in long recipes. No universal flour advantage may exist


-- END OF ANALYSIS
