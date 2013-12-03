require 'set'
require 'json'
require 'unirest'

class Brain	
	raise "JSONBLOB_URL not set in environment" unless ENV['JSONBLOB_URL']
	puts "Fetching data"
	response = Unirest.get ENV['JSONBLOB_URL'], headers:{ "Accept" => "application/json" }
	@data = JSON.parse(response.body.to_s).to_set
	def self.get
		@data.to_a
	end
	def self.add(repo_identifier)
		@data.add repo_identifier
		self.save()
	end
	def self.save
		return Unirest.put ENV['JSONBLOB_URL'],
			headers: { "Accept" => "application/json" },
			headers: { "Content-Type" => "application/json"},
			parameters: @data.to_a.to_json
	end
	def self.delete(repo_identifier)
		@data.delete?(repo_identifier)
		self.save()
	end
	def self.member?(repo_identifier)
		@data.include? repo_identifier
	end
end