require 'open-uri'
require 'nokogiri'
require 'writeexcel'
require 'pry'
class Crowdworks

  def scrapping(keyword, filter)
    page           = last_page(keyword, filter, number = 1, employeer_url = nil)
    i              = 1
    user           = []
    title          = []
    url            = []
    employeers_url = []
    data           = {}
    records        = []

    while i <= page 
      root_path       = "https://crowdworks.jp/public/jobs/search?hide_expired=#{filter}&keep_search_criteria=true&order=score&page=#{i}&search%5Bkeywords%5D=#{keyword}"
      document        = open(root_path)
      content         = document.read
      parsed_content  = Nokogiri::HTML(content)
      response        = parsed_content.xpath("//h3[@class='item_title']").to_a
      response_user   = parsed_content.xpath("//span[@class='user-name']").to_a
      user[i-1]           = fetch_user(response_user)
      title[i-1]          = fetch_title(response)
      url[i-1]            = fetch_url(response)
      employeers_url[i-1] = fetch_employeer_url(response_user)
      i += 1
    end

    data = { user: user.flatten, title: title.flatten, url: url.flatten }
    save_data_jobs(data, keyword)
    scrapping_user(employeers_url.flatten.uniq)
  end

  def scrapping_user(employeers_url)
    data = {}

    employeers_url.each do |employeer_url|
      titles_job = []
      urls_job = []
      page = last_page(keyword = nil, filter = nil, number = nil, employeer_url)
      url            = employeer_url
      document       = open(url)
      content        = document.read
      parsed_content = Nokogiri::HTML(content)

      (1..page).each do |i|
        begin
          url            = "#{employeer_url}?page=#{i}&target=contracted_job_offers#contracted_job_offers"
          document       = open(url)
          content        = document.read
          parsed_content = Nokogiri::HTML(content)
          urls_job << data_job_url(parsed_content)
          titles_job << data_job_name(parsed_content)
        rescue
          next
        end
      end

      data[data_user_name(parsed_content)] = [titles_job.flatten] + [urls_job.flatten] + [employeer_url] + [data_describe_job(parsed_content)]
    end
    save_data_users(data)
  end

  def save_data_users(data)
    workbook  = WriteExcel.new("#{Time.now.strftime("%d-%m-%Y")}-1.xls")
    worksheet = workbook.add_worksheet
    i         = 0

    data.map do |key, value| 
      value[0].each_with_index do |dt, index|
        worksheet.write_string(i, 0, key)
        worksheet.write_url(i, 1, value[2])
        worksheet.write_string(i, 2, dt)
        worksheet.write_url(i, 3, value[1][index])
        worksheet.write_string(i, 4, value[3])
        i += 1
      end
    end

    workbook.close
  end

  def save_data_jobs(data, keyword)
    column = 0
    workbook  = WriteExcel.new("#{Time.now.strftime("%d-%m-%Y")}-#{keyword}.xls")
    worksheet = workbook.add_worksheet
    data.map do |key, values|
      values.each_with_index do |dt, index|
        if column != 2
          worksheet.write_string(index, column, dt)
        else
          worksheet.write_url(index, column, dt)
        end
      end
      column += 1
    end
    workbook.close
  end

  def fetch_title(response)
    title = []
    response.each do |res|
      title << res.children.text.gsub!(/\s+/, '')
    end
    title
  end

  def fetch_url(response)
    url = []
    response.each do |res|
      url << "https://crowdworks.jp/#{res.children.to_a[1].to_h['href']}"
    end
    url
  end

  def fetch_user(response_user)
    user = []
    response_user.each do |res|
      user << res.children.text.gsub!(/\s+/, '')
    end
    user
  end

  def fetch_employeer_url(response_user)
    employeer_url = []
    
    response_user.each do |res|
      employeer_url << "https://crowdworks.jp#{res.children[1].to_h['href']}"
    end
    employeer_url
  end

  def data_user_name(parsed_content)
    users_name = parsed_content.xpath("//strong[@class='user_name']").first.children.text
  end

  def data_job_name(parsed_content)
    name = []
    jobs_name = parsed_content.xpath("//div[@class='title']//span[@class='title']//a['href']").to_a
    jobs_name.each do |job|
      name << job.children.text
    end
    name
  end

  def data_job_url(parsed_content)
    url = []
    job_url = parsed_content.xpath("//div[@class='title']//span[@class='title']//a['href']").to_a
    job_url.each do |job|
      url << "https://crowdworks.jp#{job.to_h['href']}"
    end
    url
  end

  def data_describe_job(parsed_content)
    describe = parsed_content.xpath("//p")[1].nil? ? "" : "#{parsed_content.xpath("//p")[1].text.gsub(/\s+/, '')}"
    url      = "#{parsed_content.xpath("//table[@class='employer mixin-for-info']//td//a['href']").to_a[0].to_h['href']}"
    describe + url
  end

  def last_page(keyword, filter, number, employeer_url)
    employeer_url.nil? ? url = "https://crowdworks.jp/public/jobs/search?hide_expired=#{filter}&keep_search_criteria=true&order=score&page=#{number}&search%5Bkeywords%5D=#{keyword}" : url = "#{employeer_url}page=#{number}&target=contracted_job_offers#contracted_job_offers"
    
    document = open(url)
    content = document.read
    parsed_content = Nokogiri::HTML(content)

    if next_page?(parsed_content)
      number = parsed_content.xpath("//div[@class='pagination_body']").children.to_a.last.children.text.to_i
      last_page(keyword, filter, number, employeer_url)
    else
      return 1 if parsed_content.xpath("//div[@class='pagination_body']").empty?
      parsed_content.xpath("//div[@class='pagination_body']").children.to_a.last.children.text.to_i
    end
  end

  def next_page?(parsed_content)
    !parsed_content.xpath("//div/a[@class='to_next_page']").empty?
  end

end
# filter: all = false // unexpired = true
# keyword: rails
scrapping = Crowdworks.new.scrapping('rails', 'false')