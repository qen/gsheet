class VisitorsController < ApplicationController
  def home
    # raise 'raise'

    @ss = SpreadSheet.new session['google_oauth2_refresh_token'] if session['google_oauth2_refresh_token'].present?
  end

  def submit

  end
end
