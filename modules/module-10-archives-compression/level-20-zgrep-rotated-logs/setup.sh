#!/bin/bash
# $1 = sandbox path
# 15 days of shop logs, rotated logrotate-style: app.log (today), app.log.1
# (yesterday), app.log.2.gz ... app.log.10.gz, app.log.11-12.bz2 (an old
# logrotate config used bzip2) and app.log.13-14.xz (older still). Order 88412
# shows up on random times in several files, always including a .bz2, an .xz,
# a two-digit .gz and today's file. Look-alikes: order=884120, order=188412,
# amount_cents=88412.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p logs

services=(checkout payment shipping account search)
msgs=("payment captured" "cart updated" "label printed" "address validated" "stock reserved" "email sent")
story=("status=created total=129.90" "status=payment_failed reason=3ds_timeout" "status=payment_retry attempt=2"
       "status=paid method=card" "status=paid method=card duplicate_charge=true" "status=address_changed by=customer"
       "status=picking warehouse=DUS-2" "status=shipped carrier=DHL" "status=delivery_failed reason=not_home"
       "status=redelivery_scheduled date=next_day" "status=delivery_failed reason=address_unknown"
       "status=returned_to_sender" "status=customer_contact channel=email" "status=refund_requested amount=129.90"
       "status=customer_contact channel=phone" "status=escalated team=support-l2")

# Which rotations mention the order: some random ones, plus the required kinds
pick=" 0 1 10 $((RANDOM % 2 + 11)) $((RANDOM % 2 + 13)) $((RANDOM % 8 + 2)) $((RANDOM % 8 + 2)) $((RANDOM % 3 + 3)) "
s=0
for n in $(seq 14 -1 0); do
  day=$(( 10 - n + 31 ))                      # Oct 27 = day 0 ... Nov 10
  if [ $day -le 31 ]; then date="2026-10-$day"; else date=$(printf '2026-11-%02d' $((day - 31))); fi
  lines=$(( RANDOM % 200 + 450 ))
  hits=" "
  if [[ "$pick" == *" $n "* ]]; then
    hits=" $((RANDOM % lines + 1)) "                  # one line, sometimes two
    [ $((RANDOM % 3)) -lt 2 ] && hits="$hits$((RANDOM % lines + 1)) "
  fi
  {
    for i in $(seq 1 "$lines"); do
      t=$(( i * 86000 / lines ))
      printf -v ts '%sT%02d:%02d:%02dZ' "$date" $((t / 3600)) $((t % 3600 / 60)) $((t % 60))
      if [[ "$hits" == *" $i "* ]]; then
        printf '%s INFO  [orders] order=88412 user=u20931 %s\n' "$ts" "${story[$s]}"
        s=$((s + 1))
        continue
      fi
      case $((RANDOM % 60)) in
        0) printf '%s INFO  [orders] order=884120 user=u%d status=created total=19.90\n' "$ts" $((RANDOM % 30000)) ;;
        1) printf '%s WARN  [orders] order=188412 user=u%d status=payment_failed reason=card_declined\n' "$ts" $((RANDOM % 30000)) ;;
        2) printf '%s INFO  [payment] order=%d amount_cents=88412 status=captured\n' "$ts" $((RANDOM + 10000)) ;;
        *) printf '%s INFO  [%s] order=%d user=u%d msg=%s\n' "$ts" "${services[$((RANDOM % 5))]}" \
             $((RANDOM + 10000)) $((RANDOM % 30000)) "${msgs[$((RANDOM % 6))]}" ;;
      esac
    done
  } > .day
  case $n in
    0)  f=logs/app.log; mv .day "$f" ;;
    1)  f=logs/app.log.1; mv .day "$f" ;;
    1[1-2]) f=logs/app.log.$n.bz2; bzip2 -c .day > "$f"; rm .day ;;
    1[3-4]) f=logs/app.log.$n.xz; xz -c .day > "$f"; rm .day ;;
    *)  f=logs/app.log.$n.gz; gzip -c .day > "$f"; rm .day ;;
  esac
  touch -d "${date}T23:59:00" "$f"
done

cat > TICKET.txt <<'EOF'
SUPPORT-5521  "Where is my order 88412??"
Customer u20931 says the order was charged twice, never arrived, and
nobody answers. Please send me every log line about order 88412, oldest
first, so I can reconstruct what happened. The logs are in logs/ on the
app server; please don't unpack the rotated ones, the disk is almost full.
EOF
