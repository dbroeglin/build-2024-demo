from azure.cosmos import CosmosClient, PartitionKey, exceptions
import os

url = os.getenv('AZURE_COSMOSDB_URL')
key = os.getenv('AZURE_COSMOSDB_KEY')

# Initialize Cosmos Client
client = CosmosClient(url, credential=key)

# Select database
database_name = 'DemoDatabase'
database = client.get_database_client(database_name)

# Select container
container_name = 'DemoContainer'
container = database.get_container_client(container_name)

# query for products with price less than 100
query = "SELECT * FROM c WHERE c.price < 100"

#query for products whose category is "Fruit" and sub-category is "Caned"
query = "SELECT * FROM c WHERE c.category.main = 'Fruit' AND c.category.sub = 'Fresh'"

items = list(container.query_items(query=query, 
                                   enable_cross_partition_query=True)) 


for item in items:
    print(f"Product Name: {item['name']}, Price: {item['price']}")


# query items to find all categories and their count of products be careful with cross partition queries aggregation functions
query = "SELECT c.category.main, c.category.sub, COUNT(1) as count FROM c GROUP BY c.category.main, c.category.sub"
query = "SELECT c.category, COUNT(c.product) as product_count FROM c GROUP BY c.category"
items = list(container.query_items(query=query,
                                      enable_cross_partition_query=True))

for item in items:
    print(f"Main Category: {item['category']['main']}, Sub Category: {item['category']['sub']}, Count: {item['count']}")
