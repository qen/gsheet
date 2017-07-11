class VisitorsController < ApplicationController
  def home
    # raise 'raise'
    ss = SpreadSheet.new session['google_oauth2_refresh_token']
    ss.file.title
  end
end
