-- =========================================================
-- CONFIGURATION
-- =========================================================
DECLARE @CreateOidcBaseSchema BIT = 1;   -- Core OIDC tables (0 = skip)
DECLARE @CreateOidcRoles BIT = 1;        -- Optional role tables (0 = skip)

-- IMPORTANT: Before running this script it is important to change the subId/UserId fields to the same type and length as your WebAppUser primary key field (or any other custom table you might use)!
-- The fields are:
-- OidcAuthorizationCode.UserId
-- OidcUserConsent.SubId
-- OidcUserConsentAudit.SubId
-- OidcUserRequestAudit.SubId
-- OidcRevokedRefreshToken.SUB
-- OidcUserRole.SubId


/* ========================================================
   BASE OIDC SCHEMA
   ======================================================== */
IF @CreateOidcBaseSchema = 1
BEGIN

    -- =====================================================
    -- CLIENT TABLE
    -- =====================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcClient')
    BEGIN
        CREATE TABLE OidcClient (
            ClientId VARCHAR(64) NOT NULL,
            ClientName NVARCHAR(255) NOT NULL,
            ClientDescription NVARCHAR(2048),
            ClientLogoURL VARCHAR(2048),
            ClientBrandColor VARCHAR(7),
            ClientType VARCHAR(12) NOT NULL,
            ClientSecret VARCHAR(255),
            IdTokenLifetime BIGINT NOT NULL,
            AccessTokenLifetime BIGINT NOT NULL,
            RefreshTokenLifetime BIGINT NOT NULL,
            [Enabled] BIT NOT NULL,
            CreatedAt DATETIME2 NOT NULL,
            SecretDisplay VARCHAR(3) NULL,
            CONSTRAINT PK_OidcClient PRIMARY KEY CLUSTERED (ClientId)
        );

        CREATE INDEX OidcClient_INDEX001 
            ON OidcClient ([Enabled], ClientId);
    END


    -- =====================================================
    -- OIDC SCOPE TABLE
    -- =====================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcScope')
    BEGIN
        CREATE TABLE OidcScope (
            ScopeName VARCHAR(128) NOT NULL,
            DisplayName NVARCHAR(255) NOT NULL,
            Description NVARCHAR(1000) NULL,
            Claims NVARCHAR(4000) NULL,
            IsSystemScope BIT NOT NULL DEFAULT 0,
            Audience VARCHAR(2000) NULL,
            CONSTRAINT PK_OidcScope PRIMARY KEY CLUSTERED (ScopeName)
        );
    END


    -- =====================================================
    -- CALLBACK URL TABLE
    -- =====================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcCallbackUrl')
    BEGIN
        CREATE TABLE OidcCallbackUrl (
            ClientId VARCHAR(64) NOT NULL,
            CallbackUrl VARCHAR(255) NOT NULL,
            CONSTRAINT PK_OidcCallbackUrl PRIMARY KEY CLUSTERED (ClientId, CallbackUrl),
            CONSTRAINT FK_OidcCallbackUrl_Client
                FOREIGN KEY (ClientId)
                REFERENCES OidcClient(ClientId)
                ON DELETE CASCADE
                ON UPDATE CASCADE
        );
    END


    -- =====================================================
    -- AUTHORIZATION CODE TABLE
    -- =====================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcAuthorizationCode')
    BEGIN
        CREATE TABLE OidcAuthorizationCode (
            AuthCode VARCHAR(64) NOT NULL,
            Client_id VARCHAR(64) NOT NULL,
            RedirectURI VARCHAR(2048) NOT NULL,
            UserID VARCHAR(255) NOT NULL,
            Scope VARCHAR(4000) NOT NULL,
            Nonce VARCHAR(64) NULL,
            CodeChallenge VARCHAR(128) NOT NULL,
            CodeChallengeMethod VARCHAR(5) NOT NULL,
            CreatedAt DATETIME2,
            Valid BIT NOT NULL,
            ScopeChanged BIT NOT NULL DEFAULT 0,
            CONSTRAINT PK_OidcAuthorizationCode PRIMARY KEY CLUSTERED (AuthCode),
            CONSTRAINT FK_OidcAuthorizationCode_Client
                FOREIGN KEY (Client_id)
                REFERENCES OidcClient(ClientId)
                ON DELETE CASCADE
                ON UPDATE CASCADE
        );

        CREATE UNIQUE INDEX OidcAuthorizationCode_INDEX001 
            ON OidcAuthorizationCode (Valid, AuthCode);
    END


    -- =====================================================
    -- REVOKED REFRESH TOKEN TABLE
    -- =====================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcRevokedRefreshToken')
    BEGIN
        CREATE TABLE OidcRevokedRefreshToken (
            JTI VARCHAR(64) NOT NULL,
            Family_ID VARCHAR(64) NOT NULL,
            SUB VARCHAR(255) NOT NULL,
            Client_id VARCHAR(64) NOT NULL,
            IAT DATETIME2 NOT NULL,
            [EXP] DATETIME2 NOT NULL,
            Used BIT NOT NULL,
            Revoked BIT NOT NULL,
            AccessTokenJti VARCHAR(64) NOT NULL,
            CONSTRAINT PK_OidcRevokedRefreshToken PRIMARY KEY CLUSTERED (JTI),
            CONSTRAINT FK_OidcRevokedRefreshToken_Client
                FOREIGN KEY (Client_id)
                REFERENCES OidcClient(ClientId)
                ON DELETE CASCADE
                ON UPDATE CASCADE
        );

        CREATE UNIQUE INDEX OidcRevokedRefreshToken_INDEX001 
            ON OidcRevokedRefreshToken (Family_ID, JTI);

        CREATE UNIQUE INDEX OidcRevokedRefreshToken_INDEX002 
            ON OidcRevokedRefreshToken ([EXP], JTI);

        CREATE UNIQUE INDEX OidcRevokedRefreshToken_INDEX003 
            ON OidcRevokedRefreshToken (AccessTokenJti);
    END


    -- =====================================================
    -- CLIENT SCOPE TABLE
    -- =====================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcClientScope')
    BEGIN
        CREATE TABLE OidcClientScope (
            ClientId VARCHAR(64) NOT NULL,
            Scope VARCHAR(64) NOT NULL,
            CONSTRAINT PK_OidcClientScope PRIMARY KEY CLUSTERED (ClientId, Scope),
            CONSTRAINT FK_OidcClientScope_Client
                FOREIGN KEY(ClientId)
                REFERENCES OidcClient(ClientId)
                ON DELETE CASCADE
        );
    END


    -- =====================================================
    -- USER CONSENT TABLE
    -- =====================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcUserConsent')
    BEGIN
        CREATE TABLE OidcUserConsent (
            ClientId VARCHAR(64) NOT NULL,
            SubId VARCHAR(255) NOT NULL,
            Scopes NVARCHAR(4000) NOT NULL,
            GrantedAt DATETIME2 NOT NULL,
            CONSTRAINT PK_OidcUserConsent PRIMARY KEY CLUSTERED (ClientId, SubId)
        );
    END


    -- =====================================================
    -- USER CONSENT AUDIT TABLE
    -- =====================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcUserConsentAudit')
    BEGIN
        CREATE TABLE OidcUserConsentAudit (
            AuditId BIGINT IDENTITY(1,1) NOT NULL,
            ClientId VARCHAR(64) NOT NULL,
            SubId VARCHAR(255) NOT NULL,
            Scopes NVARCHAR(4000) NOT NULL,
            Action VARCHAR(16) NOT NULL,
            PerformedAt DATETIME2 NOT NULL,
            PerformedBy VARCHAR(20) NULL,
            CONSTRAINT PK_OidcUserConsentAudit PRIMARY KEY CLUSTERED (AuditId)
        );
    END


    -- =====================================================
    -- REQUEST AUDIT TABLE
    -- =====================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcRequestAudit')
    BEGIN
        CREATE TABLE OidcRequestAudit (
            AuditId BIGINT IDENTITY(1,1) NOT NULL,
            Timestamp DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
            Endpoint VARCHAR(128) NOT NULL,
            ClientId VARCHAR(64) NOT NULL,
            SubId NVARCHAR(255) NULL,
            IPAddress VARCHAR(45) NULL,
            HttpMethod VARCHAR(8) NOT NULL,
            RequestData NVARCHAR(MAX) NULL,
            ResponseStatus INT NOT NULL,
            ErrorCode VARCHAR(64) NULL,
            ErrorMessage VARCHAR(512) NULL,
            Scope NVARCHAR(4000) NULL,
            CONSTRAINT PK_OidcRequestAudit PRIMARY KEY CLUSTERED (AuditId)
        );
    END

