# Config Parser

## What you practiced
`while read` loops are a standard shell pattern for processing structured line-based input. Setting `IFS='='` splits each line into a key and value.

## Commands to remember
```bash
while IFS='=' read -r key value; do
  export "$key=$value"
done < app.env

source ./load_env.sh app.env
```
