require 'pathname'

source 'https://rubygems.org'

gemspec

DM_VERSION     = '~> 1.3.0.beta'.freeze
DO_VERSION     = '~> 0.10.6'.freeze
CURRENT_BRANCH = ENV.fetch('GIT_BRANCH', 'master')

do_options = {}
do_options[:git] = "firespring/datamapper-do" if ENV['DO_GIT'] == 'true'

gem 'data_objects', DO_VERSION, do_options.dup
gem 'dm-core', DM_VERSION, github: "firespring/dm-core", branch: CURRENT_BRANCH

group :development do

  gem 'rake'
  gem 'rspec'

end

platforms :mri_18 do
  group :quality do
    gem 'rcov'
    gem 'yard'
    gem 'yardstick'
  end
end
