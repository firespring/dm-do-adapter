require 'pathname'

source 'https://rubygems.org'

gemspec

SOURCE         = ENV.fetch('SOURCE', :git).to_sym
REPO_POSTFIX   = (SOURCE == :path) ? '' : '.git'
DATAMAPPER     = (SOURCE == :path) ? Pathname(__FILE__).dirname.parent : 'https://github.com/firespring'
DM_VERSION     = '~> 1.3.0.beta'.freeze
DO_VERSION     = '~> 0.10.6'.freeze
CURRENT_BRANCH = ENV.fetch('GIT_BRANCH', 'master')

do_options = {}
do_options[:git] = "#{DATAMAPPER}/datamapper-do#{REPO_POSTFIX}" if ENV['DO_GIT'] == 'true'

gem 'data_objects', DO_VERSION, do_options.dup
if SOURCE == :path
  gem 'dm-core', DM_VERSION, SOURCE => "#{DATAMAPPER}/dm-core#{REPO_POSTFIX}"
else
  gem 'dm-core', DM_VERSION, SOURCE => "#{DATAMAPPER}/dm-core#{REPO_POSTFIX}", branch: CURRENT_BRANCH
end

group :development do
  gem 'rake', '~> 13.1'
  gem 'rspec', '~> 3.13'
end

platforms :mri_18 do
  group :quality do
    gem 'rcov'
    gem 'yard'
    gem 'yardstick'
  end
end
