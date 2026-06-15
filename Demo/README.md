# OAuth Server Lib Demo

This demo shows how the OAuth server library can be used to turn any DataFlex WebApp into an OpenID Connect Authorization Server. It includes the default handler, provider implementation, login and consent views, and database tables needed to issue authorization codes, access tokens, refresh tokens, and ID tokens.

## Table Of Contents

- [Setup](#setup)
- [Demo Clients](#demo-clients)
- [Allowed Client Scopes](#allowed-client-scopes)
- [Roles](#roles)
- [Running The Demo](#running-the-demo)

## Setup

Run the SQL scripts in `Data/` against the demo database:

1. `CreateTables.sql` creates the OAuth/OIDC tables if they do not already exist.
2. `InsertSystemScopes.sql` inserts the built-in system scopes if they do not already exist.
3. `SeedDemoData.sql` inserts demo clients, callback URLs, allowed client scopes, demo roles, role scopes, and the example user role assignment if they do not already exist.

The scripts are idempotent, so they can be run more than once without creating duplicate records.

## Demo Clients

`SeedDemoData.sql` creates these clients:

| Client ID | Type | Secret |
| --- | --- | --- |
| `demo-public-client` | `public` | None |
| `demo-confidential-client` | `confidential` | `this_is_ultra_secret` |

The confidential client's secret is stored as a hashed value in the script. Use the original value `this_is_ultra_secret` when authenticating the client.

Both clients are allowed to use these callback URLs:

```text
http://localhost/oauth/callback
https://oidcdebugger.com/debug
```

For localhost callback URLs, the library ignores the port during redirect URI validation. That means a runtime redirect URI such as `http://localhost:8080/oauth/callback` can match the seeded callback URL.

## Allowed Client Scopes

Both demo clients are allowed to request these scopes through `OidcClientScope`:

| Scope | Purpose |
| --- | --- |
| `openid` | Enables OpenID Connect and ID token generation. |
| `profile` | Allows profile claims such as name and username. |
| `email` | Allows email-related claims. |
| `offline_access` | Allows refresh token issuance. |
| `example_scope` | Allows access to the demo example API scope. |

## Roles

`SeedDemoData.sql` creates these roles:

| Role | Default | Scopes |
| --- | --- | --- |
| `Default Role` | Yes | `openid`, `offline_access`, `profile`, `email` |
| `Example` | No | `example_scope` |

The `Default Role` is marked as default, so users get its scopes without an explicit `OidcUserRole` assignment. The `Example` role is explicitly assigned to subject `example-user`, so that user gets the default scopes plus `example_scope`. The `admin` user only gets the default scopes.

The demo login credentials are:

| Username | Password |
| --- | --- |
| `admin` | `admin` |
| `example-user` | `example-user` |

## Running The Demo

1. Open the demo workspace in DataFlex.
2. Run the scripts in `Data/`.
3. Compile and run the WebApp.
4. Configure an OAuth/OIDC client or test tool with one of the demo client IDs, the callback URL above, and the scopes you want to test.

Use the public client with PKCE. Use the confidential client with the secret above.
