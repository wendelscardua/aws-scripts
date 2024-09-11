#!/usr/bin/ruby
# frozen_string_literal: true

def usage
  puts 'update-ip.rb --description|-d <description> --sg <sg-name> [--ip <ip>]'
  puts 'update-ip.rb --help|-h'
end

def usage!
  usage
  exit 1
end

description = nil
sg_name = nil
ip = nil

while ARGV.any?
  arg = ARGV.shift
  case arg
  when /\A(--description|-d)=/
    description = arg.gsub(/^(--description|-d)=/, '')
    usage! if description.empty?
  when /\A(--description|-d)\z/
    description = ARGV.shift
    usage! if description.nil?
  when /\A(--help|-h)\z/
    usage
    exit 0
  when /\A(--ip)=/
    ip = arg.gsub(/^(--ip)=/, '')
    usage! if ip.empty?
  when /\A(--ip)\z/
    ip = ARGV.shift
    usage! if ip.nil?
  when /\A(--sg)=/
    sg_name = arg.gsub(/^(--sg)=/, '')
    usage! if sg_name.empty?
  when /\A(--sg)\z/
    sg_name = ARGV.shift
    usage! if sg_name.nil?
  else
    usage!
  end
end

usage! unless sg_name
usage! unless description

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

web_accessible = ec2_client.describe_security_groups.security_groups.find do |sg|
  sg.group_name == sg_name
end || raise('Security Group not found')

old_cidr_ip = web_accessible.ip_permissions
                            .flat_map(&:ip_ranges)
                            .find { |range| range.description == description }
                            .cidr_ip || raise('Old CIDR IP not found')

new_cidr_ip = "#{ip || Net::HTTP.get('api.ipify.org', '/')}/32"

puts "Will replace #{old_cidr_ip} with #{new_cidr_ip}"

permissions = web_accessible.ip_permissions
                            .map { |perm| [perm.from_port, perm.to_port, perm.ip_ranges.select { |range| range.description == description }.map(&:cidr_ip)] }

permissions.each do |from_port, to_port, old_cidr_ips|
  old_cidr_ips.each do |old_cidr_ip|
    puts " Revoking port #{from_port}:#{to_port} for #{old_cidr_ip}"
    ec2_client.revoke_security_group_ingress group_name: sg_name,
                                             ip_permissions: [
                                               {
                                                 ip_protocol: 'tcp',
                                                 from_port:,
                                                 to_port:,
                                                 ip_ranges: [
                                                   { cidr_ip: old_cidr_ip, description: }
                                                 ]
                                               }
                                             ]
  end
rescue StandardError => e
  puts 'Error: ', e.message
  binding.pry
end

permissions.each do |from_port, to_port|
  puts " Authorizing port #{from_port}:#{to_port} to #{new_cidr_ip}"
  ec2_client.authorize_security_group_ingress group_name: sg_name,
                                              ip_permissions: [
                                                {
                                                  ip_protocol: 'tcp',
                                                  from_port:,
                                                  to_port:,
                                                  ip_ranges: [
                                                    { cidr_ip: new_cidr_ip, description: description }
                                                  ]
                                                }
                                              ]
rescue StandardError => e
  puts 'Error: ', e.message
  binding.pry
end
