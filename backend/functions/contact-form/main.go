package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ses"
)

// ContactFormRequest repräsentiert die Anfrage vom Kontaktformular
type ContactFormRequest struct {
	Name    string `json:"name"`
	Email   string `json:"email"`
	Phone   string `json:"phone,omitempty"`
	Subject string `json:"subject"`
	Message string `json:"message"`
}

// SellCarFormRequest repräsentiert die Anfrage vom Auto-Verkaufen-Formular
type SellCarFormRequest struct {
	// Fahrzeugdaten
	Marke          string `json:"marke"`
	Modell         string `json:"modell"`
	Baujahr        int    `json:"baujahr"`
	Kilometerstand int    `json:"kilometerstand"`
	Preis          int    `json:"preis,omitempty"`
	Zustand        string `json:"zustand"`
	// Kontaktdaten
	Name  string `json:"name"`
	Email string `json:"email"`
}

// FormRequest wrapper für beide Formulartypen
type FormRequest struct {
	FormType string                 `json:"formType"` // "contact" oder "sell-car"
	Data     map[string]interface{} `json:"data"`
}

var (
	sesClient     *ses.SES
	recipientMail string
	senderMail    string
)

func init() {
	// AWS Session initialisieren - Region wird automatisch von Lambda gesetzt
	sess := session.Must(session.NewSession())
	sesClient = ses.New(sess)

	// E-Mail-Konfiguration aus Umgebungsvariablen
	recipientMail = os.Getenv("RECIPIENT_EMAIL")
	if recipientMail == "" {
		recipientMail = "info@dennisdiepolder.com"
	}

	senderMail = os.Getenv("SENDER_EMAIL")
	if senderMail == "" {
		senderMail = "info@dennisdiepolder.com"
	}
}

// CORS Headers hinzufügen
func addCORSHeaders(response *events.APIGatewayProxyResponse) {
	if response.Headers == nil {
		response.Headers = make(map[string]string)
	}
	response.Headers["Access-Control-Allow-Origin"] = "*"
	response.Headers["Access-Control-Allow-Headers"] = "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
	response.Headers["Access-Control-Allow-Methods"] = "GET,POST,OPTIONS"
}

// Handler ist die Lambda-Funktion
func Handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	response := events.APIGatewayProxyResponse{}
	addCORSHeaders(&response)

	// OPTIONS Request für CORS
	if request.HTTPMethod == "OPTIONS" {
		response.StatusCode = 200
		return response, nil
	}

	// Nur POST erlauben
	if request.HTTPMethod != "POST" {
		response.StatusCode = 405
		response.Body = `{"error":"Method not allowed"}`
		return response, nil
	}

	// Request Body parsen
	var formReq FormRequest
	if err := json.Unmarshal([]byte(request.Body), &formReq); err != nil {
		log.Printf("Error parsing request body: %v", err)
		response.StatusCode = 400
		response.Body = `{"error":"Invalid request body"}`
		return response, nil
	}

	// Je nach Formulartyp verarbeiten
	switch formReq.FormType {
	case "contact":
		return handleContactForm(formReq.Data)
	case "sell-car":
		return handleSellCarForm(formReq.Data)
	default:
		response.StatusCode = 400
		response.Body = `{"error":"Unknown form type"}`
		return response, nil
	}
}

// handleContactForm verarbeitet das Kontaktformular
func handleContactForm(data map[string]interface{}) (events.APIGatewayProxyResponse, error) {
	response := events.APIGatewayProxyResponse{}
	addCORSHeaders(&response)

	// Daten extrahieren
	name := getString(data, "name")
	email := getString(data, "email")
	phone := getString(data, "phone")
	subject := getString(data, "subject")
	message := getString(data, "message")

	// Validierung
	if name == "" || email == "" || subject == "" || message == "" {
		response.StatusCode = 400
		response.Body = `{"error":"Missing required fields"}`
		return response, nil
	}

	// E-Mail-Body erstellen
	emailSubject := fmt.Sprintf("Neue Kontaktanfrage: %s", subject)
	emailBody := formatContactEmail(name, email, phone, subject, message)

	// E-Mail senden
	if err := sendEmail(emailSubject, emailBody, email); err != nil {
		log.Printf("Error sending email: %v", err)
		response.StatusCode = 500
		response.Body = `{"error":"Failed to send email"}`
		return response, nil
	}

	response.StatusCode = 200
	response.Body = `{"success":true,"message":"Email sent successfully"}`
	return response, nil
}

