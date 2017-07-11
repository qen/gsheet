require 'fileutils'

class SpreadSheet
  include ActionView::Helpers::DateHelper

  attr_accessible :title, :person_id
  serialize :settings
  serialize :cache_data

  attr_writer :session

  # suffix file as destroyed as to indicate its not linked anymore in the CRM
  after_destroy do |model|
    model.file.rename "#{model.title} | Destroyed #{Date.today}"
  end

  class << self
    # clean out any spread sheet lock file
    def work_unlock

      all.each do |model|
        model.work_unlock!
      end

    end
  end

  def self.investment_columns

  end

  def created?
    not spread_sheet_id.blank?
  end

  # build google drive session
  def session
    # @session ||= Celluloid::Actor[:google_drive_session].session(refresh_token)
    session!
  end

  def session!
    @session ||= begin
      # Celluloid::Actor[:google_drive_session].session!(self)
      client             = Google::APIClient.new application_name: 'angel_crm', application_version: 'v1'
      auth               = client.authorization
      auth.client_id     = ENV['OAUTH_GOOGLE_CLIENT_ID']
      auth.client_secret = ENV['OAUTH_GOOGLE_SECRET_KEY']
      auth.refresh_token = refresh_token
      auth.fetch_access_token!

      # Creates a session.
      GoogleDrive.login_with_oauth(auth.access_token)
    rescue => ex
      Airbrake.notify_or_ignore(ex, {parameters: { 'refresh_token' => refresh_token } });
      nil
    end
  end

  def [](obj)
    WorkSheet.new obj, self
  end

  # clears the global company id
  def reload!
    portfolio.reload
    investments.reload
  end

  def sync_portfolio
    # returns false if not created? or if there is an existing work for the spread_sheet
    return false if not created? or work_locked?
    work_lock!

    begin
      Rails.logger.info "spreadsheet> portfolio reload!"
      @portfolio = portfolio!
      @portfolio.reload

      Rails.logger.info "spreadsheet> investments reload!"
      @investments = investments!
      @investments.reload

      Rails.logger.info "spreadsheet> 1"
      person    = Person.find person_id
      Rails.logger.info "spreadsheet> 2"


      companies = person.investing_as.portfolio(false).to_a
      Rails.logger.info "spreadsheet> 3"

      # for any raised error make sure to unlock the work
    ensure
      work_unlock!
    end

    # so once we got the list of companies, we need to unlock, to allow
    # new jobs to run and sync, because it means that there will be another list of companies that needs to be synced
    build_spreadsheet_from companies

    self.cache_data!
    self.save
  end
  handle_asynchronously :sync_portfolio

  def build_spreadsheet_from(companies)
    return false if not created?

    portfolio['A1'] = 'Id'
    portfolio['B1'] = 'Name'
    portfolio['C1'] = 'Lead'
    portfolio['D1'] = 'Date'

    investments['A1'] = 'Id'
    investments['B1'] = 'Name'
    investments['C1'] = 'Date'

    portfolio_row  = portfolio.num_rows + 1
    investment_row = investments.num_rows + 1

    company_ids = []
    # (2..portfolio.num_rows).each {|r| current_ids << portfolio["A#{r}"] unless portfolio["A#{r}"].blank? }

    companies.each do |company|
      ws = self[company]

      # insert or update the company portfolio row
      ws.portfolio! company

      # insert the company investments row if needed
      ws.investments! company

      company_ids.push company.id.to_s
    end

    # select all GoogleDrive::ListRow
    portfolio.list.each do |row|
      # list row is subject for deletion if company id does not exists in the array
      next if company_ids.include? row['Id']

      # check if there is no data
      hash = row.to_hash true

      # remove the predefined columns in the hash
      %w(Id Name Lead Date).each {|f| hash.delete f }

      # only clear the row has no data
      if hash.values.select {|v| not v.blank? }.blank?
        Rails.logger.info "[#{self.id}] spreadsheet> clearing row for #{row['Name']} [#{row['Id']}]"
        row.clear
      end
    end

    # IMPORTANT to avoid race conditions on the delayed job, there should only be
    # 1 worker assigned to the "spread_sheet" queue
    Rails.logger.info "[#{self.id}] spreadsheet> portfolio reorder by name "
    portfolio_order_by_name

    Rails.logger.info "[#{self.id}] spreadsheet> dirty? #{portfolio.dirty?}"

    portfolio.title = 'Portfolio Companies'
    portfolio.save

    investments.title = 'Investments'
    investments.save

    Rails.logger.info "[#{self.id}] spreadsheet> finished! "
  end

  def portfolio_order_by_name
    list = portfolio.list

    rows = list.sort_by {|x| x['Name'].to_s.capitalize }.
    select {|x| not x['Name'].blank? }.
    map {|x| x.to_hash(true) }

    # for sanity's sake, lets clear all list first
    list.each {|x| x.clear}

    # iterate to all rows and add them back in
    rows.each { |row| list.push row }
  end

  def file
    if not created?
      f = session.create_spreadsheet title
      self.spread_sheet_id = f.id
      self.save
    end

    session.spreadsheet_by_key(spread_sheet_id)
  rescue Google::APIClient::AuthorizationError => ex
    Airbrake.notify_or_ignore(ex, {parameters: { 'refresh_token' => refresh_token } });
    session!.spreadsheet_by_key(spread_sheet_id)
  end

  def portfolio
    # @portfolio ||= ( Celluloid::Actor[:google_drive_session].portfolio(refresh_token) || portfolio! )
    @portfolio ||= portfolio!
  end

  def investments
    # @investments ||= ( Celluloid::Actor[:google_drive_session].investments(refresh_token) || investments! )
    @investments ||= investments!
  end

  def portfolio!
    file.worksheets[0]
  end

  def investments!
    begin
      sheet = file.worksheets[1]
      if sheet.blank?
        file.add_worksheet 'Investments'
        sheet = file.worksheets[1]
      end
      sheet
    end
  end

  def cache_data!
    portfolio_rows = portfolio.list.sort_by {|x| x['Name'].to_s.capitalize }.
    select {|x| not x['Name'].blank? }.
    map {|x| x.to_hash(true) }

    investments_rows = investments.list.sort_by {|x| x['Name'].to_s.capitalize }.
    select {|x| not x['Name'].blank? }.
    map {|x| x.to_hash(true) }

    self.cache_data = { :portfolio => portfolio_rows, :investments => investments_rows }
  end

  def cache_data
    return {:portfolio => [], :investments => []} if super.blank?
    super
  end

  def num_portfolio
    portfolio.num_rows - 1
  end

  def num_investments
    investments.num_rows - 1
  end

  def work_lockfile
    File.join Rails.root, 'tmp', "spread_sheet_#{self.id}.lock"
  end

  # its impossible for a work to process for more than 24 hours,
  # this check is used for cases where the lock file was somehow not removed
  def work_stale?
    ( File.exist?(work_lockfile) ? (work_lockfile_last_modified > 24.hours) : false)
  end

  def work_lockfile_last_modified
    Time.now - File.mtime(work_lockfile)
  end

  # lockfile exists and is not stale
  def work_locked?
    File.exist?(work_lockfile) and not work_stale?
  end

  def work_lock!
    raise ErrorLock, "spread_sheet id #{self.id} is locked, #{distance_of_time_in_words(work_lockfile_last_modified)} ago ", [] if work_locked?
    FileUtils.touch work_lockfile
  end

  def work_unlock!
    File.delete work_lockfile if File.exist?(work_lockfile)
  end

end
