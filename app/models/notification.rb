require "nokogiri"
require 'open-uri'
require "rest-client"
require "yaml"

class Notification < ActiveRecord::Base
  validates :uid, :uniqueness => true

  PROXY_STRING = "http://someuser:somepass@somehwere:80"
  ENDPOINTS = YAML::load(File.open("#{Rails.root}/config/endpoints.yml"))
  BIN_ID = "YOURBIN_ID"

  after_create :push

  def self.scrape
    RestClient.proxy = PROXY_STRING

    get = RestClient.get("http://www.postbin.org/#{BIN_ID}")

    doc = Nokogiri::XML(get.body)

    doc.root.xpath("//div[@class='post']").reverse.each do |notification|
      n = Notification.new
      n.received_at = DateTime.strptime(notification.inner_html.split("\n")[2].strip, "%H:%M %b %d %Y")
      n.uid = notification.at_xpath("a").inner_html.gsub("#", "")
      n.body = notification.xpath(".//pre").last.content
      puts "Saved a notification" if n.save
    end
  end

  private

  def push
    RestClient.proxy = nil

    ENDPOINTS["internal"].try(:each) do |endpoint|
      begin
        RestClient.post(endpoint, body, {:content_type => "application/xml"})
      rescue RestClient::BadRequest
        # do nothing atm
      end
    end

    RestClient.proxy = PROXY_STRING

    ENDPOINTS["external"].try(:each) do |endpoint|
      RestClient.post(endpoint, body, {:content_type => "application/xml"})
    end
  end
end
