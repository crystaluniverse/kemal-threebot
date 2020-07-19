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

##### Export needed environment vars. before running your server code

```
export SEED="sY4dAEWZXsPQEMOHzP65hNeDr4+7D0D6fbEm2In22t0="
export OPEN_KYC_URL=https://openkyc.live/verification/verify-sei
export THREEBOT_LOGIN_URL=https://login.threefold.me
```
##### Usage (Kemal.rc)

- You must include `Threebot` module
- You must provide `def threebot_login(context, email, username)` method with your login logic, including any redirection after successful login in case you are running a `Server side mode` or returning API token in case of `Client side mode`
- 
  ```crystal
  require "threebot"

  include Threebot

  def threebot_login(context, email, username)
    env.session.string("token", "***&&&&secureToken&&&&&&***")
    env.session.string("username", username)
    env.session.string("email", email)
    env.session.string?("token")
  end
  ```

## Warning
This library uses `kemal-session` which is by default non persistent
This means in your original app you must provice a `kemal seesion backend` if you want your sessions to be persistent

for instance, in **threefold**, we use bcdb and for persistenting sessions in bcdb
you should add the [kemal-session-bcdb](https://github.com/crystaluniverse/kemal-session-bcdb) to your application

```yaml
  dependencies:
    threebot:
      github: crystaluniverse/kemal-session-bcdb
```

then configure the session expiration time like
````
  require "kemal"
  require "kemal-session"
  require "kemal-session-bcdb"

  Kemal::Session.config do |config|
    config.cookie_name = "test"
    config.secret = "a_secret"
    config.engine = Kemal::Session::BcdbEngine.new(unixsocket= "/tmp/bcdb.sock", namespace = "kemal_sessions", key_prefix = "kemal:session:")
    config.timeout = Time::Span.new hours: 200, minutes: 0, seconds: 0
  end
```