// handleSellCarForm verarbeitet das Auto-Verkaufen-Formular
func handleSellCarForm(data map[string]interface{}) (events.APIGatewayProxyResponse, error) {
	response := events.APIGatewayProxyResponse{}
	addCORSHeaders(&response)

	// Daten extrahieren
	marke := getString(data, "marke")
	modell := getString(data, "modell")
	baujahr := getInt(data, "baujahr")
	kilometerstand := getInt(data, "kilometerstand")
	preis := getInt(data, "preis")
	zustand := getString(data, "zustand")
	name := getString(data, "name")
	email := getString(data, "email")

	// Validierung
	if marke == "" || modell == "" || baujahr == 0 || kilometerstand == 0 || zustand == "" || name == "" || email == "" {
		response.StatusCode = 400
		response.Body = `{"error":"Missing required fields"}`
		return response, nil
	}

	// E-Mail-Body erstellen
	emailSubject := fmt.Sprintf("Auto-Verkaufsanfrage: %s %s (%d)", marke, modell, baujahr)
	emailBody := formatSellCarEmail(marke, modell, baujahr, kilometerstand, preis, zustand, name, email)

	// E-Mail senden
	if err := sendEmail(emailSubject, emailBody, email); err != nil {
		log.Printf("Error sending email: %v", err)
		response.StatusCode = 500
		response.Body = `{"error":"Failed to send email"}`
		return response, nil
	}

	response.StatusCode = 200
	response.Body = `{"success":true,"message":"Email sent successfully"}`
	return response, nil
}

// formatContactEmail formatiert die Kontakt-E-Mail
func formatContactEmail(name, email, phone, subject, message string) string {
	timestamp := time.Now().Format("02.01.2006 15:04:05")

	html := fmt.Sprintf(`
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #0c1117; color: #d97706; padding: 20px; text-align: center; }
        .content { background-color: #f5f5f5; padding: 20px; margin-top: 20px; }
        .field { margin-bottom: 15px; }
        .label { font-weight: bold; color: #0c1117; }
        .value { margin-left: 10px; }
        .message-box { background-color: white; padding: 15px; border-left: 4px solid #d97706; margin-top: 20px; }
        .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Neue Kontaktanfrage</h1>
            <p>Autosalon Volketswil</p>
        </div>
        
        <div class="content">
            <div class="field">
                <span class="label">Datum/Zeit:</span>
                <span class="value">%s</span>
            </div>
            
            <div class="field">
                <span class="label">Name:</span>
                <span class="value">%s</span>
            </div>
            
            <div class="field">
                <span class="label">E-Mail:</span>
                <span class="value"><a href="mailto:%s">%s</a></span>
            </div>
            
            %s
            
            <div class="field">
                <span class="label">Betreff:</span>
                <span class="value">%s</span>
            </div>
            
            <div class="message-box">
                <h3>Nachricht:</h3>
                <p>%s</p>
            </div>
        </div>
        
        <div class="footer">
            <p>Diese E-Mail wurde automatisch vom Kontaktformular auf autosalonvolketswil.ch generiert.</p>
            <p>Bitte antworten Sie direkt an die angegebene E-Mail-Adresse des Kunden.</p>
        </div>
    </div>
</body>
</html>
`, timestamp, name, email, email,
		func() string {
			if phone != "" {
				return fmt.Sprintf(`<div class="field"><span class="label">Telefon:</span><span class="value">%s</span></div>`, phone)
			}
			return ""
		}(),
		getSubjectLabel(subject),
		strings.ReplaceAll(message, "\n", "<br>"))

	return html
}

