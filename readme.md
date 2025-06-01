# 🚀 Astro Preset – Astro + AWS Lambda + Terraform

Dieses Projekt ist ein modernes, SEO-optimiertes Starter-Template.  
Frontend basiert auf **Astro**, das Backend auf **AWS Lambda Functions**.  
Provisionierung erfolgt via **Terraform**, CI/CD via **GitHub Actions**.

---

## 📦 Projektstruktur

```

/frontend         → Astro-Projekt
/backend          → Lambda Functions (z. B. API-Endpunkte, Kontaktformular)
/infra            → Terraform Setup für S3, CloudFront, Lambda, API Gateway

```

---

## 🔧 Technologien

| Bereich     | Stack                                     |
|-------------|-------------------------------------------|
| Frontend    | Astro, Tailwind, Static HTML/JS           |
| Backend     | AWS Lambda, API Gateway                   |
| Infrastruktur | Terraform                               |
| CI/CD       | GitHub Actions                            |
| Hosting     | S3 + CloudFront                           |

---

## 🚀 Features (geplant)

- ⚡ Ultra-schnell & SEO-optimiert (Astro)
- 🌍 Globales CDN mit HTTPS (CloudFront)
- 📬 Kontaktformulare (z. B. Anfrage stellen)
- 🔌 Erweiterbar mit eigenen API-Endpunkten (Lambda)

---

## 🛠️ Setup

```bash
# Frontend
cd frontend
npm install
npm run dev

# Backend (lokal testen via z. B. aws-lambda-ric oder sam)
cd backend
# siehe README im Backend-Ordner

# Infrastruktur
cd infra
terraform init
terraform apply
```

---

## 🔄 CI/CD

GitHub Actions automatisieren:

* Astro-Build & Upload nach S3
* CloudFront Invalidation
* Terraform Apply bei Änderungen

Secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) müssen im GitHub Repo gesetzt sein.

---

## 🧪 Entwicklungsstatus

* [x] Projektstruktur initialisiert
* [ ] Frontend Basis (Landing, Beispielseiten, Kontakt)
* [ ] Backend API (z. B. GET /api, POST /kontakt)
* [ ] Terraform Setup für Infrastruktur
* [ ] CI/CD Pipeline

---

## 📁 Lizenz

MIT – Feel free to use, modify & contribute.

# Astro Backend CI/CD

Serverless Backend-API mit CI/CD-Pipeline für AWS Lambda und API Gateway.

## 🚀 Projekt-Übersicht

Dieses Repository enthält:
- **Search API**: Umfassende Such-API für Fahrzeugdaten
- **Contact Form**: Kontaktformular-API (geplant)
- **Infrastructure**: Terraform-Konfiguration für AWS
- **CI/CD**: GitHub Actions für automatisches Testing und Deployment

## 📁 Repository-Struktur

```
├── Makefile                              # Globale Operationen
├── backend/
│   └── functions/
│       ├── search-api/                   # Search API Lambda Funktion
│       │   ├── Makefile                 # Funktions-spezifische Commands
│       │   ├── main.go                  # Haupt-Go-Code
│       │   ├── main_test.go             # Unit Tests
│       │   ├── go.mod                   # Go Dependencies
│       │   └── README.md                # API Dokumentation
│       └── contact-form/                 # Contact Form Lambda Funktion (geplant)
├── infra/                               # Terraform Infrastructure
│   ├── main.tf                         # Hauptkonfiguration
│   └── search-api.tf                   # Search API Ressourcen
├── .github/
│   ├── workflows/
│   │   └── search-api-deploy.yml       # CI/CD Pipeline
│   └── README.md                       # GitHub Actions Setup
└── examples/
    ├── api_usage.sh                    # API Verwendungsbeispiele
    └── development_workflow.sh         # Entwicklungsworkflow
```

## 🛠️ Quick Start

### 1. Search API entwickeln

```bash
# In das Funktions-Verzeichnis wechseln
cd backend/functions/search-api

# Dependencies installieren
make deps

# Tests ausführen
make test

# API lokal bauen
make build-local
```

### 2. Deployment

```bash
# Komplettes Deployment (aus dem Funktions-Verzeichnis)
cd backend/functions/search-api
make deploy

# Oder vom Root-Verzeichnis
make deploy-all
```

### 3. API verwenden

```bash
# API-Endpunkte testen
cd backend/functions/search-api
make test-api

# Oder Beispiele ausführen
./examples/api_usage.sh
```

## 📦 Verfügbare Funktionen

### Search API
- **Status**: ✅ Verfügbar
- **Endpunkte**: 
  - `GET /search/options` - Suchoptionen abrufen
  - `POST /search` - Erweiterte Fahrzeugsuche
