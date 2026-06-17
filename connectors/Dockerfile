FROM confluentinc/cp-server-connect:7.8.1 AS base

USER root

# Install AWS SDK
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-s3:10.5.3
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-s3-source:3.0.11

USER appuser 