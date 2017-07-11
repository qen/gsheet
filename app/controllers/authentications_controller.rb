class AuthenticationsController < ApplicationController

  # omniauth callback method
  def google
    raise 'test'
    session['google_oauth2_refresh_token'] = env['omniauth.auth'].credentials.refresh_token

    # the only reason google_oauth2 is called is for the
    # google docs spreadsheet integration!
    if params[:provider] == 'google_oauth2'
      # session['refresh_token'] = env['omniauth.auth'].credentials.refresh_token
      redirect_to root_path and return
    end

    raise env['omniauth.auth'].inspect
  end

end
