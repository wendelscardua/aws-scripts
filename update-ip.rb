#!/usr/bin/ruby
# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'base64'
  gem 'bigdecimal'
  gem 'ox'
  gem 'aws-sdk-ec2'
  gem 'pry'
end

require 'net/http'

ec2_client = Aws::EC2::Client.new

sg_name, description = ARGV

web_accessible = ec2_client.describe_security_groups.security_groups.find do |sg|
  sg.group_name == sg_name
end || raise('Security Group not found')

old_cidr_ip = web_accessible.ip_permissions
                            .flat_map(&:ip_ranges)
                            .find { |range| range.description == description }
                            .cidr_ip || raise('Old CIDR IP not found')

new_cidr_ip = "#{Net::HTTP.get('api.ipify.org', '/')}/32"

puts "Will replace #{old_cidr_ip} with #{new_cidr_ip}"

[80, 443, 22].each do |port|
  ec2_client.revoke_security_group_ingress group_name: sg_name,
                                           ip_permissions: [
                                             {
                                               ip_protocol: 'tcp',
                                               from_port: port,
                                               to_port: port,
                                               ip_ranges: [
                                                 { cidr_ip: old_cidr_ip }
                                               ]
                                             }
                                           ]
rescue StandardError => e
  puts 'Error: ', e.message
  binding.pry
end

[80, 443, 22].each do |port|
  ec2_client.authorize_security_group_ingress group_name: sg_name,
                                              ip_permissions: [
                                                {
                                                  ip_protocol: 'tcp',
                                                  from_port: port,
                                                  to_port: port,
                                                  ip_ranges: [
                                                    { cidr_ip: new_cidr_ip, description: description }
                                                  ]
                                                }
                                              ]
rescue StandardError => e
  puts 'Error: ', e.message
  binding.pry
end
