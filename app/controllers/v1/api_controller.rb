module V1
  class ApiController < ApplicationController
    def test
      render json: "OK"
    end
  end
end
