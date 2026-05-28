package main

import (
	"encoding/json"
	"fmt"
	"hash/crc32"
	"log"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"time"
)

type stringResponse struct {
	Input      string `json:"input"`
	Uppercase  string `json:"uppercase"`
	Lowercase  string `json:"lowercase"`
	Reversed   string `json:"reversed"`
	Hash       uint64 `json:"hash"`
	Runtime    string `json:"runtime"`
	Language   string `json:"language"`
	LogEnabled bool   `json:"logEnabled"`
}

func main() {
	port := env("PORT", "8080")
	logRequests := envBool("LOG_REQUESTS", false)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]string{"status": "UP", "runtime": runtime.Version()})
	})
	mux.HandleFunc("GET /ready", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]string{"status": "READY"})
	})
	mux.HandleFunc("GET /api/strings/{value}", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		value := r.PathValue("value")
		result := transform(value, logRequests)
		if logRequests {
			log.Printf("path=%s input=%q elapsed=%s", r.URL.Path, value, time.Since(start))
		}
		writeJSON(w, result)
	})

	addr := ":" + port
	log.Printf("go service listening on http://localhost%s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}

func transform(value string, logEnabled bool) stringResponse {
	return stringResponse{
		Input:      value,
		Uppercase:  strings.ToUpper(value),
		Lowercase:  strings.ToLower(value),
		Reversed:   reverse(value),
		Hash:       stableHash(value),
		Runtime:    runtime.Version(),
		Language:   "go",
		LogEnabled: logEnabled,
	}
}

func reverse(value string) string {
	runes := []rune(value)
	for left, right := 0, len(runes)-1; left < right; left, right = left+1, right-1 {
		runes[left], runes[right] = runes[right], runes[left]
	}
	return string(runes)
}

func stableHash(value string) uint64 {
	return uint64(crc32.ChecksumIEEE([]byte(value)))
}

func writeJSON(w http.ResponseWriter, value any) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(value); err != nil {
		http.Error(w, fmt.Sprintf("encode response: %v", err), http.StatusInternalServerError)
	}
}

func env(name string, fallback string) string {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback
	}
	return value
}

func envBool(name string, fallback bool) bool {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}
