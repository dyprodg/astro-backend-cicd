package main

import (
	"testing"
)

func TestGetString(t *testing.T) {
	tests := []struct {
		name     string
		data     map[string]interface{}
		key      string
		expected string
	}{
		{
			name:     "existing string value",
			data:     map[string]interface{}{"test": "value"},
			key:      "test",
			expected: "value",
		},
		{
			name:     "non-existing key",
			data:     map[string]interface{}{"other": "value"},
			key:      "test",
			expected: "",
		},
		{
			name:     "non-string value",
			data:     map[string]interface{}{"test": 123},
			key:      "test",
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := getString(tt.data, tt.key)
			if result != tt.expected {
				t.Errorf("getString() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestGetInt(t *testing.T) {
	tests := []struct {
		name     string
		data     map[string]interface{}
		key      string
		expected int
	}{
		{
			name:     "float64 value",
			data:     map[string]interface{}{"test": float64(123)},
			key:      "test",
			expected: 123,
		},
		{
			name:     "int value",
			data:     map[string]interface{}{"test": 456},
			key:      "test",
			expected: 456,
		},
		{
			name:     "non-existing key",
			data:     map[string]interface{}{"other": 789},
			key:      "test",
			expected: 0,
		},
		{
			name:     "non-numeric value",
			data:     map[string]interface{}{"test": "string"},
			key:      "test",
			expected: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := getInt(tt.data, tt.key)
			if result != tt.expected {
				t.Errorf("getInt() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestGetSubjectLabel(t *testing.T) {
	tests := []struct {
		subject  string
		expected string
	}{
		{"fahrzeug-interesse", "Interesse an einem Fahrzeug"},
		{"beratung", "Allgemeine Beratung"},
		{"finanzierung", "Finanzierung"},
		{"service", "Service & Wartung"},
		{"sonstiges", "Sonstiges"},
		{"unknown", "unknown"}, // fallback to original value
	}

	for _, tt := range tests {
		t.Run(tt.subject, func(t *testing.T) {
			result := getSubjectLabel(tt.subject)
			if result != tt.expected {
				t.Errorf("getSubjectLabel(%s) = %v, want %v", tt.subject, result, tt.expected)
			}
		})
	}
}

func TestGetZustandLabel(t *testing.T) {
	tests := []struct {
		zustand  string
		expected string
	}{
		{"sehr-gut", "Sehr gut"},
		{"gut", "Gut"},
		{"befriedigend", "Befriedigend"},
		{"reparaturbedürftig", "Reparaturbedürftig"},
		{"unknown", "unknown"}, // fallback to original value
	}

	for _, tt := range tests {
		t.Run(tt.zustand, func(t *testing.T) {
			result := getZustandLabel(tt.zustand)
			if result != tt.expected {
				t.Errorf("getZustandLabel(%s) = %v, want %v", tt.zustand, result, tt.expected)
			}
		})
	}
}
