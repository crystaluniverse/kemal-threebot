require "kemal"
require "uuid"
require "sodium"
require "base64"
require "http/params"
require "json"
require "http/client"
require "./errors"
require "kemal-session"
require "uri"

module Threebot
  class ThreebotResponse
    include JSON::Serializable

    property doubleName : String
    property signedAttempt : String
  end

  class ThreebotData
    include JSON::Serializable

    property nonce : String
    property ciphertext : String
  end

  class ThreebotSignedData
    include JSON::Serializable

    property doubleName : String
    property signedState : String
    property data : ThreebotData
    property randomRoom : String
    property appId : String
    property selectedImageId : Int32
  end

  class ThreebotUser
    include JSON::Serializable

    property doublename : String
    property publicKey : String
  end

  class UserEmail
    include JSON::Serializable

    property email : String
    property sei : String
  end

  class UserData
    include JSON::Serializable

    property email : UserEmail
  end

  class KycResponse
    include JSON::Serializable

    property email : String
    property identifier : String

  end

  @@seed = ""
  @@threebot_login_ur = "https://login.threefold.me"
  @@open_kyc_url = "https://openkyc.live/verification/verify-sei"

  def self.set_seed(seed)
    @@seed = seed
  end

  def self.set_threebot_login_url(url)
    @@threebot_login_ur = url
  end

  def self.open_kyc_url(url)
    @@open_kyc_url = url
  end

  if ENV.has_key?("SEED")
    @@seed  = Base64.decode_string(ENV["SEED"])
  end

  # production "https://login.threefold.me"
  if ENV.has_key?("@@threebot_login_ur")
    @@threebot_login_ur = ENV["@@threebot_login_ur"]
  end

  # production "https://openkyc.live/verification/verify-sei"
  if ENV.has_key?("open_kyc_url")
    @@open_kyc_url = ENV["open_kyc_url"]
  end

  # to be overriden by your application
  def threebot_login(env, email, username); end
  

  # backend mode end points
  get "/threebot/login" do |env|
      if @@seed  == ""
        raise "SEED is missing, either set it in your module or as an environment variable"
      end
      secret = Sodium::Sign::SecretKey.new seed: Base64.decode_string(@@seed).to_slice
      publickey = secret.public_key.to_curve25519
      
      state = UUID.random().to_s.gsub('-', "")
      env.session.string("state", state)
            
      encoded = HTTP::Params.encode(
          {"appid" => env.request.host_with_port.not_nil!,
            "scope" =>  "{\"user\": true, \"email\": true}",
            "publickey" => Base64.strict_encode(publickey.to_slice),
            "redirecturl" => "/threebot/callback",
            "state" => state
          })
      
      env.response.status_code = 302
      env.response.headers.add("Location", %(#{@@threebot_login_ur}?#{encoded}&#{env.request.query_params.to_s}))
      env
  end
  
  get "/threebot/callback" do |env|
    if @@seed  == ""
      raise "SEED is missing, either set it in your module or as an environment variable"
    end

      secret = Sodium::Sign::SecretKey.new seed: Base64.decode_string(@@seed).to_slice
      publickey = secret.public_key.to_curve25519

      if ! env.request.query_params.has_key?("signedAttempt")
          env.response.status_code = 400
          env.response.print "Bad Request - signedAttempt param is missing"
          env
      end
      
      threebot_res = nil
      response = nil

      begin
          threebot_res = ThreebotResponse.from_json(env.request.query_params["signedAttempt"])
          response = HTTP::Client.get %(#{@@threebot_login_ur}/api/users/) + threebot_res.not_nil!.doubleName
          if ! response.status_code == 200
              env.response.print "Bad Request - can not get user public key"
              env
          end
      rescue exception
          env.response.print "Bad Request - signedAttempt param is not valid"
          env
      end

      user_public_key = nil

      begin
          user = ThreebotUser.from_json(response.not_nil!.body)
          user_public_key_slice = Base64.decode(user.publicKey).to_slice
          user_public_key = Sodium::Sign::PublicKey.new(user_public_key_slice)
      rescue exception
          env.response.print "Bad Request - can not get user public key"
          env
      end

      sig_msg = Base64.decode(threebot_res.not_nil!.signedAttempt)
      
      signature = sig_msg[0..63]
    
      msg = sig_msg[64 .. sig_msg.size - 1]
      begin
        verified = user_public_key.not_nil!.verify_detached(msg, signature)
      rescue
        env.response.print "Bad Request - can not verify data"
        env
      end
      verified_data = ThreebotSignedData.from_json(String.new msg)
      
      state = verified_data.signedState
      
      session_state = env.session.string?("state")
      if session_state.nil? || session_state != state
        halt env, status_code: 400, response: "Invalid state"
      end

      nonce = Base64.decode(verified_data.data.nonce)
      ciphertext = Base64.decode(verified_data.data.ciphertext)

      sekret_curve = secret.to_curve25519
      public_curve = user_public_key.not_nil!.to_curve25519

      sekret_curve.box public_curve do |box|
        
        begin
          decrypted = box.decrypt ciphertext, nonce: Sodium::Nonce.new nonce
        rescue exception
          halt env, status_code: 400, response: "Can not decrypt data"
        end
        
        data = UserData.from_json(String.new(decrypted))
        email = data.email.email
        sei = data.email.sei
        response = HTTP::Client.post @@open_kyc_url, headers: HTTP::Headers{"Content-Type" => "application/json"}, body: %({"signedEmailIdentifier": "#{sei}"})
        if  response.status_code != 200
          halt env, status_code: 400, response: "Email not verified"
        end
        data = KycResponse.from_json(response.body)
        threebot_login(env, data.email, data.identifier)
      end
  end

  # frontend mode end points
  # call with /threebot/login/url?callback={/blah} where /blah is your frontend point
  get "/threebot/login/url" do |env|
    if @@seed  == ""
      raise "SEED is missing, either set it in your module or as an environment variable"
    end

    secret = Sodium::Sign::SecretKey.new seed: Base64.decode_string(@@seed).to_slice
    publickey = secret.public_key.to_curve25519

    if ! env.request.query_params.has_key?("callback")
      env.response.status_code = 400
      env.response.print "Bad Request - callback query param is required"
      env
    end

    state = UUID.random().to_s.gsub('-', "")
    env.session.string("state", state)
    callback = env.request.query_params["callback"]
    env.request.query_params.delete("callback")
    
    encoded = HTTP::Params.encode(
        {"appid" => env.request.host.not_nil!,
          "scope" =>  "{\"user\": true, \"email\": true}",
          "publickey" => Base64.strict_encode(publickey.to_slice),
          "redirecturl" => URI.decode(callback),
          "state" => state
        })
    
    %(#{@@threebot_login_ur}?#{encoded}&#{env.request.query_params.to_s}) 
  end
end
