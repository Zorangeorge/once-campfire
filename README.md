# Campfire

Campfire is a web-based chat application. It supports many of the features you'd
expect, including:

- Multiple rooms, with access controls
- Direct messages
- File attachments with previews
- Search
- Notifications (via Web Push)
- @mentions
- API, with support for bot integrations

## Running your own Campfire instance

Campfire's Docker image contains everything needed for a fully-functional,
single-machine deployment. This includes the web app, background jobs, caching,
file serving, and SSL. You can use our pre-built image at
`ghcr.io/basecamp/once-campfire:latest`, or build your own from this repo.

### Deploying with ONCE

The easiest way to self-host Campfire is with [ONCE](https://github.com/basecamp/once).
It will guide you through the initial set up and then keep your instance up to date automatically.

If you don't already have `once` installed, run this on the machine you want to run Campfire on:

```sh
curl https://get.once.com | sh
```

`once` will launch as soon as the install is finished. 

Choose Campfire from the list of applications, follow the instructions, and ONCE will take care of the rest.

If you prefer the command line to the dashboard, you can deploy directly:

```sh
once deploy ghcr.io/basecamp/once-campfire --host chat.example.com
```

### Deploying with Docker

If you'd rather run the Docker image yourself, you can read more about that in the [self-hosting guide](docs/self-hosting.md).

> [!TIP]
> When you start Campfire for the first time, you'll be guided through a wizard to create an admin account.
> The email address that you enter for the admin account will be visible on the sign-in page, it's there so
> that people have someone to contact if they need help with their account. If that bothers you, put in any
> email address you want and create yourself a new admin account.

### Single Sign-On (SSO)

Campfire supports SSO via OpenID Connect (OIDC), allowing integration with
identity providers such as Keycloak, Okta, Azure AD, and Google Workspace.
SSO is entirely optional — when no SSO environment variables are set, the login
page shows only the standard email/password form.

Both SSO and password authentication can coexist. Users who first registered with
a password will have their account automatically linked when they sign in via SSO
(matched by email address). New users signing in via SSO for the first time are
created automatically and do not need a join code.

To disable password-based registration (so new users can only join via SSO), set:

- `DISABLE_PASSWORD_REGISTRATION=true` - disables the join code registration
  page and hides the invite link from the admin panel. Existing users can still
  sign in with their password.

**OIDC configuration (multiple providers):**

- `OIDC_PROVIDERS` - comma-separated provider keys (for example: `google,github,keycloak`)
- For each key, define:
    - `OIDC_<KEY>_ISSUER` - issuer URL
    - `OIDC_<KEY>_CLIENT_ID` - client ID
    - `OIDC_<KEY>_CLIENT_SECRET` - client secret
    - `OIDC_<KEY>_REDIRECT_URI` - callback URL (for example `https://chat.example.com/auth/oidc_google/callback`)
- Optional per provider:
    - `OIDC_<KEY>_PROVIDER_NAME` - label shown on the sign-in button (defaults to titleized key)
    - `OIDC_<KEY>_SCOPE` - scopes separated by spaces or commas (defaults to `openid email profile`)
    - `OIDC_<KEY>_CLIENT_AUTH_METHOD` - client auth method (defaults to `basic`)
    - `OIDC_<KEY>_END_SESSION_ENDPOINT` - explicit RP-initiated logout endpoint (otherwise discovered from issuer metadata - `${OIDC_<KEY>_ISSUER}/.well-known/openid-configuration`)

Provider keys must use lowercase letters, numbers, and underscores.
When a user signs out from Campfire, the app also attempts OIDC RP-initiated
logout with the provider used for that login session and includes
`id_token_hint` when available.

## Development

You are welcome - and encouraged - to modify Campfire to your liking.
Please see our [development guide](docs/development.md) for how to get Campfire set up for local development.
