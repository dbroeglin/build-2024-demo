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

# Define product names, categories, and sub-categories
product_names = ["Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape", "Honeydew", "Iced Tea", "Juice",
                 "Kiwi", "Lemon", "Mango", "Nectarine", "Orange", "Papaya", "Quince", "Raspberry", "Strawberry", "Tangerine",
                 "Ugli Fruit", "Vodka", "Watermelon", "Xigua", "Yam", "Zucchini", "Artichoke", "Broccoli", "Carrot", "Daikon"]
main_categories = ["Fruit", "Beverage", "Vegetable", "Dairy", "Meat", "Poultry", "Seafood", "Grain", "Bakery", "Confectionery",
                   "Snack", "Frozen", "Canned", "Dried", "Spice", "Condiment", "Oil", "Sauce", "Alcohol", "Non-Alcoholic"]
sub_categories = ["Fresh", "Canned", "Frozen", "Dried", "Baked", "Fried", "Grilled", "Steamed", "Raw", "Pickled"]


# Generate sample data
for i in range(100):
    product = {
        "id": "product" + str(i),
        "ProductId": "product" + str(i),
        "name": product_names[i % 30],
        "price": (i % 30) * 10,
        "category": {
            "main": main_categories[i % 20],
            "sub": sub_categories[i % 10]
        }
    }

    # Add product to container
    container.upsert_item(body=product)