# Threebot

Threebot login module for [kemalcr.com](kemalcr.com) applications and for crystal lang in general
It supoprts 2 modes

**Server side mode**

Exposes the following API end points
  - `GET /threebot/login` : redirects to 3blot login page
  - `GET /threebot/callback` : callback after success authentication

You must override `def threebot_login(context, email, username)` in your serverside code with the post login logic including any redirections to other relartive urls like home page

**Client side mode** (Suitable for applications where frontend code is separate)

Exposes the following API end points
- `GET /threebot/login/url?callback={/path/to/frontend/callback_route}`
  - The frontend code can call this endpoint to get a 3bot login page full url, then redirect suer to it.The reaosn this is dynamic, because the frontend code must provice `?callback=` param to set the callback frontend endpoint that the user will be redirected to after successful authentication

- `GET /threebot/callback` 
your frontend callback endpoint provide by `?callback=` in the previous call must then do a `GET /threebot/callback` and pass the same params it obtained from 3botlogin, to validate user

You must override def `login(context, email, username)` in your serverside code with the post login logic, in this case returning an API token.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     threebot:
       github: crystaluniverse/kemal-threebot
   ```

2. Run `shards install`

## How to use

##### Generate (SEED) for your Application secret key if you don't have one
This secret key must be unique for your application, and must be used with the application all along

```
crystal spec spec/generate_seed.cr
```

##### Export needed environment vars. before running your server code (optional)

```
export SEED="sY4dAEWZXsPQEMOHzP65hNeDr4+7D0D6fbEm2In22t0="
export OPEN_KYC_URL=https://openkyc.live/verification/verify-sei
export THREEBOT_LOGIN_URL=https://login.threefold.me
```
##### Usage (Kemal.rc)

- You must include `Threebot` module
- You must provide `def threebot_login(context, email, username)` method with your login logic, including any redirection after successful login in case you are running a `Server side mode` or returning API token in case of `Client side mode`
- provide `seed` as environment variable or set it explicitly, otherwise use `Threebot.set_seed(your-seed)` **Required**
- provide `THREEBOT_LOGIN_URL` as environment variable , or use `set_threebot_login_url(url)` **Optional**
- provide `OPEN_KYC_URL` as environment variable , otherwise use `set_open_kyc_url(url)` **Optional**

- 
  ```crystal
require "kemal"
require "kemal-session"
require "kemal-session-bcdb"
require "threebot"

# save session in bcdb
Kemal::Session.config do |config|
  config.cookie_name = "test"
  config.secret = "a_secret"
  config.engine = Kemal::Session::BcdbEngine.new(unixsocket= "/home/hamdy/work/chat/bcdb1.sock", namespace = "kemal_sessions", key_prefix = "kemal:session:")
  config.timeout = Time::Span.new hours: 200, minutes: 0, seconds: 0
end

include Threebot

# set if not set using environment variables
Threebot.set_seed("muTjUU/xm8u0WnrhetiSHtJEwLT4lJQbmjEAtRXUBqg=")

def threebot_login(env, email, username)
  env.session.string("token", "***&&&&secureToken&&&&&&***")
  env.session.string("username", username)
  env.session.string("email", email)
  env.session.string?("token")
end

Kemal.run

  ```

