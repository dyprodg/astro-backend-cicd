# Data Bucket Setup und Nutzung

Dieses Setup erstellt einen öffentlichen S3 Bucket für die Car Search API Daten.

## 🏗️ Infrastruktur

### S3 Bucket
- **Name:** `astro-backend-data-bucket`
- **Verwendung:** CSV Dateien und Fahrzeugbilder
- **Zugriff:** Public GET für alle Objekte
- **Verschlüsselung:** AES256
- **Versionierung:** Aktiviert
- **CORS:** Aktiviert für Browser-Zugriff

## 📁 Struktur

```
astro-backend-data-bucket/
├── autos.csv              # Haupt-CSV Datei
└── images/                # Fahrzeugbilder
    ├── car1.jpg
    ├── car2.png
    └── ...
```

## 🚀 Deployment

1. **Infrastruktur deployen:**
```bash
cd infra/
terraform apply
```

2. **CSV initial hochladen:**
```bash
cd backend/functions/search-api/
make upload-csv
```

## 💾 CSV Management

### CSV hochladen
```bash
cd backend/functions/search-api/
make upload-csv
```

### CSV Format
Die `autos.csv` muss folgende 18 Spalten haben:
1. ID
2. Title
3. Price CHF
4. Leasing Text
5. First Registration
6. Car Type
7. Mileage KM
8. Transmission
9. Fuel
10. Drive
11. Power HP
12. Power KW
13. MFK (boolean)
14. Warranty (boolean)
15. Warranty Text
16. Equipment (semicolon separated)
17. Description
18. Image URLs (semicolon separated)

### Automatischer Download
Der CI/CD Workflow lädt automatisch die aktuellste CSV von S3 vor dem Build.

### CSV URL
```
https://astro-backend-data-bucket.s3.eu-central-1.amazonaws.com/autos.csv
```

## 🖼️ Bilder Management

### Einzelnes Bild hochladen
```bash
cd backend/functions/search-api/
make upload-image FILE=path/to/image.jpg
```

### Mehrere Bilder hochladen
```bash
# Direkt mit AWS CLI
aws s3 cp images/ s3://astro-backend-data-bucket/images/ --recursive
```

### Bild URLs im CSV
Bilder können referenziert werden als:
- S3 URLs: `https://astro-backend-data-bucket.s3.eu-central-1.amazonaws.com/images/car1.jpg`
- Multiple URLs mit `;` getrennt

### Images Base URL
```
https://astro-backend-data-bucket.s3.eu-central-1.amazonaws.com/images/
```

## 🔄 Build Process

### Lokaler Build
```bash
cd backend/functions/search-api/
make build  # Lädt automatisch CSV von S3
```

### CI/CD Workflow
1. Prüft ob CSV in S3 existiert
2. Upload lokale CSV falls nicht vorhanden
3. Download aktuelle CSV vor Build
4. Build und Deploy der Lambda

## 📊 Monitoring

### S3 Metriken  
- Storage Usage
- Request Metrics
- Data Transfer
- Error Rates

## 🛠️ Troubleshooting

### CSV nicht gefunden
```bash
# Prüfen ob CSV in S3 existiert
aws s3 ls s3://astro-backend-data-bucket/autos.csv

# Manuell hochladen falls fehlt
aws s3 cp autos.csv s3://astro-backend-data-bucket/autos.csv
```

### Public Access prüfen
```bash
# Testen ob CSV öffentlich verfügbar ist
curl -I https://astro-backend-data-bucket.s3.eu-central-1.amazonaws.com/autos.csv
```

### Berechtigungen prüfen
```bash
# IAM Rolle für CI/CD prüfen
aws sts get-caller-identity
aws iam get-role --role-name astro-backend-cicd-role
```

## 🔐 Sicherheit

- **Public GET Access:** Nur lesender Zugriff auf Objekte
- **HTTPS Support:** SSL-verschlüsselte Verbindungen
- **IAM Permissions:** Minimale erforderliche Berechtigungen
- **Encryption:** Server-side Verschlüsselung
- **CORS:** Browser-freundliche Konfiguration

## 💰 Kosten

- **S3 Storage:** ~$0.023/GB/Monat
- **S3 Requests:** $0.0004/1000 GET requests
- **Data Transfer:** Erste 1GB/Monat kostenlos, dann $0.09/GB

Geschätzte monatliche Kosten für kleine App: **< $2**

## 🆚 Vorteile vs CloudFront

### S3 Direct Access
✅ **Einfacher:** Keine zusätzliche Distribution  
✅ **Günstiger:** Keine CloudFront-Kosten  
✅ **Direkt:** Sofortige Verfügbarkeit nach Upload  
✅ **CORS:** Native Browser-Unterstützung  

### CloudFront (falls später gewünscht)
❌ **Komplexer:** Zusätzliche Konfiguration  
❌ **Teurer:** Extra CloudFront-Kosten  
❌ **Cache:** Verzögerung bei Updates  
✅ **Performance:** Bessere globale Latenz  
✅ **Caching:** Reduzierte S3-Requests 