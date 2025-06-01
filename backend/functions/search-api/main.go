package main

import (
	"context"
	_ "embed"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"html"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

//go:embed autos.csv
var csvContent string

// Constants for validation
const (
	MaxQueryLength  = 100
	MaxStringLength = 1000
	MaxLimit        = 100
	MaxOffset       = 10000
	MinPrice        = 0
	MaxPrice        = 10000000 // 10M CHF should be enough
	MinMileage      = 0
	MaxMileage      = 2000000 // 2M km should be enough
	MinPower        = 0
	MaxPower        = 2000 // 2000 HP should be enough
)

// Regular expressions for validation
var (
	alphanumericRegex = regexp.MustCompile(`^[a-zA-Z0-9\s\-\.äöüÄÖÜß]*$`)
	safeStringRegex   = regexp.MustCompile(`^[a-zA-Z0-9\s\-\.\,\;\(\)äöüÄÖÜß]*$`)
)

// Car represents a single car entry
type Car struct {
	ID           int      `json:"id"`
	Title        string   `json:"title"`
	Brand        string   `json:"brand"`
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
	Brands        []string `json:"brands"`
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
	Brand        string `json:"brand,omitempty"`
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

// ValidationError represents a validation error
type ValidationError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

type ErrorResponse struct {
	Error       string            `json:"error"`
	Validations []ValidationError `json:"validations,omitempty"`
}

var cars []Car

// sanitizeString removes potentially dangerous characters and HTML-escapes the result
func sanitizeString(s string) string {
	// Trim whitespace
	s = strings.TrimSpace(s)

	// Limit length
	if len(s) > MaxStringLength {
		s = s[:MaxStringLength]
	}

	// HTML escape to prevent XSS
	s = html.EscapeString(s)

	return s
}

// validateString checks if a string contains only safe characters
func validateString(s string, regex *regexp.Regexp) bool {
	return regex.MatchString(s)
}

// validateIntRange checks if an integer is within a valid range
func validateIntRange(value, min, max int) bool {
	return value >= min && value <= max
}

// validateSearchRequest validates and sanitizes the search request
func validateSearchRequest(req *SearchRequest) []ValidationError {
	var errors []ValidationError

	// Validate and sanitize query
	if req.Query != "" {
		if len(req.Query) > MaxQueryLength {
			errors = append(errors, ValidationError{
				Field:   "query",
				Message: fmt.Sprintf("Query too long, maximum %d characters", MaxQueryLength),
			})
		}
		if !validateString(req.Query, alphanumericRegex) {
			errors = append(errors, ValidationError{
				Field:   "query",
				Message: "Query contains invalid characters",
			})
		}
		req.Query = sanitizeString(req.Query)
	}

	// Validate and sanitize brand
	if req.Brand != "" {
		if !validateString(req.Brand, alphanumericRegex) {
			errors = append(errors, ValidationError{
				Field:   "brand",
				Message: "Brand contains invalid characters",
			})
		}
		req.Brand = sanitizeString(req.Brand)
	}

	// Validate car type (must be from predefined list)
	if req.CarType != "" {
		req.CarType = sanitizeString(req.CarType)
	}

	// Validate transmission (must be from predefined list)
	if req.Transmission != "" {
		req.Transmission = sanitizeString(req.Transmission)
	}

	// Validate fuel (must be from predefined list)
	if req.Fuel != "" {
		req.Fuel = sanitizeString(req.Fuel)
	}

	// Validate drive (must be from predefined list)
	if req.Drive != "" {
		req.Drive = sanitizeString(req.Drive)
	}

	// Validate price ranges
	if req.MinPrice != nil {
		if !validateIntRange(*req.MinPrice, MinPrice, MaxPrice) {
			errors = append(errors, ValidationError{
				Field:   "min_price",
				Message: fmt.Sprintf("Min price must be between %d and %d", MinPrice, MaxPrice),
			})
		}
	}
	if req.MaxPrice != nil {
		if !validateIntRange(*req.MaxPrice, MinPrice, MaxPrice) {
			errors = append(errors, ValidationError{
				Field:   "max_price",
				Message: fmt.Sprintf("Max price must be between %d and %d", MinPrice, MaxPrice),
			})
		}
	}

	// Validate mileage ranges
	if req.MinMileage != nil {
		if !validateIntRange(*req.MinMileage, MinMileage, MaxMileage) {
			errors = append(errors, ValidationError{
				Field:   "min_mileage",
				Message: fmt.Sprintf("Min mileage must be between %d and %d", MinMileage, MaxMileage),
			})
		}
	}
	if req.MaxMileage != nil {
		if !validateIntRange(*req.MaxMileage, MinMileage, MaxMileage) {
			errors = append(errors, ValidationError{
				Field:   "max_mileage",
				Message: fmt.Sprintf("Max mileage must be between %d and %d", MinMileage, MaxMileage),
			})
		}
	}

	// Validate power ranges
	if req.MinPower != nil {
		if !validateIntRange(*req.MinPower, MinPower, MaxPower) {
			errors = append(errors, ValidationError{
				Field:   "min_power",
				Message: fmt.Sprintf("Min power must be between %d and %d", MinPower, MaxPower),
			})
		}
	}
	if req.MaxPower != nil {
		if !validateIntRange(*req.MaxPower, MinPower, MaxPower) {
			errors = append(errors, ValidationError{
				Field:   "max_power",
				Message: fmt.Sprintf("Max power must be between %d and %d", MinPower, MaxPower),
			})
		}
	}

	// Validate limit and offset
	if req.Limit < 0 || req.Limit > MaxLimit {
		req.Limit = 10 // Set to default
	}
	if req.Offset < 0 || req.Offset > MaxOffset {
		req.Offset = 0 // Set to default
	}

	return errors
}

// extractBrandFromTitle extracts the brand from a car title
func extractBrandFromTitle(title string) string {
	// Remove common prefixes and clean the title
	title = strings.TrimSpace(title)

	// Split by space and take the first word as brand
	parts := strings.Fields(title)
	if len(parts) == 0 {
		return ""
	}

	brand := parts[0]

	// Handle special cases like "Mercedes-Benz"
	if strings.ToLower(brand) == "mercedes-benz" || strings.ToLower(brand) == "mercedes" {
		return "Mercedes-Benz"
	}

	return brand
}

// normalizeString removes diacritics and converts to lowercase for comparison
func normalizeString(s string) string {
	// Convert to lowercase
	s = strings.ToLower(s)

	// Replace common diacritics
	replacements := map[rune]rune{
		'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 's',
		'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
		'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
		'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
		'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o',
		'ù': 'u', 'ú': 'u', 'û': 'u',
		'ý': 'y', 'ÿ': 'y',
		'ñ': 'n', 'ç': 'c',
		'š': 's', 'č': 'c', 'ž': 'z',
	}

	var result strings.Builder
	for _, r := range s {
		if replacement, exists := replacements[r]; exists {
			result.WriteRune(replacement)
		} else {
			result.WriteRune(r)
		}
	}

	return result.String()
}

// brandMatches checks if a brand matches the search term (case-insensitive, partial)
func brandMatches(brand, searchTerm string) bool {
	if searchTerm == "" {
		return true
	}

	normalizedBrand := normalizeString(brand)
	normalizedSearch := normalizeString(searchTerm)

	return strings.Contains(normalizedBrand, normalizedSearch)
}

// loadCarsFromCSV loads car data from the embedded autos.csv file
func loadCarsFromCSV() error {
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

	log.Printf("Loaded %d cars from embedded CSV", len(cars))
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
		equipmentParts := strings.Split(record[15], ";")
		for _, part := range equipmentParts {
			// Sanitize each equipment part
			sanitized := sanitizeString(part)
			if sanitized != "" {
				equipment = append(equipment, sanitized)
			}
		}
	}

	imageURLs := []string{}
	if record[17] != "" {
		imageParts := strings.Split(record[17], ";")
		for _, part := range imageParts {
			// Basic URL validation - ensure it's a valid HTTP(S) URL
			part = strings.TrimSpace(part)
			if strings.HasPrefix(part, "http://") || strings.HasPrefix(part, "https://") {
				imageURLs = append(imageURLs, part)
			}
		}
	}

	title := sanitizeString(record[1])
	brand := extractBrandFromTitle(title)

	return Car{
		ID:           id,
		Title:        title,
		Brand:        brand,
		PriceCHF:     priceCHF,
		LeasingText:  sanitizeString(record[3]),
		FirstReg:     sanitizeString(record[4]),
		CarType:      sanitizeString(record[5]),
		MileageKM:    mileageKM,
		Transmission: sanitizeString(record[7]),
		Fuel:         sanitizeString(record[8]),
		Drive:        sanitizeString(record[9]),
		PowerHP:      powerHP,
		PowerKW:      powerKW,
		MFK:          mfk,
		Warranty:     warranty,
		WarrantyText: sanitizeString(record[14]),
		Equipment:    equipment,
		Description:  sanitizeString(record[16]),
		ImageURLs:    imageURLs,
	}, nil
}

func getSearchOptions() SearchOptions {
	brands := make(map[string]bool)
	carTypes := make(map[string]bool)
	transmissions := make(map[string]bool)
	fuels := make(map[string]bool)
	drives := make(map[string]bool)

	minPrice, maxPrice := 999999, 0
	minMileage, maxMileage := 999999, 0
	minPower, maxPower := 999, 0

	for _, car := range cars {
		if car.Brand != "" {
			brands[car.Brand] = true
		}
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
		Brands:        mapKeysToSlice(brands),
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

	// Apply pagination with validated limits
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
		query := normalizeString(req.Query)
		title := normalizeString(car.Title)
		description := normalizeString(car.Description)

		if !strings.Contains(title, query) && !strings.Contains(description, query) {
			return false
		}
	}

	// Filter by brand (case-insensitive, partial match)
	if req.Brand != "" && !brandMatches(car.Brand, req.Brand) {
		return false
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
		"Access-Control-Allow-Origin":  "*", // In production, restrict this to specific domains
		"Access-Control-Allow-Methods": "GET, POST, OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type, Authorization",
		"Content-Type":                 "application/json",
		"X-Content-Type-Options":       "nosniff",
		"X-Frame-Options":              "DENY",
		"X-XSS-Protection":             "1; mode=block",
	}
}

func handleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// Basic request validation
	if len(request.Body) > 10000 { // 10KB limit for request body
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusRequestEntityTooLarge,
			Headers:    corsHeaders(),
			Body:       `{"error": "Request body too large"}`,
		}, nil
	}

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
			log.Printf("Error marshaling search options: %v", err)
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
			log.Printf("Error unmarshaling search request: %v", err)
			return events.APIGatewayProxyResponse{
				StatusCode: http.StatusBadRequest,
				Headers:    headers,
				Body:       `{"error": "Invalid JSON body"}`,
			}, nil
		}

		// Validate request
		if validationErrors := validateSearchRequest(&searchReq); len(validationErrors) > 0 {
			errorResponse := ErrorResponse{
				Error:       "Validation failed",
				Validations: validationErrors,
			}
			body, _ := json.Marshal(errorResponse)
			return events.APIGatewayProxyResponse{
				StatusCode: http.StatusBadRequest,
				Headers:    headers,
				Body:       string(body),
			}, nil
		}

		response := searchCars(searchReq)
		body, err := json.Marshal(response)
		if err != nil {
			log.Printf("Error marshaling search response: %v", err)
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