- **Features**: ARM64, CORS, Pagination, Filter
- **Dokumentation**: [backend/functions/search-api/README.md](backend/functions/search-api/README.md)

### Contact Form
- **Status**: 🚧 Geplant
- **Funktionalität**: Kontaktformular mit E-Mail-Versand

## 🔧 Entwicklung

### Funktions-spezifische Entwicklung (Empfohlen)

```bash
# In das Funktions-Verzeichnis wechseln
cd backend/functions/search-api

# Alle verfügbaren Commands anzeigen
make help

# Entwicklungsworkflow
make deps     # Dependencies installieren
make test     # Tests ausführen
make build    # Für Lambda bauen
make deploy   # Deployment
```

### Globale Entwicklung

```bash
# Vom Root-Verzeichnis

# Alle verfügbaren Commands anzeigen
make help

# Alle Funktionen testen
make test-all

# Komplettes Deployment
make deploy-all

# Einzelne Funktion deployieren
make deploy-function FUNCTION=search-api
```

## 🏗️ Infrastructure

### Terraform

```bash
# Terraform initialisieren
make tf-init

# Plan erstellen
make plan

# Deployment
make deploy

# Infrastructure löschen
make destroy
```

### AWS Architektur

```
Frontend ──→ API Gateway ──→ Lambda (ARM64) ──→ Data Source
                   │
                   └──→ CloudWatch Logs
```

**Komponenten:**
- **AWS Lambda**: Serverless Go-Runtime (provided.al2023)
- **API Gateway**: HTTP-Endpunkte mit CORS
- **CloudWatch**: Logging und Monitoring
- **ARM64**: Optimiert für AWS Graviton2 (~20% günstiger)

## 🚦 CI/CD Pipeline

### Automatisches Deployment

Die GitHub Actions Pipeline wird bei Änderungen in folgenden Pfaden ausgelöst:
- `backend/functions/search-api/**`
- `infra/search-api.tf`
- `infra/main.tf`

### Pipeline Stages

1. **Test**: Go-Tests, Linting, Formatierung
2. **Build**: ARM64-Binary kompilieren
3. **Plan**: Terraform Plan (nur bei Pull Requests)
4. **Deploy**: Automatisches Deployment (nur auf `main` Branch)
5. **Validate**: API-Endpunkte testen

### Setup

Benötigte GitHub Secrets:
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_ROLE_ARN (optional)
```

Siehe: [.github/README.md](.github/README.md)

## 📊 Monitoring

### CloudWatch
- **Logs**: `/aws/lambda/search-api`
- **Metriken**: Latenz, Error Rate, Memory Usage
- **Alerts**: Konfigurierbar über Terraform

### Performance
- **Cold Start**: ~100-300ms (ARM64 optimiert)
- **Warm Requests**: ~5-20ms
- **Memory**: 256MB
- **Timeout**: 30 Sekunden

## 🔒 Sicherheit

- **Public API**: Rate Limiting über API Gateway
- **CORS**: Konfiguriert für Frontend-Zugriff
- **Input Validation**: In Go-Code implementiert
- **IAM**: Minimale Permissions für Lambda-Rolle

## 📈 Skalierung

### Neue Funktionen hinzufügen

1. Ordner erstellen: `backend/functions/new-function/`
2. Makefile kopieren und anpassen
3. Terraform-Konfiguration erstellen: `infra/new-function.tf`
4. GitHub Actions Pipeline erweitern
5. Root-Makefile aktualisieren

### Multi-Region Deployment

Terraform-Module für verschiedene Regionen:
```bash
# Zukünftige Implementierung
make deploy REGION=us-east-1
make deploy REGION=eu-west-1
```

## 🛟 Troubleshooting

### Häufige Probleme

**Build-Fehler:**
```bash
cd backend/functions/search-api
make clean
make deps
make build
```

**Deployment-Fehler:**
```bash
make tf-init
make validate
make plan
```

**API-Tests fehlschlagen:**
```bash
# CloudWatch Logs prüfen
make logs

# Lokale Tests
make test-local
```

### Support

- **Issues**: GitHub Issues erstellen
- **Logs**: CloudWatch oder `make logs`
- **Lokales Debugging**: `make dev` in Funktions-Verzeichnis

## 📝 Beiträge

1. Feature Branch erstellen
2. Änderungen in entsprechendem Funktions-Verzeichnis
3. Tests hinzufügen/aktualisieren
4. Pull Request erstellen
5. Pipeline prüft automatisch

## 📄 Lizenz

MIT License - siehe LICENSE Datei

---

**Ready to build?** 🚀

```bash
# Start here:
cd backend/functions/search-api
make help
```
