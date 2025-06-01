# Search API

Eine umfassende Such-API für Fahrzeugdaten basierend auf CSV-Daten, gehostet auf AWS Lambda mit API Gateway.

## Features

- **Suchoptionen**: Ruft verfügbare Filteroptionen für Dropdowns ab
- **Erweiterte Suche**: Volltext-Suche und Filterung nach verschiedenen Kriterien
- **Pagination**: Unterstützung für limit/offset-basierte Paginierung
- **CORS**: Vollständig konfiguriert für Frontend-Integration
- **Typisiert**: Vollständig typisierte Go-Strukturen
- **Getestet**: Umfassende Unit-Tests
- **ARM64**: Optimiert für AWS Graviton2 Prozessoren

## API Endpunkte

### GET `/search/options`

Ruft verfügbare Suchoptionen ab (für Dropdown-Befüllung).

**Response:**
```json
{
  "car_types": ["Limousine", "Kombi", "SUV"],
  "transmissions": ["Automatik", "Manuell"],
  "fuels": ["Diesel", "Benzin", "Elektro", "Hybrid"],
  "drives": ["Allrad", "Front", "Hinterrad"],
  "min_price": 28900,
  "max_price": 48900,
  "min_mileage": 19000,
  "max_mileage": 62000,
  "min_power": 130,
  "max_power": 351
}
```

### POST `/search`

Führt eine Suche basierend auf den angegebenen Kriterien aus.

**Request Body:**
```json
{
  "query": "BMW",
  "car_type": "Limousine",
  "transmission": "Automatik",
  "fuel": "Diesel",
  "drive": "Allrad",
  "min_price": 30000,
  "max_price": 50000,
  "min_mileage": 0,
  "max_mileage": 60000,
  "min_power": 150,
  "max_power": 300,
  "limit": 10,
  "offset": 0
}
```

**Response:**
```json
{
  "cars": [
    {
      "id": 1,
      "title": "BMW 520d xDrive 48V M Sport Steptronic",
      "price_chf": 42890,
      "leasing_text": "Ab 580.- pro Monat ohne Anzahlung",
      "first_registration": "08.2021",
      "car_type": "Limousine",
      "mileage_km": 55000,
      "transmission": "Automatik",
      "fuel": "Diesel",
      "drive": "Allrad",
      "power_hp": 190,
      "power_kw": 140,
      "mfk": true,
      "warranty": true,
      "warranty_text": "Ab 1. Inverkehrsetzung, 19.08.2021, 24 Monate oder 100'000 km",
      "equipment": ["Ambientes Licht", "Mild-Hybrid", "Rückfahrkamera", "Sportsitze"],
      "description": "Top gepflegt, M Sport Paket",
      "image_urls": ["https://img.example.com/bmw1.jpg", "https://img.example.com/bmw2.jpg"]
    }
  ],
  "total": 1,
  "limit": 10,
  "offset": 0
}
```

## Suchkriterien

- **query**: Volltext-Suche in Titel und Beschreibung
- **car_type**: Fahrzeugtyp (Limousine, Kombi, SUV)
- **transmission**: Getriebe (Automatik, Manuell)
- **fuel**: Kraftstoff (Diesel, Benzin, Elektro, Hybrid)
- **drive**: Antrieb (Allrad, Front, Hinterrad)
- **min_price/max_price**: Preisbereich in CHF
- **min_mileage/max_mileage**: Kilometerstand-Bereich
- **min_power/max_power**: Leistungsbereich in PS
- **limit**: Anzahl der Ergebnisse (Standard: 10)
- **offset**: Offset für Paginierung (Standard: 0)

## Beispiel-Anfragen

### Alle BMW-Fahrzeuge
```bash
curl -X POST https://your-api-url/search \
  -H "Content-Type: application/json" \
  -d '{"query": "BMW", "limit": 5}'
```

### SUVs mit Automatikgetriebe
```bash
curl -X POST https://your-api-url/search \
  -H "Content-Type: application/json" \
  -d '{"car_type": "SUV", "transmission": "Automatik"}'
```

### Fahrzeuge im Preisbereich 30.000-40.000 CHF
```bash
curl -X POST https://your-api-url/search \
  -H "Content-Type: application/json" \
  -d '{"min_price": 30000, "max_price": 40000}'
```

### Suchoptionen abrufen
```bash
curl https://your-api-url/search/options
```

## Lokale Entwicklung

### Voraussetzungen
- Go 1.21+
- AWS CLI konfiguriert
- Terraform installiert

### Setup
```bash
# In das Funktions-Verzeichnis wechseln
cd backend/functions/search-api

# Dependencies installieren
make deps

# Tests ausführen
make test

# Für lokale Tests kompilieren
make build-local

# Für Lambda (ARM64) kompilieren
make build
```

