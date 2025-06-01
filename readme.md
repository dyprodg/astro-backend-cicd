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
