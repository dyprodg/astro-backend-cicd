package main

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/aws/aws-lambda-go/events"
)

func TestParseCarRecord(t *testing.T) {
	tests := []struct {
		name     string
		record   []string
		expected Car
		wantErr  bool
	}{
		{
			name: "Valid BMW record",
			record: []string{
				"1", "BMW 520d xDrive 48V M Sport Steptronic", "42890", "Ab 580.- pro Monat ohne Anzahlung",
				"08.2021", "Limousine", "55000", "Automatik", "Diesel", "Allrad", "190", "140",
				"True", "True", "Ab 1. Inverkehrsetzung, 19.08.2021, 24 Monate oder 100'000 km",
				"Ambientes Licht;Mild-Hybrid;Rückfahrkamera;Sportsitze", "Top gepflegt, M Sport Paket",
				"https://img.example.com/bmw1.jpg;https://img.example.com/bmw2.jpg",
			},
			expected: Car{
				ID:           1,
				Title:        "BMW 520d xDrive 48V M Sport Steptronic",
				PriceCHF:     42890,
				LeasingText:  "Ab 580.- pro Monat ohne Anzahlung",
				FirstReg:     "08.2021",
				CarType:      "Limousine",
				MileageKM:    55000,
				Transmission: "Automatik",
				Fuel:         "Diesel",
				Drive:        "Allrad",
				PowerHP:      190,
				PowerKW:      140,
				MFK:          true,
				Warranty:     true,
				WarrantyText: "Ab 1. Inverkehrsetzung, 19.08.2021, 24 Monate oder 100'000 km",
				Equipment:    []string{"Ambientes Licht", "Mild-Hybrid", "Rückfahrkamera", "Sportsitze"},
				Description:  "Top gepflegt, M Sport Paket",
				ImageURLs:    []string{"https://img.example.com/bmw1.jpg", "https://img.example.com/bmw2.jpg"},
			},
			wantErr: false,
		},
		{
			name: "Invalid ID",
			record: []string{
				"invalid", "BMW 520d", "42890", "Ab 580.-",
				"08.2021", "Limousine", "55000", "Automatik", "Diesel", "Allrad", "190", "140",
				"True", "True", "warranty", "equipment", "description", "images",
			},
			wantErr: true,
		},
		{
			name: "Invalid price",
			record: []string{
				"1", "BMW 520d", "invalid", "Ab 580.-",
				"08.2021", "Limousine", "55000", "Automatik", "Diesel", "Allrad", "190", "140",
				"True", "True", "warranty", "equipment", "description", "images",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := parseCarRecord(tt.record)

			if tt.wantErr && err == nil {
				t.Errorf("Expected error but got none")
				return
			}

			if !tt.wantErr && err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}

			if !tt.wantErr && !carEquals(result, tt.expected) {
				t.Errorf("Expected %+v, got %+v", tt.expected, result)
			}
		})
	}
}

func TestMatchesCriteria(t *testing.T) {
	testCar := Car{
		ID:           1,
		Title:        "BMW 520d xDrive",
		PriceCHF:     42890,
		CarType:      "Limousine",
		Transmission: "Automatik",
		Fuel:         "Diesel",
		Drive:        "Allrad",
		MileageKM:    55000,
		PowerHP:      190,
		Description:  "Top gepflegt, M Sport Paket",
	}

	tests := []struct {
		name     string
		car      Car
		req      SearchRequest
		expected bool
	}{
		{
			name:     "No filters - should match",
			car:      testCar,
			req:      SearchRequest{},
			expected: true,
		},
		{
			name: "Text query matches title",
			car:  testCar,
			req: SearchRequest{
				Query: "BMW",
			},
			expected: true,
		},
		{
			name: "Text query matches description",
			car:  testCar,
			req: SearchRequest{
				Query: "gepflegt",
			},
			expected: true,
		},
		{
			name: "Text query doesn't match",
			car:  testCar,
			req: SearchRequest{
				Query: "Audi",
			},
			expected: false,
		},
		{
			name: "Car type filter matches",
			car:  testCar,
			req: SearchRequest{
				CarType: "Limousine",
			},
			expected: true,
		},
		{
			name: "Car type filter doesn't match",
			car:  testCar,
			req: SearchRequest{
				CarType: "SUV",
			},
			expected: false,
		},
		{
			name: "Price range - within range",
			car:  testCar,
			req: SearchRequest{
				MinPrice: intPtr(40000),
				MaxPrice: intPtr(50000),
			},
			expected: true,
		},
		{
			name: "Price range - below minimum",
			car:  testCar,
			req: SearchRequest{
				MinPrice: intPtr(50000),
			},
			expected: false,
		},
		{
			name: "Price range - above maximum",
			car:  testCar,
			req: SearchRequest{
				MaxPrice: intPtr(40000),
			},
			expected: false,
		},
		{
			name: "Mileage range - within range",
			car:  testCar,
			req: SearchRequest{
				MinMileage: intPtr(50000),
				MaxMileage: intPtr(60000),
			},
			expected: true,
		},
		{
			name: "Power range - within range",
			car:  testCar,
			req: SearchRequest{
				MinPower: intPtr(180),
				MaxPower: intPtr(200),
			},
			expected: true,
		},
		{
			name: "Multiple filters - all match",
			car:  testCar,
			req: SearchRequest{
				Query:        "BMW",
				CarType:      "Limousine",
				Transmission: "Automatik",
				Fuel:         "Diesel",
				MinPrice:     intPtr(40000),
				MaxPrice:     intPtr(50000),
			},
			expected: true,
		},
		{
			name: "Multiple filters - one doesn't match",
			car:  testCar,
			req: SearchRequest{
				Query:        "BMW",
				CarType:      "SUV", // This doesn't match
				Transmission: "Automatik",
			},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := matchesCriteria(tt.car, tt.req)
			if result != tt.expected {
				t.Errorf("Expected %v, got %v", tt.expected, result)
			}
		})
	}
}