END



/* ========================================================
   OPTIONAL ROLE TABLES
   ======================================================== */
IF @CreateOidcRoles = 1
BEGIN

    -- Roles depend on OidcScope (so base schema must exist)

    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcRole')
    BEGIN
        CREATE TABLE OidcRole (
            RoleId INT IDENTITY(1,1) NOT NULL,
            RoleName NVARCHAR(255) NOT NULL,
            Description NVARCHAR(1000) NULL,
            ClientId VARCHAR(64) NULL,
            IsDefault BIT NOT NULL DEFAULT 0,
            CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
            CONSTRAINT PK_OidcRole PRIMARY KEY CLUSTERED (RoleId)
        );

        CREATE UNIQUE INDEX OidcRole_INDEX001
            ON OidcRole(RoleName, ClientId);
			
		CREATE UNIQUE INDEX OidcRole_INDEX002
			ON OidcRole (IsDefault, RoleId);
    END


    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcRoleScopes')
    BEGIN
        CREATE TABLE OidcRoleScopes (
            RoleId INT NOT NULL,
            Scope VARCHAR(128) NOT NULL,
            CONSTRAINT PK_OidcRoleScopes PRIMARY KEY CLUSTERED (RoleId, Scope),
            CONSTRAINT FK_OidcRoleScopes_Role
                FOREIGN KEY (RoleId)
                REFERENCES OidcRole(RoleId)
                ON DELETE CASCADE
                ON UPDATE CASCADE,
            CONSTRAINT FK_OidcRoleScopes_Scope
                FOREIGN KEY (Scope)
                REFERENCES OidcScope(ScopeName)
                ON DELETE CASCADE
                ON UPDATE CASCADE
        );
    END


    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OidcUserRole')
    BEGIN
        CREATE TABLE OidcUserRole (
            SubId VARCHAR(255) NOT NULL,
            RoleId INT NOT NULL,
            AssignedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
            CONSTRAINT PK_OidcUserRole PRIMARY KEY CLUSTERED (SubId, RoleId),
            CONSTRAINT FK_OidcUserRole_Role
                FOREIGN KEY (RoleId)
                REFERENCES OidcRole(RoleId)
                ON DELETE CASCADE
                ON UPDATE CASCADE
        );
    END

END
