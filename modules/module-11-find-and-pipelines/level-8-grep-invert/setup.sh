#!/bin/bash
# What Is Actually Set: a postgresql.conf in the stock layout. Every parameter
# is written as a commented default; about 30 random ones are "set" (some with
# a trailing # comment, some indented). Continuation comments are indented with
# tabs, and some blank lines hold spaces or tabs.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM" '
BEGIN { srand(seed); FS = "|" }
/^@/ {   # section header
  sub(/^@/, ""); printf "\n\n#%s\n# %s\n#%s\n\n", bar, $0, bar
  if (rand() < 0.5) printf "%s\n", (rand() < 0.5 ? "   " : "\t")
  next
}
/^%/ { sub(/^%/, ""); printf "# - %s -\n\n", $0; next }
/^\?/ { sub(/^\?/, ""); printf "# %s\n", $0; next }
{
  name = $1; def = $2; alt = $3; note = $4
  if (rand() < 0.3 && alt != "") {
    # a real setting
    line = name " = " alt
    r = rand()
    if (r < 0.35)      line = line "\t\t# " (note != "" ? note : "changed by ops")
    else if (r < 0.45) line = "  " line
    print line
  } else {
    line = "#" name " = " def
    if (note != "") line = line "\t\t# " note
    print line
  }
  if (rand() < 0.25) printf "\t\t\t\t\t# (change requires restart)\n"
  if (rand() < 0.04) printf "%s\n", (rand() < 0.5 ? " " : "\t \t")
}
BEGIN { bar = "------------------------------------------------------------------------------" }
' > postgresql.conf <<'PARAMS'
?-----------------------------
?PostgreSQL configuration file
?-----------------------------
?
?This file consists of lines of the form:
?
?  name = value
?
?(The "=" is optional.)  Whitespace may be used.  Comments are introduced with
?"#" anywhere on a line.  The complete list of parameter names and allowed
?values can be found in the PostgreSQL documentation.
?
?The commented-out settings shown in this file represent the default values.
?Re-commenting a setting is NOT sufficient to revert it to the default value;
?you need to reload the server.
?
?Memory units:  B  = bytes            Time units:  us  = microseconds
?               kB = kilobytes                     ms  = milliseconds
?               MB = megabytes                     s   = seconds
?               GB = gigabytes                     min = minutes
?               TB = terabytes                     h   = hours
?                                                  d   = days
@FILE LOCATIONS
?The default values of these variables are driven from the -D command-line
?option or PGDATA environment variable, represented here as ConfigDir.
data_directory|'/var/lib/postgresql/16/main'|'/srv/pgdata/16/main'|use data in another directory
hba_file|'/etc/postgresql/16/main/pg_hba.conf'||host-based authentication file
ident_file|'/etc/postgresql/16/main/pg_ident.conf'||ident configuration file
external_pid_file|'/var/run/postgresql/16-main.pid'||write an extra PID file
@CONNECTIONS AND AUTHENTICATION
%Connection Settings
listen_addresses|'localhost'|'*'|what IP address(es) to listen on;
port|5432|5433|
max_connections|100|400|
reserved_connections|0|3|
superuser_reserved_connections|3|5|
unix_socket_directories|'/var/run/postgresql'||comma-separated list of directories
unix_socket_group|''||
unix_socket_permissions|0777|0770|begin with 0 to use octal notation
bonjour|off||advertise server via Bonjour
bonjour_name|''||defaults to the computer name
%TCP settings
tcp_keepalives_idle|0|60|TCP_KEEPIDLE, in seconds;
tcp_keepalives_interval|0|10|TCP_KEEPINTVL, in seconds;
tcp_keepalives_count|0|6|TCP_KEEPCNT;
tcp_user_timeout|0||TCP_USER_TIMEOUT, in milliseconds;
client_connection_check_interval|0|10s|time between checks for client
%Authentication
authentication_timeout|1min|30s|1s-600s
password_encryption|scram-sha-256|scram-sha-256|scram-sha-256 or md5
scram_iterations|4096||
db_user_namespace|off||
krb_server_keyfile|'FILE:${sysconfdir}/krb5.keytab'||
krb_caseins_users|off||
%SSL
ssl|off|on|
ssl_ca_file|''|'/etc/ssl/certs/internal-ca.pem'|
ssl_cert_file|'/etc/ssl/certs/ssl-cert-snakeoil.pem'|'/etc/ssl/certs/db.pem'|
ssl_crl_file|''||
ssl_key_file|'/etc/ssl/private/ssl-cert-snakeoil.key'|'/etc/ssl/private/db.key'|
ssl_ciphers|'HIGH:MEDIUM:+3DES:!aNULL'||allowed SSL ciphers
ssl_prefer_server_ciphers|on||
ssl_ecdh_curve|'prime256v1'||
ssl_min_protocol_version|'TLSv1.2'|'TLSv1.3'|
ssl_max_protocol_version|''||
@RESOURCE USAGE (except WAL)
%Memory
shared_buffers|128MB|8GB|min 128kB
huge_pages|try|on|on, off, or try
huge_page_size|0||zero for system default
temp_buffers|8MB|32MB|min 800kB
max_prepared_transactions|0|50|zero disables the feature
work_mem|4MB|64MB|min 64kB
hash_mem_multiplier|2.0|4.0|1-1000.0 multiplier on hash table work_mem
maintenance_work_mem|64MB|2GB|min 1MB
autovacuum_work_mem|-1|1GB|min 1MB, or -1 to use maintenance_work_mem
logical_decoding_work_mem|64MB||min 64kB
max_stack_depth|2MB||min 100kB
shared_memory_type|mmap||the default is the first option
dynamic_shared_memory_type|posix|posix|the default is usually the first option
min_dynamic_shared_memory|0MB||(change requires restart)
%Disk
temp_file_limit|-1|50GB|limits per-process temp file space
%Kernel Resources
max_files_per_process|1000|4000|min 64
%Cost-Based Vacuum Delay
vacuum_cost_delay|0|2ms|0-100 milliseconds (0 disables)
vacuum_cost_page_hit|1||0-10000 credits
vacuum_cost_page_miss|2||0-10000 credits
vacuum_cost_page_dirty|20||0-10000 credits
vacuum_cost_limit|200|2000|1-10000 credits
%Background Writer
bgwriter_delay|200ms|50ms|10-10000ms between rounds
bgwriter_lru_maxpages|100|1000|max buffers written/round, 0 disables
bgwriter_lru_multiplier|2.0|4.0|0-10.0 multiplier on buffers scanned/round
bgwriter_flush_after|512kB||measured in pages, 0 disables
%Asynchronous Behavior
backend_flush_after|0||measured in pages, 0 disables
effective_io_concurrency|1|200|1-1000; 0 disables prefetching
maintenance_io_concurrency|10|200|1-1000; 0 disables prefetching
max_worker_processes|8|16|
max_parallel_workers_per_gather|2|4|limited by max_parallel_workers
max_parallel_maintenance_workers|2|4|limited by max_parallel_workers
max_parallel_workers|8|16|number of max_worker_processes that
parallel_leader_participation|on||
old_snapshot_threshold|-1||1min-60d; -1 disables; 0 is immediate
@WRITE-AHEAD LOG
%Settings
wal_level|replica|logical|minimal, replica, or logical
fsync|on||flush data to disk for crash safety
synchronous_commit|on|off|synchronization level;
wal_sync_method|fsync||the default is the first option
full_page_writes|on||recover from partial page writes
wal_log_hints|off|on|also do full page writes of non-critical updates
wal_compression|off|lz4|enables compression of full-page writes;
wal_init_zero|on||zero-fill new WAL files
wal_recycle|on||recycle WAL files
wal_buffers|-1|64MB|min 32kB, -1 sets based on shared_buffers
wal_writer_delay|200ms||1-10000 milliseconds
wal_writer_flush_after|1MB||measured in pages, 0 disables
wal_skip_threshold|2MB||
commit_delay|0||range 0-100000, in microseconds
commit_siblings|5||range 1-1000
%Checkpoints
checkpoint_timeout|5min|15min|range 30s-1d
checkpoint_completion_target|0.9|0.9|checkpoint target duration, 0.0 - 1.0
checkpoint_flush_after|256kB||measured in pages, 0 disables
checkpoint_warning|30s||0 disables
max_wal_size|1GB|16GB|
min_wal_size|80MB|2GB|
%Archiving
archive_mode|off|on|enables archiving; off, on, or always
archive_library|''||library to use to archive a WAL file
archive_command|''|'test ! -f /mnt/wal/%f && cp %p /mnt/wal/%f'|command to use to archive a WAL file
archive_timeout|0|300|force a WAL file switch after this
%Archive Recovery
restore_command|''||command to use to restore an archived WAL file
archive_cleanup_command|''||command to execute at every restartpoint
recovery_end_command|''||command to execute at completion of recovery
@REPLICATION
%Sending Servers
max_wal_senders|10|20|max number of walsender processes
max_replication_slots|10|20|max number of replication slots
wal_keep_size|0|4GB|in megabytes; 0 disables
max_slot_wal_keep_size|-1|64GB|in megabytes; -1 disables
wal_sender_timeout|60s||in milliseconds; 0 disables
track_commit_timestamp|off|on|collect timestamp of transaction commit
%Primary Server
synchronous_standby_names|''|'ANY 1 (db_02, db_03)'|standby servers that provide sync rep
%Standby Servers
primary_conninfo|''||connection string to sending server
primary_slot_name|''||replication slot on sending server
hot_standby|on||"off" disallows queries during recovery
max_standby_archive_delay|30s|300s|max delay before canceling queries
max_standby_streaming_delay|30s|300s|max delay before canceling queries
wal_receiver_status_interval|10s||send replies at least this often
hot_standby_feedback|off|on|send info from standby to prevent
wal_receiver_timeout|60s||time that receiver waits for
wal_retrieve_retry_interval|5s||time to wait before retrying to
recovery_min_apply_delay|0||minimum delay for applying changes during recovery
@QUERY TUNING
%Planner Method Configuration
enable_async_append|on||
enable_bitmapscan|on||
enable_gathermerge|on||
enable_hashagg|on||
enable_hashjoin|on||
enable_incremental_sort|on||
enable_indexscan|on||
enable_indexonlyscan|on||
enable_material|on||
enable_memoize|on||
enable_mergejoin|on||
enable_nestloop|on|off|disabled after incident 2024-11
enable_parallel_append|on||
enable_parallel_hash|on||
enable_partition_pruning|on||
enable_partitionwise_join|off|on|
enable_partitionwise_aggregate|off|on|
enable_seqscan|on||
enable_sort|on||
enable_tidscan|on||
%Planner Cost Constants
seq_page_cost|1.0||measured on an arbitrary scale
random_page_cost|4.0|1.1|same scale as above
cpu_tuple_cost|0.01||same scale as above
cpu_index_tuple_cost|0.005||same scale as above
cpu_operator_cost|0.0025||same scale as above
parallel_setup_cost|1000.0||same scale as above
parallel_tuple_cost|0.1||same scale as above
min_parallel_table_scan_size|8MB||
min_parallel_index_scan_size|512kB||
effective_cache_size|4GB|24GB|
jit_above_cost|100000|-1|perform JIT compilation if available
jit_inline_above_cost|500000||inline small functions if query is
jit_optimize_above_cost|500000||use expensive JIT optimizations if
%Genetic Query Optimizer
geqo|on||
geqo_threshold|12||
geqo_effort|5||range 1-10
geqo_pool_size|0||selects default based on effort
geqo_generations|0||selects default based on effort
geqo_selection_bias|2.0||range 1.5-2.0
geqo_seed|0.0||range 0.0-1.0
%Other Planner Options
default_statistics_target|100|500|range 1-10000
constraint_exclusion|partition||on, off, or partition
cursor_tuple_fraction|0.1||range 0.0-1.0
from_collapse_limit|8||
jit|on|off|allow JIT compilation
join_collapse_limit|8||1 disables collapsing of explicit
plan_cache_mode|auto||auto, force_generic_plan or
@REPORTING AND LOGGING
%Where to Log
log_destination|'stderr'|'stderr,csvlog'|Valid values are combinations of
logging_collector|off|on|Enable capturing of stderr, jsonlog,
log_directory|'log'|'/var/log/postgresql'|directory where log files are written,
log_filename|'postgresql-%Y-%m-%d_%H%M%S.log'|'postgresql-%a.log'|log file name pattern,
log_file_mode|0600||creation mode for log files,
log_rotation_age|1d||Automatic rotation of logfiles will
log_rotation_size|10MB|0|Automatic rotation of logfiles will
log_truncate_on_rotation|off|on|If on, an existing log file with the
syslog_facility|'LOCAL0'||
syslog_ident|'postgres'||
event_source|'PostgreSQL'||
%When to Log
log_min_messages|warning|info|values in order of decreasing detail:
log_min_error_statement|error||values in order of decreasing detail:
log_min_duration_statement|-1|250ms|-1 is disabled, 0 logs all statements
log_min_duration_sample|-1||-1 is disabled, 0 logs a sample of statements
log_statement_sample_rate|1.0||1.0 logs all statements from all sampled queries
log_transaction_sample_rate|0.0||Fraction of transactions whose statements
log_startup_progress_interval|10s||Time between progress updates for
%What to Log
debug_print_parse|off||
debug_print_rewritten|off||
debug_print_plan|off||
debug_pretty_print|on||
log_autovacuum_min_duration|10min|0|log autovacuum activity;
log_checkpoints|on||
log_connections|off|on|
log_disconnections|off|on|
log_duration|off||
log_error_verbosity|default||terse, default, or verbose messages
log_hostname|off||
log_line_prefix|'%m [%p] %q%u@%d '|'%m [%p] %q%u@%d app=%a '|special values:
log_lock_waits|off|on|log lock waits >= deadlock_timeout
log_recovery_conflict_waits|off||log standby recovery conflict waits
log_parameter_max_length|-1||when logging statements, limit logged
log_parameter_max_length_on_error|0||when logging an error, limit logged
log_statement|'none'|'ddl'|none, ddl, mod, all
log_replication_commands|off||
log_temp_files|-1|0|log temporary files equal or larger
log_timezone|'Etc/UTC'|'Etc/UTC'|
%Process Title
cluster_name|'16/main'|'orders-prod'|added to process titles if nonempty
update_process_title|on||
@STATISTICS
%Cumulative Query and Index Statistics
track_activities|on||
track_activity_query_size|1024|4096|
track_counts|on||
track_io_timing|off|on|
track_wal_io_timing|off||
track_functions|none|pl|none, pl, all
stats_fetch_consistency|cache||cache, none, snapshot
%Monitoring
compute_query_id|auto|on|
log_statement_stats|off||
log_parser_stats|off||
log_planner_stats|off||
log_executor_stats|off||
@AUTOVACUUM
autovacuum|on||Enable autovacuum subprocess?  'on'
autovacuum_max_workers|3|6|max number of autovacuum subprocesses
autovacuum_naptime|1min|15s|time between autovacuum runs
autovacuum_vacuum_threshold|50||min number of row updates before
autovacuum_vacuum_insert_threshold|1000||min number of row inserts
autovacuum_analyze_threshold|50||min number of row updates before
autovacuum_vacuum_scale_factor|0.2|0.05|fraction of table size before vacuum
autovacuum_vacuum_insert_scale_factor|0.2||fraction of inserts over table
autovacuum_analyze_scale_factor|0.1|0.02|fraction of table size before analyze
autovacuum_freeze_max_age|200000000||maximum XID age before forced vacuum
autovacuum_multixact_freeze_max_age|400000000||maximum multixact age
autovacuum_vacuum_cost_delay|2ms|1ms|default vacuum cost delay for
autovacuum_vacuum_cost_limit|-1|3000|default vacuum cost limit for
@CLIENT CONNECTION DEFAULTS
%Statement Behavior
client_min_messages|notice||values in order of decreasing detail:
search_path|'"$user", public'|'"$user", public, shop'|schema names
row_security|on||
default_table_access_method|'heap'||
default_tablespace|''||a tablespace name, '' uses the default
default_toast_compression|'pglz'|'lz4'|'pglz' or 'lz4'
temp_tablespaces|''||a list of tablespace names, '' uses
check_function_bodies|on||
default_transaction_isolation|'read committed'||
default_transaction_read_only|off||
default_transaction_deferrable|off||
session_replication_role|'origin'||
statement_timeout|0|60s|in milliseconds, 0 is disabled
lock_timeout|0|10s|in milliseconds, 0 is disabled
idle_in_transaction_session_timeout|0|5min|in milliseconds, 0 is disabled
idle_session_timeout|0||in milliseconds, 0 is disabled
vacuum_freeze_table_age|150000000||
vacuum_freeze_min_age|50000000||
vacuum_failsafe_age|1600000000||
vacuum_multixact_freeze_table_age|150000000||
vacuum_multixact_freeze_min_age|5000000||
vacuum_multixact_failsafe_age|1600000000||
bytea_output|'hex'||hex, escape
xmlbinary|'base64'||
xmloption|'content'||
gin_pending_list_limit|4MB||
createrole_self_grant|''||set and/or inherit
%Locale and Formatting
datestyle|'iso, mdy'|'iso, dmy'|
intervalstyle|'postgres'||
timezone|'Etc/UTC'|'Europe/Berlin'|
timezone_abbreviations|'Default'||Select the set of available time zone
extra_float_digits|1||min -15, max 3; any value >0 actually
client_encoding|sql_ascii||actually, defaults to database
lc_messages|'C.UTF-8'||locale for system error message
lc_monetary|'C.UTF-8'|'de_DE.UTF-8'|locale for monetary formatting
lc_numeric|'C.UTF-8'||locale for number formatting
lc_time|'C.UTF-8'||locale for time formatting
default_text_search_config|'pg_catalog.english'||
%Shared Library Preloading
local_preload_libraries|''||
session_preload_libraries|''||
shared_preload_libraries|''|'pg_stat_statements,auto_explain'|(change requires restart)
jit_provider|'llvmjit'||JIT library to use
%Other Defaults
dynamic_library_path|'$libdir'||
extension_destdir|''||prepend path when loading extensions
gin_fuzzy_search_limit|0||
@LOCK MANAGEMENT
deadlock_timeout|1s|2s|
max_locks_per_transaction|64|256|min 10
max_pred_locks_per_transaction|64||min 10
max_pred_locks_per_relation|-2||negative values mean
max_pred_locks_per_page|2||min 0
@VERSION AND PLATFORM COMPATIBILITY
%Previous PostgreSQL Versions
array_nulls|on||
backslash_quote|safe_encoding||on, off, or safe_encoding
escape_string_warning|on||
lo_compat_privileges|off||
quote_all_identifiers|off||
standard_conforming_strings|on||
synchronize_seqscans|on||
%Other Platforms and Clients
transform_null_equals|off||
@ERROR HANDLING
exit_on_error|off||terminate session on any error?
restart_after_crash|on||reinitialize after backend crash?
data_sync_retry|off||retry or panic on failure to fsync
recovery_init_sync_method|fsync||fsync, syncfs (Linux 5.8+)
@CONFIG FILE INCLUDES
?These options allow settings to be loaded from files other than the
?default postgresql.conf.  Note that these are directives, not variable
?assignments, so they can usefully be given only once.
include_dir|'...'|'conf.d'|include files ending in '.conf' from
include_if_exists|'...'||include file only if it exists
include|'...'||include file
@CUSTOMIZED OPTIONS
?Add settings for extensions here
pg_stat_statements.max|5000|10000|
pg_stat_statements.track|top|all|
auto_explain.log_min_duration|-1|2s|
auto_explain.log_analyze|off|on|
PARAMS

# Make sure a few of each tricky kind exist whatever the dice said.
cat >> postgresql.conf <<'TAIL'

  # Tuning from the 2025 performance review (see OPS-431):
	# do not touch without talking to the DBA team
work_mem = 128MB		# overrides the value above for the reporting box
 	 
idle_session_timeout = 30min	
TAIL

awk '!/^[ \t]*(#|$)/' postgresql.conf > .lm-state/effective
cksum < postgresql.conf > .lm-state/conf.sum
