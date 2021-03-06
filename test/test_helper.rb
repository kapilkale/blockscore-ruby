require 'simplecov'
SimpleCov.start

require 'factory_girl'
require 'faker'
require 'minitest/autorun'
require 'minitest/rg'
require 'shoulda/context'
require 'webmock/minitest'
require 'minitest/unit'
require 'mocha/mini_test'

require File.expand_path(File.join(File.dirname(__FILE__), '../test/factories'))
require File.expand_path(File.join(File.dirname(__FILE__), '../test/support/response'))
require File.expand_path(File.join(File.dirname(__FILE__), '../test/support/resource_test'))

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'blockscore'

WebMock.disable_net_connect!(allow: 'codeclimate.com')

HEADERS = {
  'Accept' => 'application/vnd.blockscore+json;version=4',
  'User-Agent' => 'blockscore-ruby/4.1.0 (https://github.com/BlockScore/blockscore-ruby)',
  'Content-Type' => 'application/json'
}

METAKEYS = [:id, :created_at, :updated_at]

def without_authentication
  BlockScore.api_key = nil # clear API key
end

def with_authentication
  BlockScore.api_key = 'sk_test_a1ed66cc16a7cbc9f262f51869da31b3'
end

def create_candidate
  create_resource(:candidate)
end

def create_company
  create_resource(:company)
end

def create_person
  create_resource(:person)
end

def create_question_set
  person = create_person
  create_resource(:question_set)
end

def create_resource(resource)
  params = FactoryGirl.create((resource.to_s + '_params').to_sym)
  response = resource_to_class(resource).create(params)

  # make sure resulting object responds to the desired keys
  params.each { |key, _| assert_respond_to response, key }

  response
end

# Convert a resource into the corresponding BlockScore class.
def resource_to_class(resource)
  BlockScore::Util.to_constant("BlockScore::#{BlockScore::Util.to_camelcase(resource.to_s)}")
end

# configure test-unit for FactoryGirl
class Minitest::Test
  #include WebMock::API
  include FactoryGirl::Syntax::Methods

  def setup
    with_authentication

    @api_stub = stub_request(:any, /.*api\.blockscore\.com\/.*/).
      with(headers: HEADERS).
      to_return do |request|
        uri = request.uri
        check_uri_for_api_key(uri)

        resource, id, action = uri.path.split('/').tap(&:shift)
        factory_name = resource_from_uri(resource)

        unless FactoryGirl.factories[factory_name]
          raise ArgumentError, "could not find factory #{factory_name.inspect}."
        end

        handle_test_response request, id, action, factory_name
      end
  end
end
