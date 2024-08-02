#!/usr/bin/ruby
# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'aws-sdk-sts'
  gem 'base64'
  gem 'bigdecimal'
  gem 'dotini'
  gem 'ox'
  gem 'pry'
end

sts_client = Aws::STS::Client.new

identity = sts_client.get_caller_identity

puts "user_id: #{identity.user_id}"
puts "account: #{identity.account}"
puts "arn: #{identity.arn}"

mfa_arn = identity.arn.gsub(%r{:user/}, ':mfa/')
puts "assuming mfa arn is: #{mfa_arn}, is that correct? (Y/n) "

prompt = nil

loop do
  prompt = gets.chomp
  break if prompt =~ /\A[YyNn]?\z/
end

if prompt =~ /\A[Nn]\z/
  puts 'mfa arn: '
  mfa_arn = gets.chomp
end

puts 'Desired duration for session (in seconds) :'
duration = gets.to_i

puts 'MFA code: '
token_code = gets.chomp

response = sts_client.get_session_token(duration_seconds: duration, serial_number: mfa_arn, token_code: token_code)

credentials_file = File.join(Dir.home, '.aws', 'credentials')

credentials_ini = if File.exist?(credentials_file)
                    Dotini::IniFile.load(credentials_file)
                  else
                    Dotini::IniFile.new
                  end

credentials_ini['mfa']['aws_access_key_id'] = response.credentials.access_key_id
credentials_ini['mfa']['aws_secret_access_key'] = response.credentials.secret_access_key
credentials_ini['mfa']['aws_session_token'] = response.credentials.session_token
credentials_ini['mfa']['expiration'] = response.credentials.expiration

File.open(credentials_file, 'wb') do |file|
  credentials_ini.write(file)
end
