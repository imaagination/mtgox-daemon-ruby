require 'rubygems'
require 'eventmachine'
require 'httparty'
require 'json'
require 'pp'
require './config'

EventMachine.run do
	puts "Entering polling loop"
	@last_tid = "0"
	EM.add_periodic_timer($config['POLLING_FREQUENCY']) {
		begin
			puts "Fetching trades from #{$config['TICKER_URL']}"
			ticker_resp = HTTParty.get($config['TICKER_URL'])
			ticker = JSON.parse(ticker_resp.body)
			price = ticker['return']['last']['value']
			puts "Parsed price: #{price}"

			body = "price=#{price}&timestamp=#{Time.now.to_i * 1000}&market=MTGOX"

			sig = Digest::HMAC.hexdigest('POST' + $config['ALERT_API_PATH'] + body,
				$config['HMAC_KEY'], Digest::SHA1)

			puts "Posting #{body} to #{$config['ALERT_API_HOST'] + $config['ALERT_API_PATH']}"
			resp = HTTParty.post($config['ALERT_API_HOST'] + $config['ALERT_API_PATH'],
				{ :body => body, :headers => { 'X-Signature' => sig } })

			# Notify Dead Man's Snitch
			if resp.code == 200
				puts "Snitching"
				HTTParty.post($config['DMS_URL'])
			else
				puts "Bad request. CODE: #{resp.code} BODY: #{resp.body}"
			end
		rescue
			puts "ERROR", $!, $@
		end
	}

end
