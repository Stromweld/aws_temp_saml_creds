#!/usr/bin/env ruby

# Inspired by python script https://awsiammedia.s3.amazonaws.com/public/sample/SAMLAPICLIADFS/0192721658_1562696757_blogversion_samlapi_python3.py

require 'base64'
require 'bundler/inline'
require 'io/console'
require 'rbconfig'

# Install required gems
gemfile do
  source 'https://rubygems.org'
  gem 'activesupport', require: 'active_support/core_ext/hash'
  gem 'aws-sdk-core', require: 'aws-sdk-core'
  gem 'ffi'
  gem 'clipboard', require: 'clipboard'
  gem 'mechanize', require: 'mechanize'
end

def list_resources(resources)
  i = 0
  resources.each do |res|
    puts "#{i}. #{res.split(',').first}"
    i += 1
  end
  pick_resource(resources)
end

def pick_resource(resources)
  puts "\nSpecify number to use:\n"
  value = Integer(gets)
  while  value > resources.size - 1
    puts "\nPlease enter number above:\n"
    value = Integer(gets)
  end
  resources.values_at(value).first
end

# Get user Input
puts "\nEnter AWS saml url to login to: "
url = STDIN.gets.chomp

puts "\nEnter AWS login username: "
user_name = STDIN.gets.chomp
puts "\nEnter AWS login password: "
password = STDIN.noecho(&:gets).chomp

os = RbConfig::CONFIG['host_os']

# Login to xcel pingfed site
mechanize = Mechanize.new
login_page = mechanize.get(url)
form = login_page.forms.first
form.field_with(id: 'username').value = user_name
form.field_with(id: 'password').value = password
login = form.submit

# Get SAML assertion
saml_assertion = login.form.fields.first.value
decoded = Base64.decode64(saml_assertion)
saml_xml = Hash.from_xml(decoded)

# Get list of AWS roles
roles_list = saml_xml['Response']['Assertion']['AttributeStatement']['Attribute'].find { |roles| roles['Name'].eql?('https://aws.amazon.com/SAML/Attributes/Role') }
roles = [].push(roles_list['AttributeValue']).flatten

# Select role if multiple are available, autoselect if only one available
select_role = if roles.empty?
                raise 'No AWS roles found'
              elsif roles.length < 2
                roles.first
              else
                list_resources(roles)
              end

# Get AWS temporary credentials
aws_client = Aws::STS::Client.new
aws_response = aws_client.assume_role_with_saml(
  {
    duration_seconds: 3600,
    principal_arn: select_role.split(',')[1],
    role_arn: select_role.split(',')[0],
    saml_assertion: saml_assertion,
  }
).to_h
aws_creds = aws_response[:credentials]

# Create shell commands to copy paste based on OS
cmd_creds = {}
case os
when /darwin|mac os|linux/
  cmd_creds['key'] = "export AWS_ACCESS_KEY_ID=\"#{aws_creds[:access_key_id]}\""
  cmd_creds['secret'] = "export AWS_SECRET_ACCESS_KEY=\"#{aws_creds[:secret_access_key]}\""
  cmd_creds['token'] = "export AWS_SESSION_TOKEN=\"#{aws_creds[:session_token]}\""
when /mswin|windows|cygwin|mingw32/
  cmd_creds['key'] = "$env:AWS_ACCESS_KEY_ID=\"#{aws_creds[:access_key_id]}\""
  cmd_creds['secret'] = "$env:AWS_SECRET_ACCESS_KEY=\"#{aws_creds[:secret_access_key]}\""
  cmd_creds['token'] = "$env:AWS_SESSION_TOKEN=\"#{aws_creds[:session_token]}\""
else
  raise "OS #{os} commands not found"
end

puts "\n"
puts "You selected role: #{select_role}"
puts "\n"
puts "Current Time is #{Time.now}"
puts "Session token expires at #{Time.parse(aws_creds[:expiration].to_s).localtime}"
puts "\n"
puts "export AWS_ACCESS_KEY_ID=\"#{aws_creds[:access_key_id]}\""
puts "export AWS_SECRET_ACCESS_KEY=\"#{aws_creds[:secret_access_key]}\""
puts "export AWS_SESSION_TOKEN=\"#{aws_creds[:session_token]}\""
puts "\n"

puts 'Do you want to copy these to the clip board?(y/n)'
exit(0) unless STDIN.gets.chomp.eql?('y')

Clipboard.copy("#{cmd_creds['key']}\r\n#{cmd_creds['secret']}\r\n#{cmd_creds['token']}\r\n")

exit(0)
