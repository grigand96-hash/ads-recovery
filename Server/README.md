# Diagnostic receiver

A separate Python standard-library service, bound to localhost:5187 behind nginx HTTPS. No dependencies or shared credentials are bundled into the app. The endpoint only accepts POST /ads-recovery/v1/events with the versioned, closed schema in server.py. GET /health is local only.

Install server.py under /opt/ads-recovery, install the service unit, and enable it with systemd. Include nginx-limits.conf in the http context and nginx-location.conf inside the chosen TLS host. Test nginx configuration before reloading it. The app endpoint must match that host; changing the recipient or data schema requires a new consent version.

The service uses a dedicated dynamic user and a private StateDirectory. SQLite contains daily sums and counts only; incoming batches and IP addresses are not persisted. Retention cleanup runs hourly and on ingestion. At most 50,000 aggregate groups are allowed. Rate limits, an 8 KiB request limit, and a closed schema bound incoming work. Failed sends are not retried by the app, so totals are approximate and may be incomplete. This public endpoint cannot authenticate that events came from genuine apps.

The production route has access/error logging disabled and forwards only Content-Type and a fixed Host header. IPs are used transiently in nginx rate-limit memory. Provider-level network metadata is outside this service. Do not include the database in backups with longer retention unless the privacy notice and retention policy are changed.

## Review aggregate results

Access the server over SSH. There is no public reporting endpoint. Query /var/lib/ads-recovery/diagnostics.sqlite3 with SQLite:

```sql
SELECT day, app, os, arch, kind, state, method, count,
       round(1.0 * milliseconds / count, 1) AS average_ms
FROM totals ORDER BY day DESC, kind;
```

Compare reloadSent with interfaceAppeared by method and version. These are counts of observations, not unique users or guaranteed success rates. An interface is not proof that all ad data loaded, and quitting or switching away may leave an attempt without an observed outcome.

## Tests

```sh
python3 -m unittest discover -s Server -p 'test_*.py'
```

Tests check the field allowlist, bounds, aggregation, and expiry. Production smoke tests should use synthetic versions and remove their aggregates afterwards.
