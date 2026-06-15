# OAuthServer

DataFlex OAuth 2.0 / OpenID Connect server library.

This repository contains a reusable DataFlex library for building an OAuth 2.0 and OpenID Connect authorization server, plus a demo workspace that shows how the objects are wired together in a web application.

## Table Of Contents

- [Repository Layout](#repository-layout)
- [What The Library Provides](#what-the-library-provides)
- [Demo Workspace](#demo-workspace)
- [Compatibility](#compatibility)
- [External Components](#external-components)
- [Notes](#notes)

## Repository Layout

- `Library/`: the reusable OAuth/OIDC library
- `Demo/`: demo workspace using the library
- `Help/`: project documentation

## What The Library Provides

The library is built around a small set of cooperating classes:

- `cOidcKeyStore`: manages signing and validation keys
- `cOidcProvider` / `cOidcProviderStandard`: provides application data, persistence, and token generation
- login and consent views: handle end-user interaction in the authorization flow
- `cOidcHandler`: processes OAuth/OIDC protocol requests
- `cOidcWellKnownHandler`: exposes discovery and JWKS endpoints
- `cOidcClaimResolver`: extension point for custom claim mapping

Supported functionality in the current codebase includes:

- authorization code flow
- PKCE
- refresh tokens
- client credentials grant
- userinfo endpoint
- token revocation
- token introspection
- OpenID discovery
- JWKS publication
- consent persistence and audit logging
- custom claim resolution

More detailed architectural documentation is available in `Help/README.md`.

## Demo Workspace

The `Demo` workspace shows a complete integration using:

- the default key store
- the standard provider
- the default OIDC handler
- the well-known handler
- login and consent views
- a sample custom claim resolver

## Compatibility

Officially supported:

- DataFlex 26.0

Compatibility note:

- `23.0`, `24.0`, and `25.0` should also be possible, but these should be treated as compatibility targets rather than officially supported versions.*

## External Components

This library depends on DataFlex web framework classes and uses OpenSSL integration included in the library source.

## Notes

`*` Older DataFlex versions may work, but support expectations should be lower than for the primary supported target of DataFlex 26.0.
