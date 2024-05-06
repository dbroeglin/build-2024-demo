-- 
-- Postgres with Azure OpenAI and Vector extensions
-- Initial author: Claire Giordano
-- Recipe data from Kaggle https://www.kaggle.com/datasets/thedevastator/better-recipes-for-a-better-life
--
-- See the end of the file for the setup instructions
--
-- Usage:
--     source .env && psql -v ON_ERROR_STOP=on


--
-- Demo script
--

CREATE TABLE IF NOT EXISTS recipes (
    recipe_id serial,
    title text,
    ingredients text,
    directions text,
    url text
);

-- Chocolate is always a good idea!
SELECT title, left(ingredients, 60) || '...' AS ingredients 
FROM recipes 
WHERE title ILIKE '%chocolate%'
LIMIT 10;

SELECT title, left(ingredients, 60) || '...' AS ingredients 
FROM recipes 
WHERE title ILIKE '%chocolate%' OR ingredients ILIKE '%chocolate%'
LIMIT 10;


-- Let's try to find high protein recipes (aka semantic search)
SELECT title, left(ingredients, 60) || '...' AS ingredients 
FROM recipes 
WHERE title ILIKE '%Give me high protein recipes%'
    OR ingredients ILIKE '%Give me high protein recipes%'
LIMIT 10;

-- Maybe if we add fulltext search to the table (english)
ALTER TABLE recipes ADD COLUMN fulltext tsvector
GENERATED ALWAYS AS (to_tsvector('english', title || ' ' || ingredients || ' ' || directions)) STORED;

-- Query with fulltext search & index
SELECT title, left(ingredients, 60) || '...' AS ingredients
FROM recipes WHERE fulltext @@ phraseto_tsquery('english', 'chocolate')
LIMIT 10;

-- But still no luck with semantic search...
SELECT title, left(ingredients, 60) || '...' AS ingredients
FROM recipes WHERE fulltext @@ phraseto_tsquery('english', 'Give me high protein recipes')
LIMIT 10;

-- Let's try with Azure OpenAI and Vector extensions
CREATE EXTENSION IF NOT EXISTS azure_ai;
CREATE EXTENSION IF NOT EXISTS vector;

SELECT extname, extversion FROM pg_extension
WHERE extname IN ('azure_ai', 'vector');

\set openai_endpoint '\'' `echo $AZURE_OPENAI_ENDPOINT` '\''
\set openai_subscription_key '\'' `echo $AZURE_OPENAI_SUBSCRIPTION_KEY` '\''

SELECT azure_ai.set_setting('azure_openai.endpoint', :openai_endpoint);
SELECT azure_ai.set_setting('azure_openai.subscription_key', :openai_subscription_key);

-- Add an embedding column and generate the embeddings on the fly
-- This can easily exhaust your OpenAI deployment quota
ALTER TABLE recipes 
ADD COLUMN embedding vector(1536) -- Creates a vector column with 1536 dimensions (text-embedding-ada-002)
GENERATED ALWAYS AS (
    azure_openai.create_embeddings(
        'text-embedding-ada-002', 
        title || ' ' || ingredients || ' ' || directions)
) STORED;

-- A more 'measured' way to generate the embeddings-
WITH recipe_ids AS (
    SELECT recipe_id
    FROM recipes
    WHERE embedding is null
    LIMIT 500
)
UPDATE recipes
SET
    embedding = azure_openai.create_embeddings(
        'text-embedding-ada-002', 
        title || ' ' || ingredients || ' ' || directions)
FROM recipe_ids
WHERE recipes.recipe_id = recipe_ids.recipe_id;

-- Create a Hierarchical Navigable Small Worlds (HNWS) index on the embeddings
CREATE INDEX ON recipes USING hnsw (embedding vector_ip_ops);

-- Let's have a look at those embeddings
SELECT title, vector_dims(embedding), left(embedding::text, 25) || '...' AS embedding
FROM recipes 
LIMIT 5;

-- Now we can do semantic search
SELECT title, left(ingredients, 60) || '...' AS ingredients
FROM recipes
ORDER BY
    embedding <#> azure_openai.create_embeddings(
        'text-embedding-ada-002', 
        'Give me high protein recipes'
    )::vector
LIMIT 10;

