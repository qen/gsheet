class CampaignsController < ApplicationController

  def update
    api   = TalkPush::Api.new params[:id]
    @ss   = SpreadSheet.new session['google_oauth2_refresh_token'] if session['google_oauth2_refresh_token'].present?
    count = 0
    @ss.rows.each do |row|
      candidate = {
        'first_name'        => row['First Name'],
        'last_name'         => row['Last Name'],
        'user_phone_number' => row['Phone Number'],
        'email'             => row['Email'],
        'source'            => 'gsheet'
      }
      count += 1 if (api.submit(candidate).status == 200)
    end

    redirect_to root_path, notice: "Candidates submitted #{count}"
  end

end
