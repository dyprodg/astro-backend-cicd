package main

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

// Car represents a single car entry
type Car struct {
	ID           int      `json:"id"`
	Title        string   `json:"title"`
	PriceCHF     int      `json:"price_chf"`
	LeasingText  string   `json:"leasing_text"`
	FirstReg     string   `json:"first_registration"`
	CarType      string   `json:"car_type"`
	MileageKM    int      `json:"mileage_km"`
	Transmission string   `json:"transmission"`
	Fuel         string   `json:"fuel"`
	Drive        string   `json:"drive"`
	PowerHP      int      `json:"power_hp"`
	PowerKW      int      `json:"power_kw"`
	MFK          bool     `json:"mfk"`
	Warranty     bool     `json:"warranty"`
	WarrantyText string   `json:"warranty_text"`
	Equipment    []string `json:"equipment"`
	Description  string   `json:"description"`
	ImageURLs    []string `json:"image_urls"`
}

// SearchOptions represents available search filter options
type SearchOptions struct {
	CarTypes      []string `json:"car_types"`
	Transmissions []string `json:"transmissions"`
	Fuels         []string `json:"fuels"`
	Drives        []string `json:"drives"`
	MinPrice      int      `json:"min_price"`
	MaxPrice      int      `json:"max_price"`
	MinMileage    int      `json:"min_mileage"`
	MaxMileage    int      `json:"max_mileage"`
	MinPower      int      `json:"min_power"`
	MaxPower      int      `json:"max_power"`
}

// SearchRequest represents search parameters
type SearchRequest struct {
	Query        string `json:"query,omitempty"`
	CarType      string `json:"car_type,omitempty"`
	Transmission string `json:"transmission,omitempty"`
	Fuel         string `json:"fuel,omitempty"`
	Drive        string `json:"drive,omitempty"`
	MinPrice     *int   `json:"min_price,omitempty"`
	MaxPrice     *int   `json:"max_price,omitempty"`
	MinMileage   *int   `json:"min_mileage,omitempty"`
	MaxMileage   *int   `json:"max_mileage,omitempty"`
	MinPower     *int   `json:"min_power,omitempty"`
	MaxPower     *int   `json:"max_power,omitempty"`
	Limit        int    `json:"limit,omitempty"`
	Offset       int    `json:"offset,omitempty"`
}

// SearchResponse represents search results
type SearchResponse struct {
	Cars   []Car `json:"cars"`
	Total  int   `json:"total"`
	Limit  int   `json:"limit"`
	Offset int   `json:"offset"`
}

var cars []Car

// loadCarsFromCSV loads car data from embedded CSV content
func loadCarsFromCSV() error {
	csvContent := `id,title,price_chf,leasing_text,first_registration,car_type,mileage_km,transmission,fuel,drive,power_hp,power_kw,mfk,warranty,warranty_text,equipment,description,image_urls
1,BMW 520d xDrive 48V M Sport Steptronic,42890,Ab 580.- pro Monat ohne Anzahlung,08.2021,Limousine,55000,Automatik,Diesel,Allrad,190,140,True,True,"Ab 1. Inverkehrsetzung, 19.08.2021, 24 Monate oder 100'000 km",Ambientes Licht;Mild-Hybrid;Rückfahrkamera;Sportsitze,"Top gepflegt, M Sport Paket",https://img.example.com/bmw1.jpg;https://img.example.com/bmw2.jpg
2,Audi A4 Avant S line 40 TDI,38900,Ab 530.- mtl.,07.2020,Kombi,62000,Automatik,Diesel,Front,204,150,True,True,"Audi Occasion Plus, 12 Monate Garantie",LED Scheinwerfer;S line Exterieur;Spurhalteassistent,Gepflegtes Nichtraucherfahrzeug,https://img.example.com/audi1.jpg;https://img.example.com/audi2.jpg
3,Mercedes-Benz C 200 AMG Line,39900,Ab 545.- mtl.,05.2021,Limousine,48000,Automatik,Benzin,Hinterrad,204,150,True,True,24 Monate Garantie,AMG-Paket;Panoramadach;360° Kamera,Sehr guter Zustand,https://img.example.com/merc1.jpg;https://img.example.com/merc2.jpg
4,Volkswagen Golf 8 GTI,35900,Ab 490.- mtl.,06.2022,Limousine,23000,Automatik,Benzin,Front,245,180,True,True,Werksgarantie bis 2026,Digital Cockpit;Sportsitze;Ambientebeleuchtung,"Neuwertig, unfallfrei",https://img.example.com/golf1.jpg;https://img.example.com/golf2.jpg
5,Škoda Octavia Combi Style 2.0 TDI,29900,Ab 410.- mtl.,09.2021,Kombi,45000,Manuell,Diesel,Front,150,110,True,True,12 Monate Garantie,Navi;Sitzheizung;Parkpilot,"Sparsam, viel Platz",https://img.example.com/skoda1.jpg
6,Volvo XC60 B4 AWD Momentum,48900,Ab 650.- mtl.,03.2022,SUV,30000,Automatik,Diesel,Allrad,197,145,True,True,Volvo Selekt Garantie,Spurhalteassistent;Pilot Assist;Leder,"Schweizer Fahrzeug, Scheckheft",https://img.example.com/volvo1.jpg
7,Tesla Model 3 Long Range AWD,44900,Ab 620.- mtl.,12.2021,Limousine,27000,Automatik,Elektro,Allrad,351,258,True,True,Tesla Garantie bis 2025,Autopilot;Glasdach;Sitzheizung,"Unfallfrei, 1. Hand",https://img.example.com/tesla1.jpg
8,Ford Kuga 2.5 Plug-in Hybrid ST-Line,36900,Ab 510.- mtl.,01.2022,SUV,19000,Automatik,Hybrid,Front,225,165,True,True,5 Jahre Garantie,PHEV;LED;Sportfahrwerk,"Wenig km, sportlich",https://img.example.com/ford1.jpg
9,Peugeot 3008 Allure Pack PureTech 130,31900,Ab 440.- mtl.,04.2021,SUV,35000,Automatik,Benzin,Front,130,96,True,True,12 Monate Händlergarantie,Keyless;Kamera;Touchscreen,Komfortables Familienfahrzeug,https://img.example.com/peugeot1.jpg
10,Honda Civic Sport 1.5 VTEC Turbo,28900,Ab 390.- mtl.,10.2020,Limousine,60000,Manuell,Benzin,Front,182,134,True,True,12 Monate Garantie,Sportpaket;Rückfahrkamera;Sitzheizung,"Top Zustand, viele Extras",https://img.example.com/honda1.jpg`

	reader := csv.NewReader(strings.NewReader(csvContent))
	records, err := reader.ReadAll()
	if err != nil {
		return fmt.Errorf("error reading CSV: %w", err)
	}

	cars = make([]Car, 0, len(records)-1)

	for i, record := range records {
		if i == 0 { // Skip header
			continue
		}

		if len(record) != 18 {
			log.Printf("Skipping row %d: expected 18 columns, got %d", i, len(record))
			continue
		}

		car, err := parseCarRecord(record)
		if err != nil {
			log.Printf("Error parsing row %d: %v", i, err)
			continue
		}

		cars = append(cars, car)
	}

	log.Printf("Loaded %d cars from CSV", len(cars))
	return nil
}