// formatSellCarEmail formatiert die Auto-Verkaufs-E-Mail
func formatSellCarEmail(marke, modell string, baujahr, kilometerstand, preis int, zustand, name, email string) string {
	timestamp := time.Now().Format("02.01.2006 15:04:05")

	preisStr := "Nicht angegeben"
	if preis > 0 {
		preisStr = fmt.Sprintf("CHF %d.-", preis)
	}

	html := fmt.Sprintf(`
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #0c1117; color: #d97706; padding: 20px; text-align: center; }
        .content { background-color: #f5f5f5; padding: 20px; margin-top: 20px; }
        .section { background-color: white; padding: 15px; margin-bottom: 20px; border-left: 4px solid #d97706; }
        .field { margin-bottom: 10px; }
        .label { font-weight: bold; color: #0c1117; display: inline-block; width: 150px; }
        .value { margin-left: 10px; }
        .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #666; }
        h3 { color: #d97706; margin-bottom: 15px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Auto-Verkaufsanfrage</h1>
            <p>Autosalon Volketswil</p>
        </div>
        
        <div class="content">
            <div class="field">
                <span class="label">Datum/Zeit:</span>
                <span class="value">%s</span>
            </div>
            
            <div class="section">
                <h3>Fahrzeugdaten</h3>
                <div class="field">
                    <span class="label">Marke:</span>
                    <span class="value">%s</span>
                </div>
                <div class="field">
                    <span class="label">Modell:</span>
                    <span class="value">%s</span>
                </div>
                <div class="field">
                    <span class="label">Baujahr:</span>
                    <span class="value">%d</span>
                </div>
                <div class="field">
                    <span class="label">Kilometerstand:</span>
                    <span class="value">%d km</span>
                </div>
                <div class="field">
                    <span class="label">Gewünschter Preis:</span>
                    <span class="value">%s</span>
                </div>
                <div class="field">
                    <span class="label">Zustand:</span>
                    <span class="value">%s</span>
                </div>
            </div>
            
            <div class="section">
                <h3>Kontaktdaten</h3>
                <div class="field">
                    <span class="label">Name:</span>
                    <span class="value">%s</span>
                </div>
                <div class="field">
                    <span class="label">E-Mail:</span>
                    <span class="value"><a href="mailto:%s">%s</a></span>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>Diese Anfrage wurde über das Auto-Verkaufsformular auf autosalonvolketswil.ch gesendet.</p>
            <p>Bitte kontaktieren Sie den Kunden innerhalb von 24 Stunden.</p>
        </div>
    </div>
</body>
</html>
`, timestamp, marke, modell, baujahr, kilometerstand, preisStr, getZustandLabel(zustand), name, email, email)

	return html
}

// sendEmail sendet die E-Mail über AWS SES
func sendEmail(subject, body, replyTo string) error {
	input := &ses.SendEmailInput{
		Destination: &ses.Destination{
			ToAddresses: []*string{aws.String(recipientMail)},
		},
		Message: &ses.Message{
			Body: &ses.Body{
				Html: &ses.Content{
					Charset: aws.String("UTF-8"),
					Data:    aws.String(body),
				},
			},
			Subject: &ses.Content{
				Charset: aws.String("UTF-8"),
				Data:    aws.String(subject),
			},
		},
		Source:           aws.String(senderMail),
		ReplyToAddresses: []*string{aws.String(replyTo)},
	}

	_, err := sesClient.SendEmail(input)
	return err
}

// Hilfsfunktionen
func getString(data map[string]interface{}, key string) string {
	if val, ok := data[key]; ok {
		if str, ok := val.(string); ok {
			return str
		}
	}
	return ""
}

func getInt(data map[string]interface{}, key string) int {
	if val, ok := data[key]; ok {
		switch v := val.(type) {
		case float64:
			return int(v)
		case int:
			return v
		}
	}
	return 0
}

func getSubjectLabel(subject string) string {
	labels := map[string]string{
		"fahrzeug-interesse": "Interesse an einem Fahrzeug",
		"beratung":           "Allgemeine Beratung",
		"finanzierung":       "Finanzierung",
		"service":            "Service & Wartung",
		"sonstiges":          "Sonstiges",
	}
	if label, ok := labels[subject]; ok {
		return label
	}
	return subject
}

func getZustandLabel(zustand string) string {
	labels := map[string]string{
		"sehr-gut":           "Sehr gut",
		"gut":                "Gut",
		"befriedigend":       "Befriedigend",
		"reparaturbedürftig": "Reparaturbedürftig",
	}
	if label, ok := labels[zustand]; ok {
		return label
	}
	return zustand
}

func main() {
	lambda.Start(Handler)
}
