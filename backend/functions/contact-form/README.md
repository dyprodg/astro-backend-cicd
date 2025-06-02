# Contact Form Lambda Function

Diese Lambda-Funktion verarbeitet Kontaktformular-Anfragen von der Autosalon Volketswil Website und sendet sie als formatierte E-Mails via AWS SES.

## Features

- 📧 Verarbeitet zwei Formulartypen: Kontaktformular und Auto-Verkaufen-Formular
- 🎨 Sendet schön formatierte HTML E-Mails mit Branding
- 🛡️ Rate Limiting zum Schutz vor Spam
- ⚡ Schnelle Antwortzeiten durch Go und ARM64 Architektur
- 🔄 Automatische CORS-Unterstützung

## API Endpoint

```
POST /contact
Content-Type: application/json
```

### Request Format

#### Kontaktformular
```json
{
  "formType": "contact",
  "data": {
    "name": "Max Mustermann",
    "email": "max@example.com",
    "phone": "+41 79 123 45 67", // optional
    "subject": "fahrzeug-interesse",
    "message": "Ich interessiere mich für..."
  }
}
```

#### Auto-Verkaufen-Formular
```json
{
  "formType": "sell-car",
  "data": {
    "marke": "BMW",
    "modell": "320i",
    "baujahr": 2020,
    "kilometerstand": 50000,
    "preis": 25000, // optional
    "zustand": "sehr-gut",
    "name": "Max Mustermann",
    "email": "max@example.com"
  }
}
```

### Subject Options (Kontaktformular)
- `fahrzeug-interesse` - Interesse an einem Fahrzeug
- `beratung` - Allgemeine Beratung
- `finanzierung` - Finanzierung
- `service` - Service & Wartung
- `sonstiges` - Sonstiges

### Zustand Options (Auto-Verkaufen)
- `sehr-gut` - Sehr gut
- `gut` - Gut
- `befriedigend` - Befriedigend
- `reparaturbedürftig` - Reparaturbedürftig

## Development

### Prerequisites
- Go 1.21 oder höher
- AWS CLI konfiguriert
- Make

### Commands

```bash
# Dependencies installieren
make deps

# Tests ausführen
make test

# Code formatieren
make fmt

# Linter ausführen
make lint

# Lambda bauen
make build

# Lambda deployen (benötigt AWS Credentials)
make update-lambda
```

## Deployment

Die Lambda wird automatisch via GitHub Actions deployed wenn Code in den `main` Branch gepusht wird.

### Manuelle Deployment

1. AWS Credentials konfigurieren
2. `make update-lambda` ausführen

## Environment Variables

- `SENDER_EMAIL` - SES verifizierte Sender E-Mail (default: noreply@autosalonvolketswil.ch)
- `RECIPIENT_EMAIL` - E-Mail-Adresse des Empfängers (default: Verkauf@autosalonvolketswil.ch)
- `AWS_REGION` - AWS Region für SES

## AWS SES Setup

⚠️ **Wichtig**: Beide E-Mail-Adressen (Sender und Empfänger) müssen in AWS SES verifiziert werden!

1. In AWS Console zu SES navigieren
2. "Email Addresses" → "Verify a New Email Address"
3. Beide E-Mail-Adressen verifizieren
4. Bestätigungs-E-Mails checken und Links klicken

## Testing

### Lokaler Test mit curl

```bash
# Kontaktformular Test
curl -X POST https://YOUR_API_ID.execute-api.eu-central-1.amazonaws.com/prod/contact \
  -H "Content-Type: application/json" \
  -d '{
    "formType": "contact",
    "data": {
      "name": "Test User",
      "email": "test@example.com",
      "subject": "beratung",
      "message": "Dies ist eine Testnachricht."
    }
  }'
```

## Monitoring

- CloudWatch Logs: `/aws/lambda/contact-form`
- CloudWatch Alarm bei hoher Fehlerrate
- API Gateway Metrics für Request Count und Latency

## Security

- Rate Limiting: 10 requests/second, 1000 requests/day
- Nur POST requests erlaubt
- Input Validierung für alle Felder
- SES mit eingeschränkten Permissions (nur spezifische Sender-Adresse) 