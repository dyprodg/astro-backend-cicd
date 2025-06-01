# GitHub Actions CI/CD Setup

Dieses Repository verwendet GitHub Actions für automatisierte Tests und Deployment der Search API.

## 🚀 Workflow Übersicht

### Search API Deploy Pipeline (`.github/workflows/search-api-deploy.yml`)

Die Pipeline wird bei folgenden Events ausgelöst:
- **Push** auf `main` oder `develop` Branch
- **Pull Request** auf `main` Branch
- Nur wenn Dateien in folgenden Pfaden geändert werden:
  - `backend/functions/search-api/**`
  - `.github/workflows/search-api-deploy.yml`

## 📋 Pipeline Stages

### 1. Test (`test`)
- Go-Code Formatierung prüfen
- Unit Tests mit Coverage ausführen
- Linting mit `go vet`
- Coverage Reports zu S3 hochladen

### 2. Deploy (`deploy`)
- **Nur für Push auf `main` Branch**
- Lambda Binary für ARM64 kompilieren
- ZIP erstellen und Lambda Function aktualisieren
- API Endpoints testen
- Deployment Summary erstellen

## 🔐 OIDC Authentifizierung (Empfohlen)

Die Pipeline verwendet **OpenID Connect (OIDC)** für sichere AWS-Authentifizierung ohne Keys.

### Benötigte GitHub Secrets
```
AWS_ACCOUNT_ID    # Deine AWS Account ID
```

### Verwendete IAM Role
```
arn:aws:iam::{AWS_ACCOUNT_ID}:role/astro-backend-cicd-role
```

## 🛠️ IAM Role Setup

Die Pipeline nutzt die **gleiche IAM Role** wie das Frontend:

### IAM Role Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject", 
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::astro-frontend-bucket",
        "arn:aws:s3:::astro-frontend-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:GetFunction",
        "lambda:ListFunctions"
      ],
      "Resource": [
        "arn:aws:lambda:eu-central-1:*:function:search-api"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::astro-backend-search-api-coverage",
        "arn:aws:s3:::astro-backend-search-api-coverage/*"
      ]
    }
  ]
}
```

## 📊 Coverage Reports

### S3 Bucket für Coverage
- **Bucket**: `astro-backend-search-api-coverage`
- **Format**: `coverage-YYYYMMDD-HHMMSS.html`
- **Lifecycle**: Dateien werden nach 30 Tagen automatisch gelöscht

### Coverage Zugriff
Coverage Reports sind nach jedem Deployment verfügbar:
- **URL**: `https://astro-backend-search-api-coverage.s3.eu-central-1.amazonaws.com/coverage-{timestamp}.html`
- **Link**: Wird im Pipeline Summary angezeigt

## 🏗️ Infrastructure vs. Code Deployment

### Code Deployment (Pipeline)
✅ **Was die Pipeline macht:**
- Go Tests ausführen
- Lambda Code aktualisieren
- Coverage Reports hochladen
- API Endpunkte testen

### Infrastructure (Lokal)
🏠 **Was lokal gemacht wird:**
- Terraform Setup (`make deploy`)
- S3 Bucket erstellen
- Lambda Funktion initial erstellen
- API Gateway Setup

## 📊 Monitoring und Debugging

### Workflow Status
- Gehe zu **Actions** Tab im Repository
- Klicke auf den entsprechenden Workflow Run
- Sieh dir die Logs jeder Stage an

### Debug Steps
1. **Tests fehlschlagen**: Prüfe Go-Code und lokale Tests mit `make test`
2. **OIDC Fehler**: Prüfe AWS_ACCOUNT_ID Secret und IAM Role
3. **Lambda Update fehlschlägt**: Prüfe IAM Permissions für Lambda
4. **S3 Upload fehlschlägt**: Prüfe S3 Bucket Permissions

### Lokales Debugging
```bash
# In das Funktions-Verzeichnis wechseln
cd backend/functions/search-api

# Lokale Tests ausführen
make test
make test-cover

# Lokalen Build testen  
make build-local

# Lambda Update testen (wenn AWS CLI konfiguriert)
make update-lambda
```

## 🔄 Entwicklungsworkflow

### Für Feature Development
1. Erstelle einen Feature Branch
2. Entwickle in `backend/functions/search-api/`
3. Lokale Tests: `cd backend/functions/search-api && make test`
4. Erstelle einen Pull Request
5. Pipeline läuft automatisch (nur Tests)
6. Review und Merge
7. Deployment erfolgt automatisch bei Merge auf `main`

### Für Hotfixes
1. Erstelle einen Hotfix Branch von `main`
2. Implementiere den Fix
3. Lokale Tests ausführen
4. Pull Request erstellen
5. Nach Review: Merge in `main`
6. Automatisches Deployment

## 📈 Performance Optimierungen

### Pipeline Benefits
- **OIDC**: Keine AWS Keys nötig - sicherer
- **Caching**: Go Modules werden gecacht
- **Selective Deployment**: Nur bei Code-Änderungen
- **Schnelle Updates**: Nur Lambda Code, keine Infrastructure

### ARM64 Benefits  
- **Kosten**: ~20% günstiger als x86_64
- **Performance**: Bessere Performance bei vielen Workloads
- **Cold Start**: Schnellere Invoke-Zeiten

## 🚨 Troubleshooting

### Häufige Probleme

#### OIDC "Access Denied"
```bash
# Prüfe IAM Role und Trust Policy
# Stelle sicher, dass AWS_ACCOUNT_ID korrekt ist
```

#### "Lambda function does not exist"
```bash
# Führe erst lokales Infrastructure Setup aus:
cd infra
terraform init
terraform apply
```

#### S3 "NoSuchBucket"
```bash
# S3 Bucket muss via Terraform erstellt werden:
cd infra
terraform apply
```

#### Coverage Upload fehlschlägt
```bash
# Prüfe S3 Permissions in IAM Role
# Stelle sicher, dass Bucket existiert
```

### Lokale Entwicklung

#### Vollständiger lokaler Test-Workflow
```bash
# 1. Setup
cd backend/functions/search-api
make deps

# 2. Entwicklung
make fmt
make lint  
make test-cover

# 3. Build und Deploy
make build
make update-lambda
make test-api

# 4. Logs prüfen
make logs
```

## 🎯 Best Practices

### Code Quality
- Immer lokale Tests vor Push: `make test`
- Code formatieren: `make fmt`
- Linting prüfen: `make lint`
- Coverage beachten: `make test-cover`

### Deployment
- Kleine, inkrementelle Änderungen
- Feature Branches für neue Features
- Pull Requests für Code Review
- Merge nur nach erfolgreichen Tests

### Security
- Keine AWS Keys in Code oder Secrets
- OIDC für sichere Authentifizierung
- Minimale IAM Permissions
- Regelmäßige Dependency Updates 