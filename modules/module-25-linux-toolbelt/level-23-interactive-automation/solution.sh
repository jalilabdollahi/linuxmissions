#!/bin/bash
# answer.sh: start the wizard as a coprocess (W[0] = its output, W[1] = its input),
# read up to each ":" (a prompt ends there, with no newline), and answer by what the prompt says.
cat > answer.sh <<'SCRIPT'
#!/bin/bash
. ./answers.conf
coproc W { ./provision-wizard; }
while IFS= read -r -d ':' -t 5 -u "${W[0]}" prompt; do
  case $prompt in
    *Hostname*)    reply=$hostname ;;
    *Region*)      reply=$region ;;
    *size*)        reply=$size ;;
    *Really*)      reply=$confirm ;;
    *Owner*)       reply=$owner ;;
    *Environment*) reply=$env ;;
    *)             continue ;;
  esac
  echo "$reply" >&"${W[1]}"
done
wait
SCRIPT
bash answer.sh
cat provision.result
