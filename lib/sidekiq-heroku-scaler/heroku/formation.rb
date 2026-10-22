# frozen_string_literal: true

module SidekiqHerokuScaler
  module Heroku
    Formation = Struct.new(:id, :quantity, :command, keyword_init: true)
  end
end