func TestSearchCars(t *testing.T) {
	// Setup test data
	originalCars := cars
	defer func() { cars = originalCars }()

	cars = []Car{
		{
			ID:           1,
			Title:        "BMW 520d",
			PriceCHF:     42890,
			CarType:      "Limousine",
			Transmission: "Automatik",
			Fuel:         "Diesel",
			Drive:        "Allrad",
			MileageKM:    55000,
			PowerHP:      190,
			Description:  "BMW description",
		},
		{
			ID:           2,
			Title:        "Audi A4",
			PriceCHF:     38900,
			CarType:      "Kombi",
			Transmission: "Automatik",
			Fuel:         "Diesel",
			Drive:        "Front",
			MileageKM:    62000,
			PowerHP:      204,
			Description:  "Audi description",
		},
		{
			ID:           3,
			Title:        "Mercedes C200",
			PriceCHF:     39900,
			CarType:      "Limousine",
			Transmission: "Automatik",
			Fuel:         "Benzin",
			Drive:        "Hinterrad",
			MileageKM:    48000,
			PowerHP:      204,
			Description:  "Mercedes description",
		},
	}

	tests := []struct {
		name          string
		req           SearchRequest
		expectedIDs   []int
		expectedTotal int
	}{
		{
			name:          "No filters - return all",
			req:           SearchRequest{Limit: 10},
			expectedIDs:   []int{1, 2, 3},
			expectedTotal: 3,
		},
		{
			name: "Filter by car type",
			req: SearchRequest{
				CarType: "Limousine",
				Limit:   10,
			},
			expectedIDs:   []int{1, 3},
			expectedTotal: 2,
		},
		{
			name: "Filter by fuel",
			req: SearchRequest{
				Fuel:  "Diesel",
				Limit: 10,
			},
			expectedIDs:   []int{1, 2},
			expectedTotal: 2,
		},
		{
			name: "Text search",
			req: SearchRequest{
				Query: "BMW",
				Limit: 10,
			},
			expectedIDs:   []int{1},
			expectedTotal: 1,
		},
		{
			name: "Price range filter",
			req: SearchRequest{
				MinPrice: intPtr(40000),
				Limit:    10,
			},
			expectedIDs:   []int{1},
			expectedTotal: 1,
		},
		{
			name: "Pagination - limit 2",
			req: SearchRequest{
				Limit:  2,
				Offset: 0,
			},
			expectedIDs:   []int{1, 2},
			expectedTotal: 3,
		},
		{
			name: "Pagination - offset 1, limit 2",
			req: SearchRequest{
				Limit:  2,
				Offset: 1,
			},
			expectedIDs:   []int{2, 3},
			expectedTotal: 3,
		},
		{
			name: "No matches",
			req: SearchRequest{
				Query: "NonExistent",
				Limit: 10,
			},
			expectedIDs:   []int{},
			expectedTotal: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := searchCars(tt.req)

			if result.Total != tt.expectedTotal {
				t.Errorf("Expected total %d, got %d", tt.expectedTotal, result.Total)
			}

			if len(result.Cars) != len(tt.expectedIDs) {
				t.Errorf("Expected %d cars, got %d", len(tt.expectedIDs), len(result.Cars))
				return
			}

			for i, expectedID := range tt.expectedIDs {
				if result.Cars[i].ID != expectedID {
					t.Errorf("Expected car ID %d at position %d, got %d", expectedID, i, result.Cars[i].ID)
				}
			}
		})
	}
}

