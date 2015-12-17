#!/usr/bin/env ruby

require "nokogiri"
require "csv"
require "open-uri"
require "optparse" 
require "json"

stores = JSON::parse(File.read("stores.json"))

options = {
	pages: 1,
	storefront_id: "143452,12" #Nederland
}

op = OptionParser.new do |opts|
	opts.banner = "Usage: #{$0} [options] appstore_id [outputfile.csv]"

	opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
		options[:verbose] = v
	end

	opts.on("-p N", "--pages N", "Number of app store review pages to process (20 per page)") do |pages|
		options[:pages] = pages.to_i
	end

	opts.on("-c COUNTRY", "--country COUNTRY", "The iTunes store to use: \n"+ stores.keys.join(", ")) do |country|
		if stores[country].nil?
			STDERR.puts "Cannot find iTunes store for country '#{country}'"
			exit 2
		end
		options[:storefront_id] = stores[country]
	end

end

op.parse!

if options[:verbose]
	options.each_pair do |o|
		STDERR.puts "\t"+ o.join(":\t")
	end	
end

if ARGV.length < 1 
	STDERR.puts op.banner
	exit 1
end

appstore_id = ARGV[0]

outfile = "-"

if ARGV.length > 1
	outfile = ARGV[1]
end


begin
	if outfile == "-"
		out = STDOUT
	else
		out = File.open(outfile, "w")
	end

	(1..options[:pages]).each do |pageno|

		open("https://itunes.apple.com/WebObjects/MZStore.woa/wa/customerReviews?displayable-kind=11&id=#{appstore_id}&page=#{pageno}&sort=4",
			"User-Agent" => "iTunes/10.3.1 (Macintosh; Intel Mac OS X 10.6.8) AppleWebKit/533.21.1",
			"X-Apple-Store-Front" => options[:storefront_id]) do |io|
			

			contents = io.read

			doc = Nokogiri::HTML(contents)

			doc.css(".customer-review").each do |review|
				date = review.css(".user-info").first.children.last.to_html.split("\n")[6].strip
				rating = review.css(".rating").first.get_attribute("aria-label")[0]
				title = review.css(".customerReviewTitle").inner_html
				review = review.css(".content").inner_html.strip
				out.puts [date, rating, title, review].to_csv
			end

		end
	end
ensure
	out.close
end
