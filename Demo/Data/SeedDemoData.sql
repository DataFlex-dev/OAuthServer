SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM OidcRole WHERE RoleName = 'Demo Admin' AND ClientId = '')
AND NOT EXISTS (SELECT 1 FROM OidcRole WHERE RoleName = 'Default Role' AND ClientId = '')
BEGIN
    UPDATE OidcRole
    SET RoleName = 'Default Role',
        Description = 'Allows the standard OpenID Connect demo scopes.',
        IsDefault = 1
    WHERE RoleName = 'Demo Admin'
      AND ClientId = '';
END;

IF EXISTS (SELECT 1 FROM OidcRole WHERE RoleName = 'Example API' AND ClientId = '')
AND NOT EXISTS (SELECT 1 FROM OidcRole WHERE RoleName = 'Example' AND ClientId = '')
BEGIN
    UPDATE OidcRole
    SET RoleName = 'Example',
        Description = 'Allows access to the demo example API scope.',
        IsDefault = 0
    WHERE RoleName = 'Example API'
      AND ClientId = '';
END;

INSERT INTO OidcScope (ScopeName, DisplayName, Description, Claims, IsSystemScope, Audience)
SELECT v.ScopeName, v.DisplayName, v.Description, v.Claims, v.IsSystemScope, v.Audience
FROM (VALUES
    ('example_scope', 'Access the example API', 'Allows access to the demo example API scope.', NULL, 0, NULL)
) AS v (ScopeName, DisplayName, Description, Claims, IsSystemScope, Audience)
WHERE NOT EXISTS (
    SELECT 1
    FROM OidcScope s
    WHERE s.ScopeName = v.ScopeName
);

INSERT INTO OidcClient (
    ClientId,
    ClientName,
    ClientDescription,
    ClientLogoURL,
    ClientBrandColor,
    ClientType,
    ClientSecret,
    IdTokenLifetime,
    AccessTokenLifetime,
    RefreshTokenLifetime,
    [Enabled],
    CreatedAt
)
SELECT
    v.ClientId,
    v.ClientName,
    v.ClientDescription,
    v.ClientLogoURL,
    v.ClientBrandColor,
    v.ClientType,
    v.ClientSecret,
    v.IdTokenLifetime,
    v.AccessTokenLifetime,
    v.RefreshTokenLifetime,
    v.[Enabled],
    SYSDATETIME()
FROM (VALUES
    ('demo-public-client',       'Demo Public Client',       'Local demo public OAuth/OIDC client.',       NULL, NULL, 'public',       NULL,                 3600, 3600, 2592000, 1),
    ('demo-confidential-client', 'Demo Confidential Client', 'Local demo confidential OAuth/OIDC client.', NULL, NULL, 'confidential', 'V1$1$FKPdpOxu3EbGDzW3BbE0qQ==$420000$Cy9GxdjhII97T3W2e3WFSNTxd1skzFOkZwW0TlhI8R3IUpDimmFtRAIBx5G4au/ginCeybTqJqUlagiKTx6Htg==', 3600, 3600, 2592000, 1)
) AS v (ClientId, ClientName, ClientDescription, ClientLogoURL, ClientBrandColor, ClientType, ClientSecret, IdTokenLifetime, AccessTokenLifetime, RefreshTokenLifetime, [Enabled])
WHERE NOT EXISTS (
    SELECT 1
    FROM OidcClient c
    WHERE c.ClientId = v.ClientId
);

INSERT INTO OidcCallbackUrl (ClientId, CallbackUrl)
SELECT v.ClientId, v.CallbackUrl
FROM (VALUES
    ('demo-public-client',       'http://localhost/oauth/callback'),
    ('demo-public-client',       'https://oidcdebugger.com/debug'),
    ('demo-confidential-client', 'http://localhost/oauth/callback'),
    ('demo-confidential-client', 'https://oidcdebugger.com/debug')
) AS v (ClientId, CallbackUrl)
WHERE NOT EXISTS (
    SELECT 1
    FROM OidcCallbackUrl cb
    WHERE cb.ClientId = v.ClientId
      AND cb.CallbackUrl = v.CallbackUrl
);

INSERT INTO OidcClientScope (ClientId, Scope)
SELECT c.ClientId, s.Scope
FROM (VALUES
    ('demo-public-client'),
    ('demo-confidential-client')
) AS c (ClientId)
CROSS JOIN (VALUES
    ('openid'),
    ('offline_access'),
    ('profile'),
    ('email'),
    ('example_scope')
) AS s (Scope)
WHERE NOT EXISTS (
    SELECT 1
    FROM OidcClientScope cs
    WHERE cs.ClientId = c.ClientId
      AND cs.Scope = s.Scope
);

INSERT INTO OidcRole (RoleName, Description, ClientId, IsDefault, CreatedAt)
SELECT v.RoleName, v.Description, v.ClientId, v.IsDefault, SYSDATETIME()
FROM (VALUES
    ('Default Role', 'Allows the standard OpenID Connect demo scopes.', '', 1),
    ('Example',      'Allows access to the demo example API scope.',    '', 0)
) AS v (RoleName, Description, ClientId, IsDefault)
WHERE NOT EXISTS (
    SELECT 1
    FROM OidcRole r
    WHERE r.RoleName = v.RoleName
      AND r.ClientId = v.ClientId
);

UPDATE OidcRole
SET IsDefault = 1
WHERE RoleName = 'Default Role'
  AND ClientId = '';

INSERT INTO OidcRoleScopes (RoleId, Scope)
SELECT r.RoleId, s.Scope
FROM OidcRole r
CROSS JOIN (VALUES
    ('openid'),
    ('offline_access'),
    ('profile'),
    ('email')
) AS s (Scope)
WHERE r.RoleName = 'Default Role'
  AND r.ClientId = ''
  AND NOT EXISTS (
      SELECT 1
      FROM OidcRoleScopes rs
      WHERE rs.RoleId = r.RoleId
        AND rs.Scope = s.Scope
  );

INSERT INTO OidcRoleScopes (RoleId, Scope)
SELECT r.RoleId, 'example_scope'
FROM OidcRole r
WHERE r.RoleName = 'Example'
  AND r.ClientId = ''
  AND NOT EXISTS (
      SELECT 1
      FROM OidcRoleScopes rs
      WHERE rs.RoleId = r.RoleId
        AND rs.Scope = 'example_scope'
  );

INSERT INTO OidcUserRole (SubId, RoleId, AssignedAt)
SELECT 'example-user', r.RoleId, SYSDATETIME()
FROM OidcRole r
WHERE r.RoleName = 'Example'
  AND r.ClientId = ''
  AND NOT EXISTS (
      SELECT 1
      FROM OidcUserRole ur
      WHERE ur.SubId = 'example-user'
        AND ur.RoleId = r.RoleId
  );

COMMIT TRANSACTION;
