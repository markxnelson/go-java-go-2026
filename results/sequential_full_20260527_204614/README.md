# Sequential Benchmark Run

This run starts one service at a time, runs the full matrix, stops it, then starts the next runtime variant.

## Tables

- `configurations.csv`: runtime variants, status, CPU/memory settings, and notes.
- `measurements.csv`: raw per-repeat measurement rows.
- `summary-by-cell.csv`: averaged rows by runtime variant, payload size, and concurrency.
- `peak-throughput-by-payload.csv`: best average throughput per runtime variant and payload size.
- `throughput-pivot-by-cell.csv`: Go/JVM/Leyden side-by-side throughput by payload and concurrency.

## Peak Throughput By Payload

| Runtime variant | Payload size | Best concurrency | Avg requests/sec | Avg p99 ns |
| --- | ---: | ---: | ---: | ---: |
| go-stdlib | 7 | 192 | 79219.53 | 12245210 |
| oracle-jdk-jvm | 7 | 96 | 108557.71 | 4825728 |
| oracle-jdk-leyden-aot | 7 | 192 | 128695.66 | 7034009 |
| go-stdlib | 128 | 96 | 66891.71 | 6980026 |
| oracle-jdk-jvm | 128 | 192 | 106659.85 | 8818676 |
| oracle-jdk-leyden-aot | 128 | 192 | 119545.23 | 7546214 |
| go-stdlib | 2048 | 96 | 21832.66 | 22786657 |
| oracle-jdk-jvm | 2048 | 192 | 4221.50 | 49318584 |
| oracle-jdk-leyden-aot | 2048 | 192 | 4230.56 | 49602734 |

## Configurations

```csv
runId,runtimeVariant,service,status,workFactor,logRequests,gomaxprocs,goMemLimit,javaProcessors,javaOpts,notes
sequential_full_20260527_204614,go-stdlib,go,ran,10,false,12,off,12,"-XX:ActiveProcessorCount=12 -XX:MaxRAMPercentage=75","Go net/http, GOMAXPROCS set explicitly"
sequential_full_20260527_204614,oracle-jdk-jvm,helidon,ran,10,false,12,off,12,"-XX:ActiveProcessorCount=12 -XX:MaxRAMPercentage=75","Helidon SE; health output records virtual-thread request handling"
sequential_full_20260527_204614,oracle-jdk-leyden-aot,helidon,ran,10,false,12,off,12,"-XX:ActiveProcessorCount=12 -XX:MaxRAMPercentage=75","Helidon SE; health output records virtual-thread request handling"
sequential_full_20260527_204614,graalvm-jvm,helidon,skipped,10,false,12,off,12,"-XX:ActiveProcessorCount=12 -XX:MaxRAMPercentage=75","GRAALVM_HOME/bin/java not available"
sequential_full_20260527_204614,graalvm-native,helidon,skipped,10,false,12,off,12,"-XX:ActiveProcessorCount=12 -XX:MaxRAMPercentage=75","native image executable not available"
```