func TestGetSearchOptions(t *testing.T) {
	// Setup test data
	originalCars := cars
	defer func() { cars = originalCars }()

	cars = []Car{
		{CarType: "Limousine", Transmission: "Automatik", Fuel: "Diesel", Drive: "Allrad", PriceCHF: 42890, MileageKM: 55000, PowerHP: 190},
		{CarType: "Kombi", Transmission: "Automatik", Fuel: "Diesel", Drive: "Front", PriceCHF: 38900, MileageKM: 62000, PowerHP: 204},
		{CarType: "SUV", Transmission: "Manuell", Fuel: "Benzin", Drive: "Hinterrad", PriceCHF: 39900, MileageKM: 48000, PowerHP: 204},
	}

	options := getSearchOptions()

	expectedCarTypes := []string{"Limousine", "Kombi", "SUV"}
	if !slicesEqual(options.CarTypes, expectedCarTypes) {
		t.Errorf("Expected car types %v, got %v", expectedCarTypes, options.CarTypes)
	}

	expectedTransmissions := []string{"Automatik", "Manuell"}
	if !slicesEqual(options.Transmissions, expectedTransmissions) {
		t.Errorf("Expected transmissions %v, got %v", expectedTransmissions, options.Transmissions)
	}

	expectedFuels := []string{"Diesel", "Benzin"}
	if !slicesEqual(options.Fuels, expectedFuels) {
		t.Errorf("Expected fuels %v, got %v", expectedFuels, options.Fuels)
	}

	if options.MinPrice != 38900 {
		t.Errorf("Expected min price 38900, got %d", options.MinPrice)
	}

	if options.MaxPrice != 42890 {
		t.Errorf("Expected max price 42890, got %d", options.MaxPrice)
	}
}

