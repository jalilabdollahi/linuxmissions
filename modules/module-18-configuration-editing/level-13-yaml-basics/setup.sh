#!/bin/bash
# compose.yml with two hotfix mistakes inside worker.environment: one line indented with a
# TAB, one with three extra spaces. The api and worker images share the tag 2.7.0.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

queues=(orders invoices shipments mailers)
QUEUE=${queues[RANDOM % ${#queues[@]}]}
CONC=$((RANDOM % 6 + 3))
RETRIES=$((RANDOM % 4 + 2))
DBPASS=$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-12)

# The intended file (what the hotfix author meant), with the new tag already in place.
cat > .lm-state/fixed.yml <<YML
# compose.yml - shop stack, hotfix 2.7.x
# api stays on 2.7.0 until the schema migration is signed off
services:
  api:
    image: registry.example.com/shop/api:2.7.0
    ports:
      - "8080:8080"
    environment:
      - LOG_LEVEL=info
      - DB_HOST=db
  worker:
    image: registry.example.com/shop/worker:2.7.1
    command: ["python", "-m", "shop.worker"]
    environment:
      QUEUE: $QUEUE
      CONCURRENCY: $CONC
      RETRIES: $RETRIES
    depends_on:
      - db
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: $DBPASS
YML

# The file the player gets: old tag, a tab before CONCURRENCY, RETRIES pushed 3 spaces too far.
sed -e 's|worker:2\.7\.1|worker:2.7.0|' \
    -e 's|^      CONCURRENCY:|\tCONCURRENCY:|' \
    -e 's|^      RETRIES:|         RETRIES:|' .lm-state/fixed.yml > compose.yml
