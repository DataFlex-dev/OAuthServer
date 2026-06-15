INSERT INTO OidcScope(ScopeName, DisplayName, Description, Claims, IsSystemScope, Audience) 
VALUES ('profile', 'View your profile data', 'Your first name, last name, nickname, profile image, birthday etc.', 'name given_name family_name middle_name nickname username profile picture', 1, NULL),
       ('email', 'View your email address', 'Your email and whether it is verified by us.', 'email email_verified', 1, NULL),
       ('offline_access', 'Keep you signed in', 'Keep your session alive on your behalf', NULL, 1, NULL),
        ('openid', 'View your DataFlex Account data', 'Your name, username, email, phone number etc.', 'sub iss aud exp iat nonce auth_time name', 1, '<YOUR SYSTEM IDENTIFIER>');