func TestHandleRequest(t *testing.T) {
	// Initialize cars data
	if err := loadCarsFromCSV(); err != nil {
		t.Fatalf("Failed to load cars: %v", err)
	}

	tests := []struct {
		name           string
		request        events.APIGatewayProxyRequest
		expectedStatus int
		expectedBody   string
		allowEmptyBody bool
	}{
		{
			name: "OPTIONS request - CORS preflight",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "OPTIONS",
				Resource:   "/search",
			},
			expectedStatus: 200,
			expectedBody:   "",
			allowEmptyBody: true,
		},
		{
			name: "GET search options",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "GET",
				Resource:   "/search/options",
			},
			expectedStatus: 200,
			expectedBody:   "", // Body will be JSON, we'll check it separately
		},
		{
			name: "POST search with valid body",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "POST",
				Resource:   "/search",
				Body:       `{"query": "BMW", "limit": 5}`,
			},
			expectedStatus: 200,
			expectedBody:   "", // Body will be JSON, we'll check it separately
		},
		{
			name: "POST search with invalid JSON",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "POST",
				Resource:   "/search",
				Body:       `{invalid json}`,
			},
			expectedStatus: 400,
			expectedBody:   `{"error": "Invalid JSON body"}`,
		},
		{
			name: "Method not allowed for search options",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "POST",
				Resource:   "/search/options",
			},
			expectedStatus: 405,
			expectedBody:   `{"error": "Method not allowed"}`,
		},
		{
			name: "Method not allowed for search",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "GET",
				Resource:   "/search",
			},
			expectedStatus: 405,
			expectedBody:   `{"error": "Method not allowed"}`,
		},
		{
			name: "Not found",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "GET",
				Resource:   "/unknown",
			},
			expectedStatus: 404,
			expectedBody:   `{"error": "Not found"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			response, err := handleRequest(context.Background(), tt.request)
			if err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}

			if response.StatusCode != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d", tt.expectedStatus, response.StatusCode)
			}

			if tt.expectedBody != "" && response.Body != tt.expectedBody {
				t.Errorf("Expected body %s, got %s", tt.expectedBody, response.Body)
			}

			// Check CORS headers
			if response.Headers["Access-Control-Allow-Origin"] != "*" {
				t.Errorf("Expected CORS header, got %s", response.Headers["Access-Control-Allow-Origin"])
			}

			// For successful JSON responses, verify the response is valid JSON (except for OPTIONS with empty body)
			if tt.expectedStatus == 200 && tt.expectedBody == "" && !tt.allowEmptyBody {
				if !isValidJSON(response.Body) {
					t.Errorf("Response body is not valid JSON: %s", response.Body)
				}
			}
		})
	}
}

func TestSearchOptionsResponse(t *testing.T) {
	if err := loadCarsFromCSV(); err != nil {
		t.Fatalf("Failed to load cars: %v", err)
	}

	request := events.APIGatewayProxyRequest{
		HTTPMethod: "GET",
		Resource:   "/search/options",
	}

	response, err := handleRequest(context.Background(), request)
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if response.StatusCode != 200 {
		t.Fatalf("Expected status 200, got %d", response.StatusCode)
	}

	var options SearchOptions
	if err := json.Unmarshal([]byte(response.Body), &options); err != nil {
		t.Fatalf("Failed to unmarshal response: %v", err)
	}

	// Verify that we have some options
	if len(options.CarTypes) == 0 {
		t.Error("Expected car types to be populated")
	}

	if len(options.Transmissions) == 0 {
		t.Error("Expected transmissions to be populated")
	}

	if len(options.Fuels) == 0 {
		t.Error("Expected fuels to be populated")
	}

	if options.MinPrice <= 0 || options.MaxPrice <= 0 {
		t.Error("Expected price ranges to be populated")
	}
}

func TestSearchResponse(t *testing.T) {
	if err := loadCarsFromCSV(); err != nil {
		t.Fatalf("Failed to load cars: %v", err)
	}

	searchReq := SearchRequest{
		Query: "BMW",
		Limit: 5,
	}

	reqBody, _ := json.Marshal(searchReq)

	request := events.APIGatewayProxyRequest{
		HTTPMethod: "POST",
		Resource:   "/search",
		Body:       string(reqBody),
	}

	response, err := handleRequest(context.Background(), request)
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if response.StatusCode != 200 {
		t.Fatalf("Expected status 200, got %d", response.StatusCode)
	}

	var searchResponse SearchResponse
	if err := json.Unmarshal([]byte(response.Body), &searchResponse); err != nil {
		t.Fatalf("Failed to unmarshal response: %v", err)
	}

	// Verify that we found BMW cars
	if searchResponse.Total == 0 {
		t.Error("Expected to find BMW cars")
	}

	if len(searchResponse.Cars) == 0 {
		t.Error("Expected cars array to be populated")
	}

	// Verify pagination info
	if searchResponse.Limit != 5 {
		t.Errorf("Expected limit 5, got %d", searchResponse.Limit)
	}

	if searchResponse.Offset != 0 {
		t.Errorf("Expected offset 0, got %d", searchResponse.Offset)
	}
}

// Helper functions
func intPtr(i int) *int {
	return &i
}

func carEquals(a, b Car) bool {
	return a.ID == b.ID &&
		a.Title == b.Title &&
		a.PriceCHF == b.PriceCHF &&
		a.LeasingText == b.LeasingText &&
		a.FirstReg == b.FirstReg &&
		a.CarType == b.CarType &&
		a.MileageKM == b.MileageKM &&
		a.Transmission == b.Transmission &&
		a.Fuel == b.Fuel &&
		a.Drive == b.Drive &&
		a.PowerHP == b.PowerHP &&
		a.PowerKW == b.PowerKW &&
		a.MFK == b.MFK &&
		a.Warranty == b.Warranty &&
		a.WarrantyText == b.WarrantyText &&
		slicesEqual(a.Equipment, b.Equipment) &&
		a.Description == b.Description &&
		slicesEqual(a.ImageURLs, b.ImageURLs)
}

func slicesEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}

	// Create maps for comparison since order doesn't matter for unique values
	mapA := make(map[string]bool)
	mapB := make(map[string]bool)

	for _, v := range a {
		mapA[v] = true
	}

	for _, v := range b {
		mapB[v] = true
	}

	if len(mapA) != len(mapB) {
		return false
	}

	for k := range mapA {
		if !mapB[k] {
			return false
		}
	}

	return true
}

func isValidJSON(s string) bool {
	var js json.RawMessage
	return json.Unmarshal([]byte(s), &js) == nil
}
