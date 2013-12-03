require 'sinatra'
require 'json'
require 'octokit'

github = Octokit::Client.new :access_token => ENV['OAUTH_TOKEN']

get '/' do
  redirect "http://captnemo.in/eteled/"
end

post '/webhook' do
	data = JSON.parse(request.body.read)
	repodata = false
	message_id=false
	#There is no "References" header for the opening comment of an issue/PR
	#Therefore, we only process if we get a References header
	data['Headers'].each do |header|
		#Get the repository and issue number via regex
		#http://www.rubular.com/r/yONKUpMQTB
		repodata = header['Value'] if header['Name']=="References"
		message_id = header['Value'] if header['Name']=="Message-ID"
	end
	if repodata
		repodata=repodata.match(/<([a-z0-9A-Z-]+)\/([a-z0-9A-Z-]+)\/(issues|pull)\/(\d+)@github.com>/i)
		if repodata
			repo_name = repodata[1]+"/"+repodata[2]
			issue_id = repodata[4]
		end
		#Get comment number from message id
		comment_details = message_id.match(/<([a-z0-9A-Z-]+)\/([a-z0-9A-Z-]+)\/(issues|pull)\/(\d+)\/(\d+)@github.com>/)
		comment_id = comment_details[5]
		puts repo_name
		puts comment_id
		#Now we delete the comment
		ret = github.delete_comment(repo_name, comment_id)
		if ret
			puts "Success"
			return "Comment Deleted"
		else
			puts "Unsuccessful"
			return "Couldn't delete comment"
		end
	end
	"Thanks for flying with Eteled\n"
end