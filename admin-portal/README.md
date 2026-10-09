# Mohajon Admin Portal

Angular 22 operations portal for Mohajon platform administrators. It provides a protected overview, bKash subscription-payment reconciliation, and the central support inbox.

## Local development

Use Node 22.22 or later, then run:

```bash
npm install
npm start
```

The default portal URLs are `http://localhost:8080` for the generic auth service and `http://localhost:8081` for the Haalkhata service.

## Administrator access

The server, not the UI, controls access. Set the authenticated user ID in the Haalkhata service environment:

```bash
PLATFORM_ADMIN_USER_IDS=global-admin-user-id
```

Multiple IDs can be comma-separated. A shop-level `ADMIN` role alone has no portal access. Platform administrators also have central support-inbox access.

## Production configuration

Before deploying, replace the two URLs in `public/runtime-config.js` with the production HTTPS domains. The same generated bundle can then be used in each environment.

```bash
npm run build
```

Payment reconciliation only asks bKash for the latest transaction state; it does not provide a manual “mark paid” action.
