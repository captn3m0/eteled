require 'sinatra'
require 'json'
require 'octokit'

load 'brain.rb'
github = Octokit::Client.new :access_token => ENV['OAUTH_TOKEN']

set :port, ENV['PORT'] || 9393 #Default port

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
	return "No repository information" unless repodata
	return "No comment information" unless message_id

	repodata=repodata.match(/<([a-z0-9A-Z-]+)\/([a-z0-9A-Z-]+)\/(issues|pull)\/(\d+)@github.com>/i)
	repo_name = repodata[1]+"/"+repodata[2]
	issue_id = repodata[4]

	comment_details = message_id.match(/(\d+)@github.com/)
	comment_id = comment_details[1]

	#Check the message
	message_body = data['TextBody'].split("\n").first.chomp
	repo_identifier = repo_name + "/" + issue_id
	if message_body == "@eteled START"	#eteled Activate
		puts "Start deleting comments on #{repo_identifier}"
		Brain.add repo_identifier
		github.add_comment repo_name, issue_id, "This issue is monitored by @eteled. Any further comments on this issue will be automatically deleted."
		return 'START Accepted'
	elsif message_body == "@eteled STOP"	#eteled De-Activate
		puts "Stop deleting comments on #{repo_identifier}"
		github.add_comment repo_name, issue_id, "This issue is no longer monitored by @eteled."
		Brain.delete repo_identifier
		return 'STOP Accepted'
	end
	#Get comment number from message id
	#Now we delete the comment
	if Brain.member? repo_identifier
		ret = github.delete_comment(repo_name, comment_id)
		if ret
			puts "Deleted comment #{repo_identifier}##{comment_id}"
			return "Comment Deleted"
		else
			puts "Couldn't Delete comment #{repo_identifier}##{comment_id}"
			return "Couldn't delete comment"
		end
	else
		puts "Skipping comment #{repo_identifier}##{comment_id}"
		return "Comment untouched"
	end
	"Thanks for flying with Eteled\n"
end