require "./spec_helper"
require "sodium"
require "base64"

it "Generate seed" do 
    secret = Sodium::Sign::SecretKey.new
    puts Base64.strict_encode(secret.seed.to_slice)
end

