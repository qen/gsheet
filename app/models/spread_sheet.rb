require 'fileutils'

class SpreadSheet

  attr_accessor :refresh_token

  def initialize(token)
    @refresh_token = token
    # https://github.com/google/google-auth-library-ruby/blob/master/lib/googleauth/user_refresh.rb#L85-L90
    credentials = Google::Auth::UserRefreshCredentials.new client_id: Rails.application.secrets[:google]['client_id'],
                                                           client_secret: Rails.application.secrets[:google]['client_secret'],
                                                           refresh_token: refresh_token

    # https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md
    @session = GoogleDrive::Session.from_credentials(credentials)
    self
  end

  def [](obj)
    WorkSheet.new obj, self
  end

  def file
    @file ||= @session.file_by_title 'Talkpush exercice'
  end

  def rows
    @rows ||= file.worksheets[0].list.map {|x| x.to_hash }
  end

  def headers
    @headers = rows.first.keys
  end

end
