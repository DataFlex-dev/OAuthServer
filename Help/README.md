# OAuthServer Library

This library is a DataFlex OAuth 2.0 / OpenID Connect server implementation built around a small set of cooperating objects. The design is intentionally split so that cryptography, protocol handling, persistence, login UX, consent UX, and claim resolution stay separate.

This README describes how the library is intended to be assembled, how requests flow through it, what the standard implementation supports today, and where developers are expected to plug in application-specific behavior.

## Table Of Contents

- [Core Architecture](#core-architecture)
- [1. Key store](#1-key-store)
- [2. Provider](#2-provider)
- [3. Login view](#3-login-view)
- [4. Consent view](#4-consent-view)
- [5. OAuth/OIDC handler](#5-oauthoidc-handler)
- [6. Well-known handler](#6-well-known-handler)
- [Request Flow](#request-flow)
- [Supported Endpoints](#supported-endpoints)
- [Supported Flows and Features](#supported-flows-and-features)
- [Authorization flow](#authorization-flow)
- [Token grants](#token-grants)
- [UserInfo](#userinfo)
- [Revocation and introspection](#revocation-and-introspection)
- [Standard Scopes and Claims](#standard-scopes-and-claims)
- [Claim Resolution Architecture](#claim-resolution-architecture)
- [Step 1: determine which claims are allowed](#step-1-determine-which-claims-are-allowed)
- [Step 2: resolve actual values](#step-2-resolve-actual-values)
- [Standard Provider Responsibilities](#standard-provider-responsibilities)
- [Session Integration](#session-integration)
- [Default Wiring](#default-wiring)
- [Practical Integration Rules](#practical-integration-rules)
- [Current Implementation Notes](#current-implementation-notes)
- [Summary](#summary)

## Core Architecture

The library is organized around six main parts:

1. `cOidcKeyStore`
2. `cOidcProvider` or `cOidcProviderStandard`
3. A login view
4. A consent view
5. `cOidcHandler`
6. `cOidcWellKnownHandler`

The dependency flow is:

`KeyStore -> Provider -> Login/Consent Views -> Handler -> Well-Known Handler`

That order matters because each layer has a narrower responsibility than the one below it.

### 1. Key store

`cOidcKeyStore` is the cryptographic root of the library.

Its responsibilities are:

- Register key pairs by `kid`
- Load public/private keys from disk
- Keep track of the active signing key through `psActiveKeyIdentifier`
- Build the in-memory JWKS representation used by discovery and token validation
- Supply key material to the JWT layer through the provider

In practice this means the key store owns the signing and verification material, while the rest of the library never needs to know where the PEM files live or how they are loaded.

The default object is `Oidc\OidcDefaultKeyStore.wo`, which registers one key pair and marks it active.

Important current behavior:

- The key loader can detect RSA, RSA-PSS, EC, and EdDSA key types.
- The JWKS endpoint currently serializes RSA keys only. If you rely on `/.well-known/jwks.json` for client validation, RSA is the safe choice today.
- Private key files are expected to be readable without a password. (If support for password protection is needed this can be added in later versions)

### 2. Provider

`cOidcProvider` is the central application integration point.

It holds handles to:

- The key store: `phoOidcKeyStore`
- An internal JWT helper: `phoJWT`
- An optional claim resolver: `phoClaimResolver`
- The handler: `phoOidcHandler`

The provider is called a provider because it provides the handler with everything the protocol engine does not own itself:

- Client lookup
- Redirect URI validation
- User login state
- User identity data
- Scope-to-claim mapping
- Consent persistence
- Authorization code persistence
- Refresh token persistence and revocation state
- Request audit logging
- Token generation
- Token validation
- Application base URL

This is also why the handler does not need direct access to the key store. The handler delegates token work to the provider, and the provider delegates the actual signing and validation details to its JWT/key infrastructure.

There are two provider layers in the library:

- `cOidcProvider`: abstract protocol-facing base class with events/stubs
- `cOidcProviderStandard`: standard database-backed implementation

Use `cOidcProvider` when you want to supply all persistence and lookup behavior yourself. Use `cOidcProviderStandard` when you want the built-in table/DDO based implementation.

### 3. Login view

The login view is not just a page. It is part of the authorization flow.

It receives a handle to the provider and is used when the authorize endpoint determines the user must authenticate first. The handler redirects unauthenticated requests to the login view using a `continue` URL that points back to the original authorize request.

The provider's application base URL is critical here. The login redirect is built from that base URL plus the view state and the normalized authorize continuation URL.

The demo uses `Demo\AppSrc\OidcLogin.wo` as the login view. It:

- stores the `continue` URL
- authenticates through `ghoWebSessionManager`
- returns to the original authorize request after login
- can apply client branding based on the requesting client

### 4. Consent view

The consent view is equally important to the login view. It also receives a provider handle and participates in the authorization flow when consent is required.

Its responsibilities are:

- load the normalized `continue` URL
- identify the requesting client
- inspect the requested scopes
- reduce scopes to what is both client-allowed and user-authorized
- show human-readable scope summaries
- persist granted consent through the provider
- redirect back to the authorize flow after approval
- redirect back to the client with `access_denied` if the user cancels

The demo uses `Demo\AppSrc\OidcConsent.wo` for this.

### 5. OAuth/OIDC handler

`cOidcHandler` is the protocol engine. It subclasses `cWebHttpHandler` and defaults to `psPath "oidc/v1"`.

It needs handles to:

- the provider
- the login view
- the consent view

Its responsibilities are:

- parse and validate inbound OAuth/OIDC requests
- enforce HTTPS, with localhost/127.0.0.1 exempted for development
- route requests to the correct endpoint logic
- authenticate clients and bearer tokens
- manage authorize/login/consent redirects
- validate PKCE and authorization codes
- ask the provider to create token sets
- return protocol-compliant success and error responses
- write request audit information through the provider

The handler is deliberately not responsible for business data. It knows protocol rules. The provider knows your application data.

### 6. Well-known handler

`cOidcWellKnownHandler` exposes the discovery documents:

- `/.well-known/openid-configuration`
- `/.well-known/jwks.json`

It needs handles to:

- the provider
- the key store
- the OIDC handler

This handler turns the current server configuration into machine-readable metadata for clients.

## Request Flow

The normal authorization code flow is:

1. The client calls `/oidc/v1/authorize`.
2. `cOidcHandler` validates the client, redirect URI, response type, scopes, prompt behavior, and PKCE requirements.
3. If the user is not logged in, the handler redirects to the login view.
4. The login view authenticates the user and navigates back to the original authorize URL.
5. The handler checks consent.
6. If consent is missing or explicitly required, the handler redirects to the consent view.
7. The consent view saves the approved scopes through the provider and navigates back to the authorize URL.
8. The handler creates an authorization code through the provider and redirects to the client callback URL.
9. The client exchanges the code at `/oidc/v1/token`.
10. The handler validates the client, code, redirect URI, and PKCE verifier.
11. The provider generates the token set.
12. The handler returns JSON with the token response.

The refresh flow is similar: the handler validates the refresh token, asks the provider for refresh token state, rotates the token family, and returns a new token set.

## Supported Endpoints

Currently the library supports these endpoints:

- `GET` or `POST` `/oidc/v1/authorize`
- `POST` `/oidc/v1/token`
- `GET` or `POST` `/oidc/v1/userinfo`
- `POST` `/oidc/v1/revoke`
- `POST` `/oidc/v1/introspect`
- `GET` `/.well-known/openid-configuration`
- `GET` `/.well-known/jwks.json`

## Supported Flows and Features

### Authorization flow

Supported today:

- Authorization Code flow
- PKCE for public clients
- Optional PKCE for confidential clients
- `response_mode=query`
- `response_mode=fragment`
- `nonce`
- `prompt=none`
- `prompt=login`
- `prompt=consent`
- `prompt=select_account` parsing exists, but there is no completed account-selection UX yet
- `max_age`
- default scopes when none are supplied
- scope reduction to the intersection of requested, client-allowed, and user-authorized scopes

Current limitations:

- `response_type=code` is the only supported response type
- `request` parameter is explicitly not supported
- discovery reports `request_parameter_supported=false` and `claims_parameter_supported=false`

### Token grants

The token endpoint supports:

- `authorization_code`
- `refresh_token`
- `client_credentials`

Notes:

- `id_token` is returned when `openid` is in scope.
- `refresh_token` is returned when `offline_access` is in scope.
- Public clients must use PKCE.
- Confidential clients can authenticate with HTTP Basic auth or body parameters.

### UserInfo

The userinfo endpoint is protected by a bearer access token and requires the token scope set to include `openid`.

Returned claims are filtered by the scope-to-claim mapping and then resolved by the provider and optional claim resolver.

### Revocation and introspection

The library also includes:

- token revocation support
- token introspection support
- refresh token family revocation when refresh token reuse is detected

## Standard Scopes and Claims

The standard scope constants included in the library are:

- `openid`
- `profile`
- `email`
- `address`
- `phone`
- `offline_access`

The standard claim constants include core OIDC claims such as:

- `sub`
- `iss`
- `aud`
- `exp`
- `iat`
- `nonce`
- `auth_time`
- `name`
- `given_name`
- `family_name`
- `preferred_username`
- `email`
- `email_verified`
- `phone_number`
- `address`
- `scope`
- `jti`
- `client_id`

The provider decides which claims belong to which scopes through `OnGetScopeToClaimsMap`.

## Claim Resolution Architecture

Claim resolution is intentionally split in two steps.

### Step 1: determine which claims are allowed

The provider builds a scope-to-claim map using `tOidcScopeClaimsMap`. This map tells the library:

- which scopes exist
- which claims each scope unlocks
- whether a scope is considered a system scope
- what audience should be attached for that scope

### Step 2: resolve actual values

Once the library knows which claims are allowed, it resolves values from:

- `OnGetUserInfo`
- `OnGetClientInfo`
- `cOidcClaimResolver`
- built-in fallback logic for standard/system claims

The custom resolver exists exactly for cases where the library cannot know where a claim lives in your application data model.

`cOidcClaimResolver` exposes `OnResolveClaim(...)`, allowing developers to map custom claims to any source they want. For example, a custom claim may come from:

- a user table
- a role table
- a customer table
- an external service
- computed business logic

This means the library does not hardcode custom claim storage. It only defines the moment in the pipeline where the value must be supplied.

## Standard Provider Responsibilities

`cOidcProviderStandard` is the default persistence implementation. It expects a set of OIDC-related DataDictionaries and tables to exist.

Its standard behavior includes:

- loading clients, redirect URIs, and allowed client scopes
- saving authorization codes
- loading and consuming authorization codes
- persisting refresh token state
- looking up refresh tokens by `jti` or access-token `jti`
- revoking single refresh tokens and whole refresh token families
- loading scope definitions and scope descriptions
- saving user consent and consent audit records
- saving request audit records
- validating client secrets
- deriving user-authorized scopes from roles and role-scope assignments
- using `psApplicationBaseUrl` as the application issuer/base URL

If your application already has its own persistence model, you can subclass `cOidcProvider` instead and implement only the required events.

## Session Integration

The library also includes `cOidcSessionManager` for the server's own web session handling.\*

This object is separate from the OAuth handler but fits naturally into the same architecture:

- it validates the web session against the access token
- it can silently refresh using the refresh token
- it stores access and refresh tokens in cookies
- it can authenticate login form credentials
- it adds a custom `sk` claim to bind tokens to the session cookie

This is especially useful when the same application is both:

- the authorization server
- and the web app that hosts the login/consent UI

\*Has not been tested thoroughly and is a proof-of-concept as of version 1.1.0

## Default Wiring

The library includes default objects that show the intended composition:

- `Oidc\OidcDefaultKeyStore.wo`
- `Oidc\OidcDefaultProvider.wo`
- `Oidc\OidcDefaultHandler.wo`
- `Oidc\OidcDefaultWellKnown.wo`

The default handler wires the provider, login view, and consent view together. The default well-known handler wires the provider, key store, and handler together.

In the demo application, the main setup is:

- load the default login view
- load the default consent view
- use the default handler
- set `psApplicationBaseUrl` on the default provider
- use the default well-known handler
- optionally attach a custom claim resolver

## Practical Integration Rules

When integrating this library, the most important rules are:

1. The provider must know the application base URL.
2. The handler must know the provider, login view, and consent view.
3. The login and consent views must each know the provider.
4. The well-known handler must know the provider, key store, and handler.
5. The provider must either implement or inherit working persistence for clients, codes, scopes, consent, and refresh token state.
6. The key store must contain at least one valid key pair and one active key identifier.

If any of these handles are missing, the library will fail early and intentionally.

## Current Implementation Notes

These points are worth knowing up front because they reflect the code as it exists today:

- The issuer is derived from the provider base URL and is normalized with a trailing slash where needed.
- Redirect URIs must match registered values exactly, except localhost/127.0.0.1 ports are normalized for validation.
- Authorization codes expire after `piAuthCodeExpiration` seconds in the handler. The default is 300 seconds.
- The handler audits supported endpoint calls after request completion.
- The discovery document includes revocation and introspection endpoints.
- The discovery document currently advertises `authorization_code`, `refresh_token`, and `client_credentials` grant types.
- The discovery document advertises `EdDSA` and `RS256` as ID token signing algorithms, while JWKS output is currently RSA-shaped only. In practice, use this combination carefully and verify it against your chosen key type.

## Summary

This library is best understood as a layered OIDC server:

- the key store owns keys
- the provider owns application data and token creation
- the login and consent views own end-user interaction
- the handler owns OAuth/OIDC protocol processing
- the well-known handler publishes metadata for clients
- the claim resolver gives developers a clean hook for custom claims

That separation is the main architectural idea of the library. It keeps protocol code generic while allowing the application to control identity data, consent, authorization, branding, and custom claims.
