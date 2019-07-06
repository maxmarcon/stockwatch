require 'active_support/concern'

module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from Exception, with: :handle_internal_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActionController::BadRequest, with: :handle_bad_request
  end

  def handle_internal_error(e = nil)
    render_error(500, Rails.env.development? && e ? e : 'An internal error has occurred')
  end

  def handle_not_found(e = nil)
    render_error(404, e || 'Not Found')
  end

  def handle_bad_request(e = nil)
    render_error(400, e || 'Bad Request')
  end

  private

  def render_error(status, message)
    respond_to do |format|
      format.html {
        render "error/error", locals: {status: status, message: message}, status: status
      }
      format.json {
        render json: {
          status: status,
          message: message
        }, status: status
      }
    end
  rescue ActionController::UnknownFormat
    render "error/error.html", locals: {status: status, message: message}, status: status
  end
end
