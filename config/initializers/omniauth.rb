
# https://stackoverflow.com/a/43928335/3288608
# https://groups.google.com/forum/#!forum/risky-access-by-unreviewed-apps

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer unless Rails.env.production?
  provider :google_oauth2,
           Rails.application.secrets[:google]['client_id'],
           Rails.application.secrets[:google]['client_secret'],
           prompt: 'consent',
           scope: [
                     'https://www.googleapis.com/auth/userinfo.email',
                     'https://www.googleapis.com/auth/userinfo.profile',
                     'https://www.googleapis.com/auth/plus.login',
                     'https://www.googleapis.com/auth/plus.me',
                     'https://spreadsheets.google.com/feeds/',
                     'https://www.googleapis.com/auth/drive',
                   ]
end

