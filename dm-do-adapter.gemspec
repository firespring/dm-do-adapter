require File.expand_path('../lib/dm-do-adapter/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['opensource_firespring']
  gem.email         = ['opensource@firespring.com']
  gem.summary       = 'DataObjects Adapter for DataMapper'
  gem.description   = 'A unified Ruby API for popular databases.'
  gem.license = 'Nonstandard'
  gem.homepage = 'https://datamapper.org'

  gem.files = `git ls-files`.split("\n")
  gem.extra_rdoc_files = %w(LICENSE README.rdoc)

  gem.name          = 'sbf-dm-do-adapter'
  gem.require_paths = ['lib']
  gem.version       = DataMapper::DoAdapter::VERSION
  gem.required_ruby_version = '>= 2.7.8'

  gem.add_runtime_dependency('sbf-data_objects', ['~> 0.10.17'])
  gem.add_runtime_dependency('sbf-dm-core', ['~> 1.3.0.beta'])
end
