# frozen_string_literal: true

require "test_helper"

class LoadingTest < Minitest::Test
  def test_every_file_maps_to_its_constant
    Zeitwerk::Loader.eager_load_all

    assert_equal("0.1.0", Typesafe::SDK::VERSION)
    assert_kind_of(Class, Typesafe::SDK::APIErrorFactory)
    assert_kind_of(Class, Typesafe::SDK::HTTPRequest)
    assert_kind_of(Class, Typesafe::SDK::NetHttpTransport)
  end
end