### Tests ausführen
```bash
# In das Funktions-Verzeichnis wechseln
cd backend/functions/search-api

# Alle Tests
make test

# Test Coverage
make test-cover

# Spezifische Tests
go test -v -run TestSearchCars
go test -v -run TestParseCarRecord
```

## Deployment

### Mit GitHub Actions (Empfohlen)
1. Änderungen in `backend/functions/search-api/` pushen
2. Pipeline läuft automatisch
3. Bei Push auf `main`: Automatisches Deployment

### Mit Makefile (Empfohlen für lokale Entwicklung)
```bash
# In das Funktions-Verzeichnis wechseln
cd backend/functions/search-api

# Komplettes Deployment
make deploy

# Nur Build und ZIP
make zip

# Nur Lambda-Funktion aktualisieren (schneller)
make update-lambda
```

### Mit Terraform (Manuell)
```bash
# Vom Root-Verzeichnis oder Funktions-Verzeichnis
make tf-init
make plan
make deploy

# Oder direkt mit Terraform
cd infra
terraform init
terraform plan
terraform apply
```

## Architektur

```
Frontend ──→ API Gateway ──→ Lambda Function (ARM64) ──→ CSV Data (embedded)
                   │
                   └──→ CloudWatch Logs
```

### Komponenten
- **AWS Lambda**: Serverless Go-Runtime auf ARM64 (Graviton2)
- **Runtime**: provided.al2023 (Amazon Linux 2023)
- **API Gateway**: HTTP-Endpunkte mit CORS-Unterstützung
- **CloudWatch**: Logging und Monitoring
- **CSV-Daten**: Eingebettet in der Lambda-Funktion

## Performance

- **Cold Start**: ~100-300ms (ARM64 optimiert)
- **Warm Requests**: ~5-20ms
- **Memory**: 256MB
- **Timeout**: 30 Sekunden
- **Architecture**: ARM64 (AWS Graviton2)
- **Cost**: ~20% günstiger als x86_64

### ARM64 Vorteile
- **Bessere Performance/Watt-Verhältnis**
- **Geringere Kosten**
- **Schnellere Invoke-Zeiten**
- **Kleinere Binaries**

## CORS Konfiguration

Die API ist für alle Origins konfiguriert:
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Methods: GET, POST, OPTIONS`
- `Access-Control-Allow-Headers: Content-Type, Authorization`

## Monitoring

CloudWatch Logs sind unter `/aws/lambda/search-api` verfügbar. 

### Wichtige Metriken
- Anzahl Requests
- Durchschnittliche Latenz
- Error Rate
- Memory Utilization
- Cold Start Rate

## Fehlerbehandlung

Die API gibt folgende HTTP-Status-Codes zurück:
- `200`: Erfolgreiche Anfrage
- `400`: Ungültiger JSON-Body
- `405`: Method Not Allowed
- `404`: Endpoint nicht gefunden
- `500`: Interner Server-Fehler

## Sicherheit

- Keine Authentifizierung (öffentliche API)
- Rate Limiting über AWS API Gateway
- Input Validation in Go-Code
- CORS für Frontend-Zugriff konfiguriert

## CI/CD Pipeline

### GitHub Actions
- **Trigger**: Änderungen in `backend/functions/search-api/**`
- **Tests**: Automatische Go-Tests und Linting
- **Build**: ARM64-Binary erstellen
- **Deploy**: Automatisches Deployment bei Push auf `main`

### Pipeline Steps
1. **Test**: Go-Tests, Formatierung, Linting
2. **Build**: ARM64-Binary kompilieren
3. **Plan**: Terraform Plan (nur PR)
4. **Deploy**: Terraform Apply (nur main)
5. **Test**: API-Endpunkte testen

## Datenstruktur

Die CSV-Daten enthalten folgende Felder:
- `id`: Eindeutige Fahrzeug-ID
- `title`: Fahrzeugtitel
- `price_chf`: Preis in CHF
- `leasing_text`: Leasing-Information
- `first_registration`: Erstzulassung
- `car_type`: Fahrzeugtyp
- `mileage_km`: Kilometerstand
- `transmission`: Getriebe
- `fuel`: Kraftstoff
- `drive`: Antrieb
- `power_hp`: Leistung in PS
- `power_kw`: Leistung in kW
- `mfk`: MFK-Status
- `warranty`: Garantie-Status
- `warranty_text`: Garantie-Details
- `equipment`: Ausstattung (Semikolon-getrennt)
- `description`: Beschreibung
- `image_urls`: Bild-URLs (Semikolon-getrennt) 