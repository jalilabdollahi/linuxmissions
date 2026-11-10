# Traffic Anomalies

## Why it works
A z-score says how unusual a value is for *its own* series: `(x - mean) / sd`. The
script stores every numeric value per host, and only in `END`, when each host is
complete, computes the host's mean and population standard deviation (the square
root of the mean squared deviation) and flags values more than 3 deviations away in
either direction. Because every host is measured against itself, a mail server
jumping from 2,100 to 3,400 requests stands out just as clearly as a web server
dropping from 118,000 to 30,000.

## Common mistakes
- One mean for all hosts: the big hosts dominate the deviation and the small host's
  spike disappears completely.
- `$3 + 0` on `NaN` or an empty cell: awk makes it 0 (or a real NaN in some awks),
  which drags the mean down and gets flagged as the "biggest anomaly".
- Dividing by zero for a host with a constant value (here the health checker, which
  hits every minute: 1440 a day).
- `sqrt(ss/n - mean^2)` (the one-pass formula) can come out slightly negative for
  constant data because of rounding, and `sqrt` of that is `nan`. The two-pass
  version above can't.

## Learn next
Mean and standard deviation are themselves pulled by the outlier. Robust variants use
the median and the median absolute deviation (MAD); `datamash -g 2 mean 3 sstdev 3`
gives grouped statistics in one command, and `sort -g` sorts the z-scores.