-- Let's see if we can use other Azure AI models
\set cognitive_endpoint '\'' `echo $AZURE_COGNITIVE_ENDPOINT` '\''
\set cognitive_subscription_key '\'' `echo $AZURE_COGNITIVE_SUBSCRIPTION_KEY` '\''
\set cognitive_region '\'' `echo $AZURE_COGNITIVE_REGION` '\''

SELECT azure_ai.set_setting('azure_cognitive.endpoint', :cognitive_endpoint);
SELECT azure_ai.set_setting('azure_cognitive.subscription_key', :cognitive_subscription_key);
SELECT azure_ai.set_setting('azure_cognitive.region', :cognitive_region); -- required for the translate function

SELECT azure_cognitive.analyze_sentiment(left(review, 5000), 'en'), recipes.recipe_id, title, review
FROM recipes JOIN recipe_reviews ON (recipes.recipe_id = recipe_reviews.recipe_id)
WHERE recipes.title = 'Chocolate Banana Peanut Butter Protein Shake'
LIMIT 10;

-- Let's try to translate the reviews
-- https://learn.microsoft.com/en-us/azure/ai-services/language-service/concepts/language-support
SELECT azure_cognitive.translate(review, 'fr', 'en'), recipes.recipe_id, title, review
FROM recipes JOIN recipe_reviews ON (recipes.recipe_id = recipe_reviews.recipe_id)
WHERE recipes.title = 'Chocolate Banana Peanut Butter Protein Shake';

SELECT azure_cognitive.translate(review, 'de', 'fr'), recipes.recipe_id, title, review
FROM recipes JOIN recipe_reviews ON (recipes.recipe_id = recipe_reviews.recipe_id)
WHERE recipes.title = 'Chocolate Banana Peanut Butter Protein Shake';

select azure_cognitive.recognize_pii_entities(
    'Miss John Doe who lives in The Circle 02, Zürich, 8058 told me that the ' || 
    'Chocolate Banana Peanut Butter Protein Shake was amazing!', 'en');

select azure_cognitive.detect_language('Cette recette était incroyable !');



--
-- Setup instructions
--
DROP TABLE IF EXISTS kaggle_recipes;
DROP TABLE IF EXISTS recipes;

CREATE TABLE kaggle_recipes( 
    rid integer NOT NULL, 
    recipe_name text, 
    prep_time text, 
    cook_time text, 
    total_time text, 
    servings integer, 
    yield text, 
    ingredients text, 
    directions text, 
    rating real, 
    url text, 
    cuisine_path text, 
    nutrition text, 
    timing text, 
    img_src text,
    PRIMARY KEY (rid) 
);

\copy kaggle_recipes FROM recipes.csv DELIMITER ',' CSV HEADER

CREATE TABLE recipes (
    recipe_id serial,
    title text,
    ingredients text,
    directions text,
    url text
);
INSERT INTO recipes 
SELECT rid AS recipe_id, recipe_name AS title, ingredients, directions, url 
FROM kaggle_recipes;

-- Create a recipe_reviews table
CREATE TABLE recipe_reviews (
    review_id serial,
    recipe_id integer,
    rating integer,
    review text
);

INSERT INTO recipe_reviews (recipe_id, rating, review)
SELECT recipe_id, floor(random() * 5) + 1, 
    CASE floor(random() * 5) + 1
        WHEN 1 THEN 'This recipe was terrible!'
        WHEN 2 THEN 'This recipe was not good.'
        WHEN 3 THEN 'This recipe was ok.'
        WHEN 4 THEN 'This recipe was good.'
        WHEN 5 THEN 'This recipe was great!'
    END
FROM recipes;

INSERT INTO recipe_reviews (recipe_id, rating, review)
VALUES
    (593, 5, 'This recipe was amazing!'),
    (593, 5, 'This recipe was fantastic!'),
    (593, 5, 'This recipe was incredible!'),
    (593, 5, 'This recipe was awesome!'),
    (593, 5, 'This recipe was the best!'),
    (593, 5, 'I don''t like chocolate! Am I weird?')
    ;









-- check nutrition facts
SELECT recipes.title, recipes.ingredients, kaggle_recipes.nutrition
FROM recipes JOIN kaggle_recipes ON (recipes.recipe_id = kaggle_recipes.rid)
ORDER BY
    embedding <#> azure_openai.create_embeddings(
        'text-embedding-ada-002', 
        'Give me high protein recipes'
    )::vector
LIMIT 10;