func parseCarRecord(record []string) (Car, error) {
	id, err := strconv.Atoi(record[0])
	if err != nil {
		return Car{}, fmt.Errorf("invalid id: %w", err)
	}

	priceCHF, err := strconv.Atoi(record[2])
	if err != nil {
		return Car{}, fmt.Errorf("invalid price: %w", err)
	}

	mileageKM, err := strconv.Atoi(record[6])
	if err != nil {
		return Car{}, fmt.Errorf("invalid mileage: %w", err)
	}

	powerHP, err := strconv.Atoi(record[10])
	if err != nil {
		return Car{}, fmt.Errorf("invalid power HP: %w", err)
	}

	powerKW, err := strconv.Atoi(record[11])
	if err != nil {
		return Car{}, fmt.Errorf("invalid power KW: %w", err)
	}

	mfk := strings.ToLower(record[12]) == "true"
	warranty := strings.ToLower(record[13]) == "true"

	equipment := []string{}
	if record[15] != "" {
		equipment = strings.Split(record[15], ";")
	}

	imageURLs := []string{}
	if record[17] != "" {
		imageURLs = strings.Split(record[17], ";")
	}

	return Car{
		ID:           id,
		Title:        record[1],
		PriceCHF:     priceCHF,
		LeasingText:  record[3],
		FirstReg:     record[4],
		CarType:      record[5],
		MileageKM:    mileageKM,
		Transmission: record[7],
		Fuel:         record[8],
		Drive:        record[9],
		PowerHP:      powerHP,
		PowerKW:      powerKW,
		MFK:          mfk,
		Warranty:     warranty,
		WarrantyText: record[14],
		Equipment:    equipment,
		Description:  record[16],
		ImageURLs:    imageURLs,
	}, nil
}

func getSearchOptions() SearchOptions {
	carTypes := make(map[string]bool)
	transmissions := make(map[string]bool)
	fuels := make(map[string]bool)
	drives := make(map[string]bool)

	minPrice, maxPrice := 999999, 0
	minMileage, maxMileage := 999999, 0
	minPower, maxPower := 999, 0

	for _, car := range cars {
		carTypes[car.CarType] = true
		transmissions[car.Transmission] = true
		fuels[car.Fuel] = true
		drives[car.Drive] = true

		if car.PriceCHF < minPrice {
			minPrice = car.PriceCHF
		}
		if car.PriceCHF > maxPrice {
			maxPrice = car.PriceCHF
		}

		if car.MileageKM < minMileage {
			minMileage = car.MileageKM
		}
		if car.MileageKM > maxMileage {
			maxMileage = car.MileageKM
		}

		if car.PowerHP < minPower {
			minPower = car.PowerHP
		}
		if car.PowerHP > maxPower {
			maxPower = car.PowerHP
		}
	}

	options := SearchOptions{
		CarTypes:      mapKeysToSlice(carTypes),
		Transmissions: mapKeysToSlice(transmissions),
		Fuels:         mapKeysToSlice(fuels),
		Drives:        mapKeysToSlice(drives),
		MinPrice:      minPrice,
		MaxPrice:      maxPrice,
		MinMileage:    minMileage,
		MaxMileage:    maxMileage,
		MinPower:      minPower,
		MaxPower:      maxPower,
	}

	return options
}

