namespace :currency do
  
  desc "Get exchange rates from the cbr.ru"
  task :get_rates_in_xml => :environment do
    today = Date.today
    client = Savon::Client.new("http://www.cbr.ru/DailyInfoWebServ/DailyInfo.asmx?WSDL")
    response = client.request :web, :get_curs_on_date, body: {"On_date" => today}
    @get_curs_on_date = response.xpath("//ValuteCursOnDate") if response.presence
  end


  desc "Parsing response from cbr.ru for ':update_rates'."
  task :parsing_response_for_update => :get_rates_in_xml do
    @hash_with_rates = {}
    @get_curs_on_date.each do |current_rate|
      code = current_rate.xpath("VchCode").text
      course_raw = current_rate.xpath("Vcurs").text.to_f
      nom = current_rate.xpath("Vnom").text.to_i
      course = course_raw / nom

      @hash_with_rates[code] = course
    end
  end


  desc "Parsing response from cbr.ru for ':fill_currency.'"
  task :parsing_response_for_create => :get_rates_in_xml do
    @hash_with_currencies = {}
    @get_curs_on_date.each do |current_rate|
      code = current_rate.xpath("VchCode").text
      name = current_rate.xpath("Vname").text.rstrip!

      @hash_with_currencies[code] = name
    end
  end


  desc "Update\create the current exchange rates."
  task :update_rates => :parsing_response_for_update do
    if @hash_with_rates.presence
      date = Date.today.beginning_of_month
      @hash_with_rates.each do |code, course|
        currency = Currency.where(code: code).first
        rate = currency.rates.where(month: date).first

        if rate.presence
          rate.update_attributes(course: course, month: date)
        else
          currency.rates.create(course: course, month: date)
        end
      end
    else
      puts "Error! No response from the cbr.ru"
    end
  end


  desc "Fill 'Currency' by data from cbr.ru (for initialize)."
  task :fill_db_currency => :parsing_response_for_create do
    if @hash_with_currencies.presence
      Rake::Task['db:reset'].invoke
      @hash_with_currencies.each do |code, name|
        Currency.create(code: code, name: name)
      end
    else
      puts "Error! No response from the cbr.ru"
    end
  end
end