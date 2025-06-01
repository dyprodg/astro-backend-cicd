# GitHub Actions CI/CD Setup

Dieses Repository verwendet GitHub Actions für automatisierte Tests und Deployment der Search API.

## 🚀 Workflow Übersicht

### Search API Deploy Pipeline (`.github/workflows/search-api-deploy.yml`)

Die Pipeline wird bei folgenden Events ausgelöst:
- **Push** auf `main` oder `develop` Branch
- **Pull Request** auf `main` Branch
- Nur wenn Dateien in folgenden Pfaden geändert werden:
  - `backend/functions/search-api/**`
  - `infra/search-api.tf`
  - `infra/main.tf`

## 📋 Pipeline Stages

### 1. Test (`test`)
- Go-Code formatierung prüfen
- Unit Tests ausführen
- Linting mit `go vet`
- Test Coverage generieren
- Coverage Report an Codecov senden

### 2. Build (`build`)
- Lambda Binary für ARM64 kompilieren
- Deployment ZIP erstellen
- Build Artifact hochladen

### 3. Terraform Plan (`terraform-plan`)
- **Nur für Pull Requests**
- Terraform Plan erstellen
- Plan als PR Comment hinzufügen

### 4. Deploy (`deploy`)
- **Nur für Push auf `main` Branch**
- Terraform Apply ausführen
- API Endpoints testen
- Deployment Summary erstellen

### 5. Cleanup (`cleanup`)
- Build Artifacts aufräumen

## 🔑 Benötigte GitHub Secrets

Füge folgende Secrets in den Repository Settings hinzu:

### AWS Credentials
```
AWS_ACCESS_KEY_ID        # AWS Access Key ID
AWS_SECRET_ACCESS_KEY    # AWS Secret Access Key
AWS_ROLE_ARN            # Optional: IAM Role ARN für AssumeRole
```

### Konfiguration der AWS Credentials

#### Option 1: IAM User (Direkt)
```bash
# AWS_ACCESS_KEY_ID und AWS_SECRET_ACCESS_KEY vom IAM User
```

#### Option 2: IAM Role (Empfohlen)
```bash
# AWS_ROLE_ARN: arn:aws:iam::ACCOUNT-ID:role/GitHubActions-Role
# AWS_ACCESS_KEY_ID und AWS_SECRET_ACCESS_KEY von einem User mit AssumeRole-Berechtigung
```

## 🛠️ Setup IAM Permissions

### Minimal IAM Policy für Deployment
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:*",
                "apigateway:*",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:GetRole",
                "iam:PassRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "logs:CreateLogGroup",
                "logs:DeleteLogGroup",
                "logs:DescribeLogGroups",
                "logs:PutRetentionPolicy",
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketVersioning",
                "s3:GetBucketLocation",
                "s3:ListBucket",
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::astro-preset-terraform-state",
                "arn:aws:s3:::astro-preset-terraform-state/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/terraform-locks"
        }
    ]
}
```

## 📊 Monitoring und Debugging

### Workflow Status
- Gehe zu **Actions** Tab im Repository
- Klicke auf den entsprechenden Workflow Run
- Sieh dir die Logs jeder Stage an

### Debug Steps
1. **Tests fehlschlagen**: Prüfe Go-Code Formatierung und Unit Tests
2. **Build fehlschlägt**: Überprüfe Go Dependencies
3. **Terraform Plan/Apply fehlschlägt**: Prüfe AWS Credentials und Permissions
4. **Deployment Tests fehlschlagen**: Prüfe API Gateway und Lambda Configuration

### Lokales Debugging
```bash
# Lokale Tests ausführen
make test

# Lokalen Build testen
make build-local

# Terraform Plan lokal ausführen
make plan
```

## 🔄 Entwicklungsworkflow

### Für Feature Development
1. Erstelle einen Feature Branch
2. Entwickle in `backend/functions/search-api/`
3. Erstelle einen Pull Request
4. Pipeline läuft automatisch (Test + Plan)
5. Review und Merge

### Für Hotfixes
1. Erstelle einen Hotfix Branch von `main`
2. Implementiere den Fix
3. Erstelle einen Pull Request
4. Nach Review: Merge in `main`
5. Deployment erfolgt automatisch

## 📈 Performance Optimierungen

### ARM64 Benefits
- **Preis**: ~20% günstiger als x86_64
- **Performance**: Bessere Performance bei vielen Workloads
- **Energie**: Geringerer Energieverbrauch

### Pipeline Optimierungen
- **Caching**: Go Modules werden gecacht
- **Parallel Jobs**: Tests und Build laufen parallel
- **Conditional Deployment**: Nur bei Änderungen in relevanten Dateien
- **Artifact Cleanup**: Automatische Bereinigung alter Artifacts

## 🚨 Troubleshooting

### Häufige Probleme

#### "No such file or directory: bootstrap"
```bash
# Stelle sicher, dass der Build-Step erfolgreich war
# Überprüfe die Build-Konfiguration im Makefile
```

#### "Access Denied" beim Terraform Apply
```bash
# Überprüfe AWS Credentials und IAM Permissions
# Stelle sicher, dass der S3 Bucket für Terraform State existiert
```

#### "Lambda function does not exist"
```bash
# Führe erst `terraform apply` aus, bevor du die Lambda-Funktion aktualisierst
```

### Support
- Erstelle ein Issue im Repository
- Überprüfe die Workflow-Logs in GitHub Actions
- Teste lokal mit `make dev` 