func mapKeysToSlice(m map[string]bool) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

func searchCars(req SearchRequest) SearchResponse {
	filtered := make([]Car, 0)

	for _, car := range cars {
		if matchesCriteria(car, req) {
			filtered = append(filtered, car)
		}
	}

	total := len(filtered)

	// Apply pagination
	if req.Limit <= 0 {
		req.Limit = 10 // Default limit
	}
	if req.Offset < 0 {
		req.Offset = 0
	}

	start := req.Offset
	end := start + req.Limit

	if start >= len(filtered) {
		filtered = []Car{}
	} else if end > len(filtered) {
		filtered = filtered[start:]
	} else {
		filtered = filtered[start:end]
	}

	return SearchResponse{
		Cars:   filtered,
		Total:  total,
		Limit:  req.Limit,
		Offset: req.Offset,
	}
}

func matchesCriteria(car Car, req SearchRequest) bool {
	// Text search in title and description
	if req.Query != "" {
		query := strings.ToLower(req.Query)
		title := strings.ToLower(car.Title)
		description := strings.ToLower(car.Description)

		if !strings.Contains(title, query) && !strings.Contains(description, query) {
			return false
		}
	}

	// Filter by car type
	if req.CarType != "" && car.CarType != req.CarType {
		return false
	}

	// Filter by transmission
	if req.Transmission != "" && car.Transmission != req.Transmission {
		return false
	}

	// Filter by fuel
	if req.Fuel != "" && car.Fuel != req.Fuel {
		return false
	}

	// Filter by drive
	if req.Drive != "" && car.Drive != req.Drive {
		return false
	}

	// Filter by price range
	if req.MinPrice != nil && car.PriceCHF < *req.MinPrice {
		return false
	}
	if req.MaxPrice != nil && car.PriceCHF > *req.MaxPrice {
		return false
	}

	// Filter by mileage range
	if req.MinMileage != nil && car.MileageKM < *req.MinMileage {
		return false
	}
	if req.MaxMileage != nil && car.MileageKM > *req.MaxMileage {
		return false
	}

	// Filter by power range
	if req.MinPower != nil && car.PowerHP < *req.MinPower {
		return false
	}
	if req.MaxPower != nil && car.PowerHP > *req.MaxPower {
		return false
	}

	return true
}

func corsHeaders() map[string]string {
	return map[string]string{
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Methods": "GET, POST, OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type, Authorization",
		"Content-Type":                 "application/json",
	}
}

func handleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// Handle CORS preflight
	if request.HTTPMethod == "OPTIONS" {
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusOK,
			Headers:    corsHeaders(),
		}, nil
	}

	headers := corsHeaders()

	switch request.Resource {
	case "/search/options":
		if request.HTTPMethod != "GET" {
			return events.APIGatewayProxyResponse{
				StatusCode: http.StatusMethodNotAllowed,
				Headers:    headers,
				Body:       `{"error": "Method not allowed"}`,
			}, nil
		}

		options := getSearchOptions()
		body, err := json.Marshal(options)
		if err != nil {
			return events.APIGatewayProxyResponse{
				StatusCode: http.StatusInternalServerError,
				Headers:    headers,
				Body:       `{"error": "Internal server error"}`,
			}, nil
		}

		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusOK,
			Headers:    headers,
			Body:       string(body),
		}, nil

	case "/search":
		if request.HTTPMethod != "POST" {
			return events.APIGatewayProxyResponse{
				StatusCode: http.StatusMethodNotAllowed,
				Headers:    headers,
				Body:       `{"error": "Method not allowed"}`,
			}, nil
		}

		var searchReq SearchRequest
		if err := json.Unmarshal([]byte(request.Body), &searchReq); err != nil {
			return events.APIGatewayProxyResponse{
				StatusCode: http.StatusBadRequest,
				Headers:    headers,
				Body:       `{"error": "Invalid JSON body"}`,
			}, nil
		}

		response := searchCars(searchReq)
		body, err := json.Marshal(response)
		if err != nil {
			return events.APIGatewayProxyResponse{
				StatusCode: http.StatusInternalServerError,
				Headers:    headers,
				Body:       `{"error": "Internal server error"}`,
			}, nil
		}

		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusOK,
			Headers:    headers,
			Body:       string(body),
		}, nil

	default:
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusNotFound,
			Headers:    headers,
			Body:       `{"error": "Not found"}`,
		}, nil
	}
}

func main() {
	if err := loadCarsFromCSV(); err != nil {
		log.Fatalf("Failed to load cars: %v", err)
	}

	lambda.Start(handleRequest)
}
