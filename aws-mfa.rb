#!/usr/bin/ruby
# frozen_string_literal: true

def usage
  puts 'aws-mfa.rb [--arn-name|-n <arn-name>] [--duration|-d <seconds>] [--no-confirm|-Y] [--token|-t <otp-code>] '
  puts '           [--profile|-p <profile>]'
  puts 'aws-mfa.rb --help|-h'
end

def usage!
  usage
  exit 1
end

def flop!(message)
  puts message
  exit 1
end

arn_name = nil
duration = nil
no_confirm = false
token_code = nil
profile = 'mfa'

while ARGV.any?
  arg = ARGV.shift
  case arg
  when /\A(--duration|-d)=/
    duration = arg.gsub(/^(--duration|-d)=/, '')
    usage! if duration.empty?
    duration = duration.to_i
    flop! 'duration must be >= 900!' if duration < 900
  when /\A(--duration|-d)\z/
    duration = ARGV.shift
    usage! if duration.nil?
    duration = duration.to_i
    flop! 'duration must be >= 900!' if duration < 900
  when /\A(--help|-h)\z/
    usage
    exit 0
  when /\A(--arn-name|-n)=/
    arn_name = arg.gsub(/^(--arn-name|-n)=/, '')
    usage! if arn_name.empty?
  when /\A(--arn-name|-n)\z/
    arn_name = ARGV.shift
    usage! if arn_name.nil?
  when /\A(--no-confirm|-Y)\z/
    no_confirm = true
  when /\A(--token|-t)=/
    token_code = arg.gsub(/^(--token|-t)=/, '')
    usage! if token_code.empty?
  when /\A(--token|-t)\z/
    token_code = ARGV.shift
    usage! if token_code.nil?
  when /\A(--profile|-p)=/
    profile = arg.gsub(/^(--profile|-p)=/, '')
    usage! if profile.nil?
  when /\A(--profile|-p)\z/
    profile = ARGV.shift
    usage! if profile.nil?
  else
    usage!
  end
end

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
puts "arn:     #{identity.arn}"

mfa_arn = identity.arn.gsub(%r{:user/}, ':mfa/')
mfa_arn.gsub!(%r{:mfa/.*}, ":mfa/#{arn_name}") if arn_name

if no_confirm
  puts "mfa arn: #{mfa_arn}"
else
  print "assuming mfa arn is: #{mfa_arn}, is that correct? (Y/n) "

  prompt = nil

  loop do
    prompt = gets.chomp
    break if prompt =~ /\A[YyNn]?\z/
  end

  if prompt =~ /\A[Nn]\z/
    print 'mfa arn: '
    mfa_arn = gets.chomp
  end
end

while !duration
  print 'Desired duration for session (in seconds, >= 900): '
  duration = gets.to_i
  if duration < 900
    puts 'Duration must be >= 900 seconds'
    duration = nil
  end
end

unless token_code
  print 'MFA code: '
  token_code = gets.chomp
end

response = sts_client.get_session_token(duration_seconds: duration,
                                        serial_number: mfa_arn,
                                        token_code: token_code)

credentials_file = File.join(Dir.home, '.aws', 'credentials')

credentials_ini = if File.exist?(credentials_file)
                    Dotini::IniFile.load(credentials_file)
                  else
                    Dotini::IniFile.new
                  end

credentials_ini[profile]['aws_access_key_id'] = response.credentials.access_key_id
credentials_ini[profile]['aws_secret_access_key'] = response.credentials.secret_access_key
credentials_ini[profile]['aws_session_token'] = response.credentials.session_token
credentials_ini[profile]['expiration'] = response.credentials.expiration

File.open(credentials_file, 'wb') do |file|
  credentials_ini.write(file)
end
