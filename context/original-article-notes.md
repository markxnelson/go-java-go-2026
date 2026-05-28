# Original Article Notes

Source: https://medium.com/helidon/can-java-microservices-be-as-fast-as-go-5ceb9a45d673

Published: 2020-11-05

Authors: Mark Nelson and Peter Nagy

Original premise:

- Test whether Java microservices could run as fast as Go microservices.
- Use a deliberately simple microservice with no external dependencies.
- Keep the code path short, mostly string manipulation.
- Include realistic microservice concerns such as logging and metrics.
- Compare small lightweight frameworks: Helidon for Java and Go-Kit for Go.
- Include Java variants such as JVM and GraalVM native image.
- Warm up the JVM before measuring.

Original environment and version notes:

- Round one used a dual-core Intel Core i7 laptop with 16 GB RAM on macOS.
- Round one used JDK 11, Helidon 2.0.1, and Go 1.13.3.
- Round two used a larger Oracle Linux 7.8 machine with 36 cores and 256 GB RAM.
- Round three used Kubernetes 1.16.8 on Oracle Linux 7.8 worker nodes.

Original conclusions to revisit carefully:

- Go did very well on smaller machines.
- Java did better on larger machines, especially without logging.
- GraalVM native image improved memory footprint and sometimes throughput.
- Logging was often the real bottleneck.
- Kubernetes changed the shape of the results.
- The article did not settle the question forever; it opened a practical line of experiments.

Update constraints for the new article:

- Write for human readers in the RedStack / Mark Nelson voice.
- Produce one article, not a series.
- Include companion code in this workspace.
- Use the article workflow in `/home/mark/evangelist-crew`.
- Use the OCA provider.
- Be explicit that the local code harness is not a universal benchmark.

