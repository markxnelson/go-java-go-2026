package main

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"runtime"
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
	duration := flag.Duration("duration", 0, "measured run duration; when set, requests is ignored")
	warmupDuration := flag.Duration("warmup-duration", 0, "warmup duration; when set, warmup is ignored")
	timeout := flag.Duration("timeout", 10*time.Second, "per-request timeout")
	flag.Parse()

	client := &http.Client{
		Timeout:   *timeout,
		Transport: transportFor(*concurrency),
	}
	warmupRequests := *warmup
	if *warmupDuration > 0 {
		warmupRequests = 0
	}
	run(client, *url, *concurrency, warmupRequests, *warmupDuration, false)

	measuredRequests := *requests
	if *duration > 0 {
		measuredRequests = 0
	}
	result := run(client, *url, *concurrency, measuredRequests, *duration, true)
	printResult(result)
}

type result struct {
	requests     int
	failures     int64
	elapsed      time.Duration
	latencies    []time.Duration
	firstFailure string
}

func run(client *http.Client, url string, concurrency int, requests int, duration time.Duration, measured bool) result {
	if requests <= 0 && duration <= 0 {
		return result{}
	}
	if concurrency <= 0 {
		concurrency = 1
	}

	startGate := make(chan struct{})
	workerLatencies := make([][]time.Duration, concurrency)
	var failures int64
	var firstFailure string
	var firstFailureMu sync.Mutex
	var completed int64
	var next int64
	var wg sync.WaitGroup

	start := time.Now()
	for i := 0; i < concurrency; i++ {
		wg.Add(1)
		go func(worker int) {
			defer wg.Done()
			localLatencies := make([]time.Duration, 0, requestsForWorker(requests, concurrency))
			<-startGate
			deadline := time.Time{}
			if duration > 0 {
				deadline = start.Add(duration)
			}
			for {
				if requests > 0 {
					if atomic.AddInt64(&next, 1) > int64(requests) {
						break
					}
				} else if time.Now().After(deadline) {
					break
				}

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
					localLatencies = append(localLatencies, time.Since(requestStart))
				}
				atomic.AddInt64(&completed, 1)
			}
			workerLatencies[worker] = localLatencies
		}(i)
	}

	start = time.Now()
	close(startGate)
	wg.Wait()

	latencies := mergeLatencies(workerLatencies)
	return result{
		requests:     int(completed),
		failures:     failures,
		elapsed:      time.Since(start),
		latencies:    latencies,
		firstFailure: firstFailure,
	}
}

func transportFor(concurrency int) *http.Transport {
	if concurrency < 1 {
		concurrency = 1
	}
	idle := concurrency * 2
	return &http.Transport{
		Proxy:               http.ProxyFromEnvironment,
		MaxIdleConns:        idle,
		MaxIdleConnsPerHost: idle,
		IdleConnTimeout:     90 * time.Second,
		DisableCompression:  true,
		ForceAttemptHTTP2:   false,
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
	fmt.Printf("gomaxprocs=%d\n", runtime.GOMAXPROCS(0))
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
	fmt.Printf("p999=%s\n", percentile(result.latencies, 999))
	fmt.Printf("min=%s\n", min(result.latencies))
	fmt.Printf("max=%s\n", max(result.latencies))
	fmt.Printf("p50Nanos=%d\n", percentile(result.latencies, 50).Nanoseconds())
	fmt.Printf("p95Nanos=%d\n", percentile(result.latencies, 95).Nanoseconds())
	fmt.Printf("p99Nanos=%d\n", percentile(result.latencies, 99).Nanoseconds())
	fmt.Printf("p999Nanos=%d\n", percentile(result.latencies, 999).Nanoseconds())
	fmt.Printf("minNanos=%d\n", min(result.latencies).Nanoseconds())
	fmt.Printf("maxNanos=%d\n", max(result.latencies).Nanoseconds())
}

func percentile(values []time.Duration, p int) time.Duration {
	if len(values) == 0 {
		return 0
	}
	denominator := 100
	if p > 100 {
		denominator = 1000
	}
	index := (len(values)*p + denominator - 1) / denominator
	if index < 1 {
		index = 1
	}
	if index > len(values) {
		index = len(values)
	}
	return values[index-1]
}

func min(values []time.Duration) time.Duration {
	if len(values) == 0 {
		return 0
	}
	return values[0]
}

func max(values []time.Duration) time.Duration {
	if len(values) == 0 {
		return 0
	}
	return values[len(values)-1]
}

func requestsForWorker(requests int, concurrency int) int {
	if requests <= 0 || concurrency <= 0 {
		return 1024
	}
	return requests/concurrency + 1
}

func mergeLatencies(workerLatencies [][]time.Duration) []time.Duration {
	total := 0
	for _, latencies := range workerLatencies {
		total += len(latencies)
	}
	merged := make([]time.Duration, 0, total)
	for _, latencies := range workerLatencies {
		merged = append(merged, latencies...)
	}
	return merged
}
