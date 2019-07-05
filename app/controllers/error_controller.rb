class ErrorController < ApplicationController

  def not_found
    @status = 404
    @message = "Not found"

    render_error
  end

  private

  def render_error
    respond_to do |format|
      format.html {
        render :error, status: @status
      }
      format.json {
        render json: {
          status: @status,
          message: @message
        }, status: @status
      }
    end
  end
end
