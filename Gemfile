require 'pathname'

source 'https://rubygems.org'

gemspec

SOURCE         = ENV.fetch('SOURCE', :git).to_sym
REPO_POSTFIX   = (SOURCE == :path) ? '' : '.git'
DATAMAPPER     = (SOURCE == :path) ? Pathname(__FILE__).dirname.parent : 'https://github.com/firespring'
DM_VERSION     = '~> 1.3.0.beta'.freeze
DO_VERSION     = '~> 0.10.17'.freeze
CURRENT_BRANCH = ENV.fetch('GIT_BRANCH', 'master')

options = {}
options[:branch] = CURRENT_BRANCH unless SOURCE == :path
do_options = {}
if ENV['DO_GIT'] == 'true'
  do_options = options.dup
  do_options[SOURCE] = "#{DATAMAPPER}/datamapper-do#{REPO_POSTFIX}"
end
gem 'data_objects', DO_VERSION, do_options.dup

options[SOURCE] = "#{DATAMAPPER}/dm-core#{REPO_POSTFIX}"
gem 'dm-core', DM_VERSION, options.dup

group :development do
  gem 'rake', '~> 13.1'
  gem 'rspec', '~> 3.13'
  gem 'simplecov'
end

platforms :mri_18 do
  group :quality do
    gem 'yard'
    gem 'yardstick'
  end
end
