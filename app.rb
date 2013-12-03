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
	return "No repository information" unless repodata
	return "No comment information" unless message_id

	repodata=repodata.match(/<([a-z0-9A-Z-]+)\/([a-z0-9A-Z-]+)\/(issues|pull)\/(\d+)@github.com>/i)
	repo_name = repodata[1]+"/"+repodata[2]
	issue_id = repodata[4]

	comment_details = message_id.match(/<([a-z0-9A-Z-]+)\/([a-z0-9A-Z-]+)\/(issues|pull)\/(\d+)\/(\d+)@github.com>/)
	comment_id = comment_details[5]

	#Check the message
	message_body = data['TextBody'].split("\n").first.chomp

	if message_body == "@eteled START"	#eteled Activate
		puts "Start deleting on this thread"
		github.add_comment repo_name, issue_id, "This issue is monitored by @eteled. Any further comments on this issue will be automatically deleted."
		return 'START Accepted'
	elsif message_body == "@eteled STOP"	#eteled De-Activate
		github.add_comment repo_name, issue_id, "This issue is no longer monitored by @eteled."
		return 'STOP Accepted'
	end
	#Get comment number from message id
	#Now we delete the comment
	ret = github.delete_comment(repo_name, comment_id)
	if ret
		puts "Deleted comment ##{comment_id}"
		return "Comment Deleted"
	else
		puts "Couldn't Delete comment ##{comment_id}"
		return "Couldn't delete comment"
	end
	"Thanks for flying with Eteled\n"
end