require 'typhoeus/adapters/faraday'

module TalkPush
  class Api

    URL = 'https://my.talkpush.com'

    def initialize(campaign_id = nil)
      @campaign_id = campaign_id || Rails.application.secrets[:talkpush]['campaign_id']
    end

    def endpoint
      '/api/talkpush_services/campaigns/'+ @campaign_id +'/campaign_invitations'
    end

    # http://read.corilla.com/Talkpush/API-Documentation.html#API---Create-Candidate
    # {
    #   'first_name'        => 'foo',
    #   'last_name'         => 'bar',
    #   'user_phone_number' => '123456789',
    #   'email'             => 'hello@exmaple.com',
    #   'source'            => 'gsheet'
    # }
    def submit(candidate)
      request = Faraday.new url: URL do |faraday|
        faraday.request :url_encoded # form-encode POST params
        faraday.response :logger, ::Logger.new(STDOUT), bodies: true # Rails.env.development?
        faraday.adapter :typhoeus
      end

      post = {}
      post['api_key']     = Rails.application.secrets[:talkpush]['key']
      post['api_secret']  = Rails.application.secrets[:talkpush]['secret']
      post['campaign_invitation'] = candidate

      result = request.post endpoint, post
    end

  end
end
