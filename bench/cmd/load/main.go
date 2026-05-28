package main

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"sort"
	"sync"
	"sync/atomic"
	"time"
)

func main() {
	url := flag.String("url", "http://localhost:8080/api/strings/Helidon", "URL to call")
	concurrency := flag.Int("concurrency", 100, "number of concurrent workers")
	requests := flag.Int("requests", 100000, "measured request count")
	warmup := flag.Int("warmup", 1000, "warmup request count")
	flag.Parse()

	client := &http.Client{Timeout: 10 * time.Second}
	run(client, *url, *concurrency, *warmup, false)
	result := run(client, *url, *concurrency, *requests, true)
	printResult(result)
}

type result struct {
	requests     int
	failures     int64
	elapsed      time.Duration
	latencies    []time.Duration
	firstFailure string
}

func run(client *http.Client, url string, concurrency int, requests int, measured bool) result {
	if requests <= 0 {
		return result{}
	}
	if concurrency <= 0 {
		concurrency = 1
	}

	jobs := make(chan int)
	latencies := make([]time.Duration, 0, requests)
	var latencyMu sync.Mutex
	var failures int64
	var firstFailure string
	var firstFailureMu sync.Mutex
	var wg sync.WaitGroup

	start := time.Now()
	for i := 0; i < concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range jobs {
				requestStart := time.Now()
				if err := call(client, url); err != nil {
					atomic.AddInt64(&failures, 1)
					firstFailureMu.Lock()
					if firstFailure == "" {
						firstFailure = err.Error()
					}
					firstFailureMu.Unlock()
				}
				if measured {
					latencyMu.Lock()
					latencies = append(latencies, time.Since(requestStart))
					latencyMu.Unlock()
				}
			}
		}()
	}

	for i := 0; i < requests; i++ {
		jobs <- i
	}
	close(jobs)
	wg.Wait()

	return result{
		requests:     requests,
		failures:     failures,
		elapsed:      time.Since(start),
		latencies:    latencies,
		firstFailure: firstFailure,
	}
}

func call(client *http.Client, url string) error {
	response, err := client.Get(url)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	_, _ = io.Copy(io.Discard, response.Body)
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("status %d", response.StatusCode)
	}
	return nil
}

func printResult(result result) {
	sort.Slice(result.latencies, func(i, j int) bool {
		return result.latencies[i] < result.latencies[j]
	})

	seconds := result.elapsed.Seconds()
	rps := float64(result.requests) / seconds
	fmt.Printf("requests=%d\n", result.requests)
	fmt.Printf("failures=%d\n", result.failures)
	if result.firstFailure != "" {
		fmt.Printf("firstFailure=%s\n", result.firstFailure)
	}
	fmt.Printf("elapsed=%s\n", result.elapsed)
	fmt.Printf("requestsPerSecond=%.2f\n", rps)
	fmt.Printf("p50=%s\n", percentile(result.latencies, 50))
	fmt.Printf("p95=%s\n", percentile(result.latencies, 95))
	fmt.Printf("p99=%s\n", percentile(result.latencies, 99))
}

func percentile(values []time.Duration, p int) time.Duration {
	if len(values) == 0 {
		return 0
	}
	index := (len(values)*p + 99) / 100
	if index < 1 {
		index = 1
	}
	if index > len(values) {
		index = len(values)
	}
	return values[index-1]
}
