#!/bin/bash
# install.sh asks "Continue? [y/N]" a random number of times (5-9) and aborts on
# anything but y/Y, including an empty answer or end of input.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
ASKS=$((5 + RANDOM % 5))
STAMP="$RANDOM$RANDOM"
cat > install.sh <<SCRIPT
#!/bin/bash
# Vendor installer v$((2 + RANDOM % 6)).$((RANDOM % 10)). Do not redistribute.
steps=(unpack "check disk space" "create service user" "write config" "register service" "enable logging" "run self-test" "clean up" "finalize")
asks=$ASKS
for ((i = 0; i < asks; i++)); do
  printf 'Step %d/%d: %s. Continue? [y/N] ' "\$((i + 1))" "\$asks" "\${steps[i]}"
  read -r answer || { echo; echo "Aborted: no answer (stdin closed)."; exit 1; }
  case "\$answer" in
    y|Y) ;;
    *) echo "Aborted by user."; exit 1 ;;
  esac
done
echo "installed after \$asks confirmations, build $STAMP" > install.done
echo "Installation complete."
SCRIPT
chmod +x install.sh
echo "installed after $ASKS confirmations, build $STAMP" > .lm-state/done.expected
