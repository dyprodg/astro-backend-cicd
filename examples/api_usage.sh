#!/bin/bash

# Search API Usage Examples
# Make sure to set your API endpoint first:
# export API_ENDPOINT="https://your-api-gateway-url.amazonaws.com/prod"

API_ENDPOINT=${API_ENDPOINT:-"https://brlsb82kdc.execute-api.eu-central-1.amazonaws.com/prod"}

echo "🚗 Search API Examples"
echo "====================="
echo "API Endpoint: $API_ENDPOINT"
echo ""

# Function to make pretty JSON output
pretty_json() {
    if command -v jq &> /dev/null; then
        echo "$1" | jq .
    else
        echo "$1"
    fi
}

# Example 1: Get search options
echo "1️⃣ Getting search options (for dropdowns)..."
echo "GET $API_ENDPOINT/search/options"
echo ""
response=$(curl -s "$API_ENDPOINT/search/options")
pretty_json "$response"
echo ""
echo "================================================"
echo ""

# Example 2: Search for BMW cars
echo "2️⃣ Search for BMW cars..."
echo "POST $API_ENDPOINT/search"
echo ""
response=$(curl -s -X POST "$API_ENDPOINT/search" \
    -H "Content-Type: application/json" \
    -d '{"query": "BMW", "limit": 3}')
pretty_json "$response"
echo ""
echo "================================================"
echo ""

# Example 3: Filter by car type (SUVs)
echo "3️⃣ Filter by car type (SUVs)..."
echo ""
response=$(curl -s -X POST "$API_ENDPOINT/search" \
    -H "Content-Type: application/json" \
    -d '{"car_type": "SUV", "limit": 5}')
pretty_json "$response"
echo ""
echo "================================================"
echo ""

# Example 4: Price range filter
echo "4️⃣ Filter by price range (30,000 - 40,000 CHF)..."
echo ""
response=$(curl -s -X POST "$API_ENDPOINT/search" \
    -H "Content-Type: application/json" \
    -d '{"min_price": 30000, "max_price": 40000, "limit": 5}')
pretty_json "$response"
echo ""
echo "================================================"
echo ""

# Example 5: Multiple filters
echo "5️⃣ Multiple filters (Automatic transmission, Diesel, under 50k CHF)..."
echo ""
response=$(curl -s -X POST "$API_ENDPOINT/search" \
    -H "Content-Type: application/json" \
    -d '{
        "transmission": "Automatik",
        "fuel": "Diesel",
        "max_price": 50000,
        "limit": 5
    }')
pretty_json "$response"
echo ""
echo "================================================"
echo ""

# Example 6: Pagination
echo "6️⃣ Pagination example (offset 2, limit 2)..."
echo ""
response=$(curl -s -X POST "$API_ENDPOINT/search" \
    -H "Content-Type: application/json" \
    -d '{
        "limit": 2,
        "offset": 2
    }')
pretty_json "$response"
echo ""
echo "================================================"
echo ""

# Example 7: Power range filter
echo "7️⃣ Filter by power range (200+ HP)..."
echo ""
response=$(curl -s -X POST "$API_ENDPOINT/search" \
    -H "Content-Type: application/json" \
    -d '{
        "min_power": 200,
        "limit": 5
    }')
pretty_json "$response"
echo ""
echo "================================================"
echo ""

# Example 8: Complex search with text query and filters
echo "8️⃣ Complex search (text: 'Automatik', car_type: 'Limousine', max_mileage: 60k)..."
echo ""
response=$(curl -s -X POST "$API_ENDPOINT/search" \
    -H "Content-Type: application/json" \
    -d '{
        "query": "Automatik",
        "car_type": "Limousine",
        "max_mileage": 60000,
        "limit": 5
    }')
pretty_json "$response"
echo ""
echo "================================================"
echo ""

echo "✅ All examples completed!"
echo ""
echo "To use with your own API endpoint:"
echo "export API_ENDPOINT='https://brlsb82kdc.execute-api.eu-central-1.amazonaws.com/prod'"
echo "./examples/api_usage.sh" 