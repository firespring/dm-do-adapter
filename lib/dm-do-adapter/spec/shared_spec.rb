shared_examples 'A DataObjects Adapter' do
  before :all do
    raise '+adapter+ should be defined in a let(:adapter) block' unless respond_to?(:adapter)

    raise '+repository+ should be defined in a let(:repository) block' unless respond_to?(:repository)

    @log = StringIO.new

    @original_logger = DataMapper.logger
    DataMapper.logger = DataMapper::Logger.new(@log, :debug)

    # set up the adapter after switching the logger so queries can be captured
    @adapter = DataMapper.setup(adapter.name, adapter.options)

    @jruby = !!(RUBY_PLATFORM =~ /java/)

    @postgres   = defined?(DataMapper::Adapters::PostgresAdapter)  && @adapter.is_a?(DataMapper::Adapters::PostgresAdapter)
    @mysql      = defined?(DataMapper::Adapters::MysqlAdapter)     && @adapter.is_a?(DataMapper::Adapters::MysqlAdapter)
    @sql_server = defined?(DataMapper::Adapters::SqlserverAdapter) && @adapter.is_a?(DataMapper::Adapters::SqlserverAdapter)
    @oracle     = defined?(DataMapper::Adapters::OracleAdapter)    && @adapter.is_a?(DataMapper::Adapters::OracleAdapter)
  end

  after :all do
    DataMapper.logger = @original_logger
  end

  def reset_log
    @log.truncate(0)
    @log.rewind
  end

  def log_output
    @log.rewind
    output = @log.read
    output.chomp!
    output.gsub!(/\A\s+~ \(\d+[\.,]?\d*\)\s+/, '')
    output.gsub!(/\Acom\.\w+\.jdbc\.JDBC4PreparedStatement@[^:]+:\s+/, '') if @jruby
    output.split($/)
  end

  def supports_default_values?
    @adapter.send(:supports_default_values?)
  end

  def supports_returning?
    @adapter.send(:supports_returning?)
  end

  describe '#create' do
    describe 'serial properties' do
      before :all do
        class ::Article
          include DataMapper::Resource

          property :id, Serial

          auto_migrate!
        end

        reset_log

        Article.create
      end

      it 'does not send NULL values' do
        statement = if @mysql
          /\AINSERT INTO `articles` \(\) VALUES \(\)\z/
        elsif @oracle
          /\AINSERT INTO "ARTICLES" \("ID"\) VALUES \(DEFAULT\) RETURNING "ID"/
        elsif supports_default_values? && supports_returning?
          /\AINSERT INTO "articles" DEFAULT VALUES RETURNING \"id\"\z/
        elsif supports_default_values?
          /\AINSERT INTO "articles" DEFAULT VALUES\z/
        else
          /\AINSERT INTO "articles" \(\) VALUES \(\)\z/
        end

        expect(log_output.first).to match statement
      end
    end

    describe 'properties without a default' do
      before :all do
        class ::Article
          include DataMapper::Resource

          property :id,    Serial
          property :title, String

          auto_migrate!
        end

        reset_log

        Article.create(id: 1)
      end

      it 'does not send NULL values' do
        regexp = if @mysql
          /^INSERT INTO `articles` \(`id`\) VALUES \(.{1,2}\)$/i
        elsif @sql_server
          /^SET IDENTITY_INSERT \"articles\" ON INSERT INTO "articles" \("id"\) VALUES \(.{1,2}\) SET IDENTITY_INSERT \"articles\" OFF $/i
        else
          /^INSERT INTO "articles" \("id"\) VALUES \(('.{1,2}'|.{1,2})\)$/i
        end

        expect(log_output.first).to match regexp
      end
    end
  end

  describe '#select' do
    before :all do
      class ::Article
        include DataMapper::Resource

        property :name,   String, key: true
        property :author, String, required: true

        auto_migrate!
      end

      @article_model = Article

      @article_model.create(name: 'Learning DataMapper', author: 'Dan Kubb')
    end

    describe 'when one field specified in SELECT statement' do
      before :all do
        @return = @adapter.select('SELECT name FROM articles')
      end

      it 'returns an Array' do
        expect(@return).to be_kind_of(Array)
      end

      it 'has a single result' do
        expect(@return.size).to eq 1
      end

      it 'returns an Array of values' do
        expect(@return).to eq [ 'Learning DataMapper' ]
      end
    end

    describe 'when more than one field specified in SELECT statement' do
      before :all do
        @return = @adapter.select('SELECT name, author FROM articles')
      end

      it 'returns an Array' do
        expect(@return).to be_kind_of(Array)
      end

      it 'has a single result' do
        expect(@return.size).to eq 1
      end

      it 'returns an Array of Struct objects' do
        expect(@return.first).to be_kind_of(Struct)
      end

      it 'returns expected values' do
        expect(@return.first.values).to eq [ 'Learning DataMapper', 'Dan Kubb' ]
      end
    end
  end

  describe '#execute' do
    before :all do
      class ::Article
        include DataMapper::Resource

        property :name,   String, key: true
        property :author, String, required: true

        auto_migrate!
      end

      @article_model = Article
    end

    before :all do
      @result = @adapter.execute('INSERT INTO articles (name, author) VALUES(?, ?)', 'Learning DataMapper', 'Dan Kubb')
    end

    it 'returns a DataObjects::Result' do
      expect(@result).to be_kind_of(DataObjects::Result)
    end

    it 'affects 1 row' do
      expect(@result.affected_rows).to eq 1
    end

    it 'does not have an insert_id' do
      pending 'Inconsistent insert_id results' unless @postgres || @mysql || @oracle

      expect(@result.insert_id).to be_nil
    end
  end

  describe '#read' do
    before :all do
      class ::Article
        include DataMapper::Resource

        property :name, String, key: true
        property :description, String, required: false

        belongs_to :parent, self, required: false
        has n, :children, self, inverse: :parent

        auto_migrate!
      end

      class ::Publisher
        include DataMapper::Resource

        property :name, String, key: true

        auto_migrate!
      end

      class ::Author
        include DataMapper::Resource

        property :name, String, key: true

        belongs_to :article
        belongs_to :publisher

        auto_migrate!
      end

      @article_model   = Article
      @publisher_model = Publisher
      @author_model    = Author
    end

    describe 'with a raw query' do
      before :all do
        expect(@article_model.create(:name => 'Test', :description => 'Description')).to be_saved
        expect(@article_model.create(:name => 'NoDescription')).to be_saved

        @query = DataMapper::Query.new(repository, @article_model, conditions: ['description IS NOT NULL'])

        @return = @adapter&.read(@query)
      end

      it 'returns an Array of Hashes' do
        expect(@return).to be_kind_of(Array)
        @return.all? { |entry| expect(entry).to be_kind_of(Hash) }
      end

      it 'returns expected values' do
        expect(@return).to eq [ { @article_model.properties[:name]        => 'Test',
                              @article_model.properties[:description] => 'Description',
                              @article_model.properties[:parent_name] => nil } ]
      end
    end

    describe 'with a raw query with a bind value mismatch' do
      before :all do
        expect(@article_model.create(:name => 'Test')).to be_saved

        @query = DataMapper::Query.new(repository, @article_model, conditions: ['name IS NOT NULL', nil])
      end

      it 'raises an error' do
        expect { @adapter.read(@query) }.to raise_error(ArgumentError, 'Binding mismatch: 1 for 0')
      end
    end

    describe 'with a Collection bind value' do
      describe 'with an inclusion comparison' do
        before :all do
          5.times do |index|
            expect(@article_model.create(:name => "Test #{index}", :parent => @article_model.last)).to be_saved
          end

          @parents = @article_model.all
          @query   = DataMapper::Query.new(repository, @article_model, parent: @parents)

          @expected = @article_model.all[1, 4]&.map { |article| article.attributes(:property) }
        end

        describe 'that is not loaded' do
          before :all do
            reset_log
            @return = @adapter&.read(@query)
          end

          it 'returns an Array of Hashes' do
            expect(@return).to be_kind_of(Array)
            @return.all? { |entry| expect(entry).to be_kind_of(Hash) }
          end

          it 'returns expected values' do
            expect(@return).to eq @expected
          end

          it 'executes one subquery' do
            pending if @mysql

            expect(log_output.size).to eq 1
          end
        end

        describe 'that is loaded' do
          before :all do
            @parents.to_a  # lazy load the collection
          end

          before :all do
            reset_log
            @return = @adapter&.read(@query)
          end

          it 'returns an Array of Hashes' do
            expect(@return).to be_kind_of(Array)
            @return.all? { |entry| expect(entry).to be_kind_of(Hash) }
          end

          it 'returns expected values' do
            expect(@return).to eq @expected
          end

          it 'executes one query' do
            expect(log_output.size).to eq 1
          end
        end
      end

      describe 'with an negated inclusion comparison' do
        before :all do
          5.times do |index|
            expect(@article_model.create(:name => "Test #{index}", :parent => @article_model.last)).to be_saved
          end

          @parents = @article_model.all
          @query   = DataMapper::Query.new(repository, @article_model, :parent.not => @parents)

          @expected = []
        end

        describe 'that is not loaded' do
          before :all do
            reset_log
            @return = @adapter&.read(@query)
          end

          it 'returns an Array of Hashes' do
            expect(@return).to be_kind_of(Array)
            @return.all? { |entry| expect(entry).to be_kind_of(Hash) }
          end

          it 'returns expected values' do
            expect(@return).to eq @expected
          end

          it 'executes one subquery' do
            pending if @mysql

            expect(log_output.size).to eq 1
          end
        end

        describe 'that is loaded' do
          before :all do
            @parents.to_a  # lazy load the collection
          end

          before :all do
            reset_log
            @return = @adapter&.read(@query)
          end

          it 'returns an Array of Hashes' do
            expect(@return).to be_kind_of(Array)
            @return.all? { |entry| expect(entry).to be_kind_of(Hash) }
          end

          it 'returns expected values' do
            expect(@return).to eq @expected
          end

          it 'executes one query' do
            expect(log_output.size).to eq 1
          end
        end
      end

      context 'with an inclusion comparison of nil values' do
        before :all do
          5.times do |index|
            expect(@article_model.create(:name => "Test #{index}", :parent => @article_model.last)).to be_saved
          end

          @query  = DataMapper::Query.new(repository, @article_model, parent_name: [nil])
          @return = @adapter&.read(@query)
        end

        it 'returns records with matching values' do
          expect(@return.to_a).to eq [ @article_model.first.attributes(:property) ]
        end
      end

      context 'with an inclusion comparison of nil and actual values' do
        before :all do
          5.times do |index|
            expect(@article_model.create(:name => "Test #{index}", :parent => @article_model.last)).to be_saved
          end

          @last   = @article_model.last
          @query  = DataMapper::Query.new(repository, @article_model, parent_name: [nil, @last.parent.name])
          @return = @adapter&.read(@query)
        end

        it 'returns records with matching values' do
          expect(@return.to_a).to match [ @article_model.first.attributes(:property), @last.attributes(:property) ]
        end
      end
    end

    describe 'with a Query Path' do
      subject { @author_model.all(query).to_a }

      let(:article_name)   { 'DataMapper Rocks!'                                                    }
      let(:publisher_name) { 'Unbiased Press'                                                       }
      let(:query)          { {'article.name' => article_name, 'publisher.name' => publisher_name} }

      before do
        @author = @author_model.first_or_create(
          name: 'Dan Kubb',
          article: {name: article_name},
          publisher: {name: publisher_name}
        )
      end

      specify { expect { subject }.to_not raise_error }

      it { is_expected.to eq [ @author ] }
    end
  end
end
