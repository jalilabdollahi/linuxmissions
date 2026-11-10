#!/bin/bash
# One line per ticket item, in order. 9-16 because the last check of the
# business day is 16:45; 9-17 would also run 17:00-17:45.
cat > schedule.cron <<'CRON'
*/15 9-16 *  *        mon-fri  true
30   2    1  *        *        true
0    23   *  *        sat,sun  true
15   4    *  1,4,7,10 mon      true
0    */2  *  *        *        true
CRON
bin/cron-expand --from "2025-01-06 08:00" --to "2025-01-06 18:00" schedule.cron | tail -n 3
