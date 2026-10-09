# Mohajon VM test deployment

The test stack is deployed on the Ubuntu VM at `104.207.93.99`.

- Auth API and Haalkhata API share the HTTPS origin; auth endpoints are routed to Auth and other API endpoints to Haalkhata.
- PostgreSQL and Redis stay on the private Docker network. PostgreSQL data persists in a Docker volume; uploaded files and logs persist under `/opt/mohajon`.
- Runtime secrets are generated on the VM in `/opt/mohajon/.env` (root-only permissions); never commit or copy that file into this repository.
- A daily PostgreSQL dump is kept in `/opt/mohajon/backups` for 14 days. IP TLS certificates are renewed by cron every 12 hours.
- The database is fresh; no local database data was copied.

Useful VM commands:

```sh
cd /opt/mohajon/deploy
docker compose --env-file ../.env ps
docker compose --env-file ../.env logs --tail=100 auth haalkhata
docker compose --env-file ../.env restart auth haalkhata
```

To deploy newer service JARs, replace the corresponding `auth/app.jar` or
`haalkhata/app.jar`, then run:

```sh
docker compose --env-file ../.env up -d --build auth haalkhata
```

The Auth mailer uses the same SMTP settings as the local test profile, stored
only in the VM's root-only `.env`. AI providers, FCM server credentials, and live
bKash credentials still need explicit configuration before those integrations
can be tested; bKash is left in sandbox mode.
