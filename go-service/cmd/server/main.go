package main

import (
	"encoding/json"
	"fmt"
	"hash/crc32"
	"log"
	"net/http"
	"os"
	"runtime"
	"runtime/debug"
	"strconv"
	"strings"
	"time"
)

var serviceRuntime = runtime.Version()

type stringResponse struct {
	Input       string      `json:"input"`
	Uppercase   string      `json:"uppercase"`
	Lowercase   string      `json:"lowercase"`
	Reversed    string      `json:"reversed"`
	Hash        uint64      `json:"hash"`
	WorkFactor  int         `json:"workFactor"`
	WorkScore   uint64      `json:"workScore"`
	Runtime     string      `json:"runtime"`
	Language    string      `json:"language"`
	LogEnabled  bool        `json:"logEnabled"`
	RuntimeInfo runtimeInfo `json:"runtimeInfo"`
}

type healthResponse struct {
	Status      string      `json:"status"`
	Runtime     string      `json:"runtime"`
	Language    string      `json:"language"`
	RuntimeInfo runtimeInfo `json:"runtimeInfo"`
}

type readyResponse struct {
	Status string `json:"status"`
}

type runtimeInfo struct {
	NumCPU           int    `json:"numCPU"`
	GOMAXPROCS       int    `json:"gomaxprocs"`
	MemoryLimitBytes int64  `json:"memoryLimitBytes"`
	ServerModel      string `json:"serverModel"`
}

func main() {
	port := env("PORT", "8080")
	logRequests := envBool("LOG_REQUESTS", false)
	workFactor := envInt("WORK_FACTOR", 1)
	info := currentRuntimeInfo()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, healthResponse{
			Status:      "UP",
			Runtime:     serviceRuntime,
			Language:    "go",
			RuntimeInfo: info,
		})
	})
	mux.HandleFunc("GET /ready", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, readyResponse{Status: "READY"})
	})
	mux.HandleFunc("GET /api/strings/{value}", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		value := r.PathValue("value")
		result := transform(value, logRequests, workFactor, info)
		if logRequests {
			log.Printf("path=%s input=%q elapsed=%s", r.URL.Path, value, time.Since(start))
		}
		writeJSON(w, result)
	})
	mux.HandleFunc("GET /api/generated/{size}", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		size := pathInt(r, "size", len("Helidon"))
		value := generatedValue(size)
		result := transform(value, logRequests, workFactor, info)
		if logRequests {
			log.Printf("path=%s size=%d elapsed=%s", r.URL.Path, size, time.Since(start))
		}
		writeJSON(w, result)
	})

	addr := ":" + port
	server := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	log.Printf("go service listening on http://localhost%s gomaxprocs=%d numCPU=%d workFactor=%d", addr, info.GOMAXPROCS, info.NumCPU, workFactor)
	if err := server.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}

func transform(value string, logEnabled bool, workFactor int, info runtimeInfo) stringResponse {
	uppercase := strings.ToUpper(value)
	lowercase := strings.ToLower(value)
	reversed := reverse(value)
	return stringResponse{
		Input:       value,
		Uppercase:   uppercase,
		Lowercase:   lowercase,
		Reversed:    reversed,
		Hash:        stableHash(value),
		WorkFactor:  workFactor,
		WorkScore:   extraWork(uppercase, lowercase, reversed, workFactor),
		Runtime:     serviceRuntime,
		Language:    "go",
		LogEnabled:  logEnabled,
		RuntimeInfo: info,
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

func extraWork(uppercase string, lowercase string, reversed string, workFactor int) uint64 {
	if workFactor < 1 {
		workFactor = 1
	}
	crc := crc32.NewIEEE()
	for i := 0; i < workFactor; i++ {
		_, _ = crc.Write([]byte(uppercase))
		_, _ = crc.Write([]byte(lowercase))
		_, _ = crc.Write([]byte(reversed))
	}
	return uint64(crc.Sum32())
}

func currentRuntimeInfo() runtimeInfo {
	return runtimeInfo{
		NumCPU:           runtime.NumCPU(),
		GOMAXPROCS:       runtime.GOMAXPROCS(0),
		MemoryLimitBytes: debug.SetMemoryLimit(-1),
		ServerModel:      "net/http goroutine-per-connection/request",
	}
}

func writeJSON(w http.ResponseWriter, value any) {
	data, err := json.Marshal(value)
	if err != nil {
		http.Error(w, fmt.Sprintf("encode response: %v", err), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Content-Length", strconv.Itoa(len(data)))
	if _, err := w.Write(data); err != nil {
		log.Printf("write response: %v", err)
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

func envInt(name string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 1 {
		return fallback
	}
	return parsed
}

func pathInt(r *http.Request, name string, fallback int) int {
	value := strings.TrimSpace(r.PathValue(name))
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 1 || parsed > 65536 {
		return fallback
	}
	return parsed
}

func generatedValue(size int) string {
	if size == len("Helidon") {
		return "Helidon"
	}
	return strings.Repeat("x", size)
}
