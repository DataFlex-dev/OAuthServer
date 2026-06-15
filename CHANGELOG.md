# Changelog

## Table of Contents
- [1.1.0](#110)

With every version, there are some improvements, the improvements are listed below per version number.
Current Version: 1.1.0

## 1.1.0
- Introduced the OAuthServer library as a DataFlex OAuth 2.0 / OpenID Connect authorization server implementation.
- Added the `cOidcKeyStore` architecture for registering multiple key pairs, selecting an active signing key, loading PEM key material from disk, and exposing in-memory JWK/JWKS data.
- Added the provider-centered architecture with `cOidcProvider` as the abstract integration point and `cOidcProviderStandard` as the default database-backed implementation.
- Added a clean separation between key management, provider logic, login UX, consent UX, HTTP protocol handling, and well-known endpoint publishing.
- Added `cOidcHandler` as the main `cWebHttpHandler` for OAuth/OIDC requests.
- Added `cOidcWellKnownHandler` to expose `/.well-known/openid-configuration` and `/.well-known/jwks.json`.
- Added support for the authorization endpoint, token endpoint, userinfo endpoint, revocation endpoint, and introspection endpoint.
- Added support for the Authorization Code flow.
- Added PKCE support for public clients and optional PKCE support for confidential clients.
- Added support for refresh tokens through the `offline_access` scope.
- Added support for the `client_credentials` grant for confidential clients.
- Added consent handling with a dedicated consent view and persistence hooks in the provider.
- Added login flow integration with a dedicated login view and continue URL handling back into the authorize endpoint.
- Added token generation through the provider so the handler does not need direct access to the key store.
- Added ID token, access token, and refresh token generation with scope-based claim filtering.
- Added scope-to-claim mapping through provider events and structs.
- Added `cOidcClaimResolver` so developers can resolve custom claims from any application-specific data source.
- Added standard claim fallback resolution based on `OnGetUserInfo` and client metadata.
- Added JWT validation through the provider/JWT layer, including issuer and expiration checks.
- Added refresh token state persistence, reuse detection, single-token revocation, and family revocation support in the standard provider.
- Added request audit logging and consent audit logging hooks to the provider architecture.
- Added default plug-and-play objects for the key store, provider, handler, and well-known handler.
- Added `cOidcSessionManager` integration for the hosting web application, including access token validation, silent refresh behavior, cookie-based token storage, and session binding through a custom claim.
- Added OpenID discovery metadata generation based on the configured provider and handler.
- Added support for the standard scopes `openid`, `profile`, `email`, `address`, `phone`, and `offline_access`.
- Added compatibility targeting for DataFlex 26.0, with earlier versions down to 23.0 expected to be possible but not treated as the primary supported target.
